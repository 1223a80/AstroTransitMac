# TransitStudio 前后端架构重设计方案

> 收尾状态（2026-09-06）：保留的后续设计，尚未实施。必须结合 architecture-redesign-review.md 修订后再开工；当前产品仍使用子进程后端。统一入口：current-status.md。

> 状态：**设计稿（2026-08-13）**，尚未开始实现。
> 决策基线（已与负责人确认）：macOS 单机为主；后端改本地常驻服务；前端引入 TCA/Reducer 风格状态机；先只出方案，暂不落地。
> 现状依据：本方案建立在对源码的量化审计之上（见 `docs/project-audit-2026-07-06.md` 与 2026-08-13 补充审计），行数、依赖与机制均以代码为准。

---

## 1. 背景与问题陈述

现状架构在 71 天内支撑了 35+ 计算模式、约 70K 行产品代码，边界清晰、测试扎实，但存在五处结构性债务（按严重度排序）：

| # | 问题 | 证据 |
|---|---|---|
| P0 | `ContentView` 上帝状态容器 | 149 个 `@State`；`ContentView+RunActions.swift` 82KB/58 函数、`+SidebarSections.swift` 78KB |
| P1 | 模板化三件套复制 | 19 个 `*Exports.swift` 骨架重复；`TextExportBuilder` 与 `Markdown*ExportBuilder` 家族（约 5,000 行）双轨并行 |
| P2 | Python 巨型 dispatcher 与事后拆分 | `astro_backend_api.py` 96KB 含分发+验证；horary v2/v2_modules/v2_aspects 三角交叉依赖靠函数内 import 规避 |
| P3 | 两套进程管理并存 | `BackendClient.swift`（480 行）与 `RectifyClient.swift`（225 行）各自实现 spawn/超时/取消/进度 |
| P4 | 分发脆弱 | 产物不捆绑 Python 运行时，依赖宿主 `python3` + `pyswisseph` |
| P5 | 每次计算冷启动进程 | rectify/timing 类重计算受制于单进程 + 300s 超时天花板 |

目标架构在不改变占星计算语义（所有计算规则、输出形状以现有测试为准）的前提下解决 P0–P5。

## 2. 设计原则

1. **计算内核不动**。Python 67 个模块的数学与规则是已验证资产；本方案只改运行形态与调用方式，不改算法。
2. **契约是唯一交接面**。Swift 与 Python 只通过版本化 JSON 契约通信；任何一端可独立替换。
3. **渐进、每步可停可回退**。每个迁移阶段产出可独立发布的 App，全程有 CI 与双跑护栏。
4. **纯值语义状态、显式副作用**。前端状态全部为值类型；所有 I/O（daemon、AI、持久化）经显式 Effect 建模，可测试、可取消。
5. **不引入第三方依赖**。项目至今零外部 Swift 依赖（纯 Apple 框架），方案延续此约束；TCA 内核自研轻量版。
6. **遵循现有仓库约定**。Python 平铺模块、conftest 路径注入、fixture 契约测试、`Examples/` 样例、`PLANS.md`/`CHANGELOG.md` 纪律全部保留。

## 3. 总体架构

```
┌────────────────────────────────────────────────────────────────────┐
│ SwiftUI App（macOS，单进程）                                          │
│                                                                      │
│  AppShell（导航 rail / 侧栏 / 结果窗格 / AI 面板 / 状态栏）            │
│    │  纯展示 chrome 状态仍留在 SwiftUI @State                         │
│    ▼                                                                 │
│  Store 层（mini-TCA 内核）                                            │
│    SessionStore ── 共享设置、profiles、presets、AI 配置               │
│    NatalStore  HoraryStore  KPStore  MomentStore  ScanStore          │
│    RectifyStore  VedicStore  ClassicalStore  Modern*Store …          │
│    │  每个 Store = State(值类型) + Action + Reducer + Effect          │
│    ▼                                                                 │
│  依赖层（协议注入）                                                    │
│    BackendTransport ◀─┬─ DaemonTransport（常驻，首选）                │
│                       └─ ColdStartTransport（进程冷启动，回退）        │
│    LLMClient（SSE 直连，不经 daemon）   Persistence（UserDefaults/JSON）│
│    EnvironmentDoctor（运行时体检）                                     │
└──────────────┬──────────────────────────────────────────────────────┘
               │ 127.0.0.1 loopback TCP + 随机端口（port 文件）+ 握手 token
               │ NDJSON envelope（request / event / response / error / cancel）
┌──────────────▼──────────────────────────────────────────────────────┐
│ 本地常驻 daemon（独立 python3 进程，launch-on-demand）                │
│    daemon.py ── accept 循环 / 握手 / 串行任务队列 / 取消检查点         │
│    api 层 ── 现有 astro_backend_api.main 的 dispatch 逻辑复用          │
│    cache ── 星历位置 / 宫位表 / 计算假设（进程内存，按 jd 键缓存）      │
│    swisseph ── 现有 ephemeris 与 67 个计算模块，零算法改动              │
└─────────────────────────────────────────────────────────────────────┘
```

数据流不变式：**一次用户操作 = 一个 Action = 一次 reducer 计算 + 至多一个 Effect（后台任务）= 零到多个新 Action**。状态变更全部发生在 reducer 内，副作用全部发生在 Effect 内。

## 4. 后端：本地常驻 daemon

### 4.1 进程模型与生命周期

- **launch on demand**：首次计算时由 `DaemonTransport` 拉起（复用现有 `AppState.pythonPath` 解析与 `suggestedPythonPath()` 探测链）。之后复用。
- **空闲自退**：无请求 10 分钟后 daemon 自行退出（`IDLE_TIMEOUT`，可配置）。下次计算再拉起。内存缓存随退出丢弃——星历热缓存的价值主要在"一次交互内的批量计算"（scan 窗口、rectify 级联），这与空闲自退不冲突。
- **配置变更重启**：App 检测到 `pythonPath`/`ephemerisPath`/`requireEphemeris` 变化时，主动关闭旧连接并杀掉旧 daemon，下次请求自然拉起新 daemon。
- **崩溃恢复**：连接断开且请求未完成时，`DaemonTransport` 自动重启 daemon 一次并重放该请求；连续两次失败则降级到 `ColdStartTransport` 完成本次计算，并在状态栏提示"常驻服务不可用，已回退单次进程模式"。
- **App 退出**：App 退出时发送 `shutdown` 命令；daemon 也监听 stdin EOF 作为兜底退出信号。
- **降级矩阵**：daemon 始终是优化路径，冷启动是正确性兜底。两者共享同一 `Envelope`/`schema`，输出必须语义等价（由契约双跑测试保证，见 §9）。

### 4.2 传输与协议

- **传输**：TCP loopback（127.0.0.1）+ daemon 启动时随机分配端口并写 `~/Library/Application Support/TransitStudio/daemon.port`。握手时双方交换随机 token，daemon 拒绝无 token 连接。选 TCP 而非 Unix domain socket 的理由：`URLSession`/`NWConnection` 现成支持、连接状态机简单、loopback + token 已足够安全（App 未沙盒，本地威胁模型不变）。备选：UDS + `NWConnection`（更"纯"，但需自管连接生命周期，收益不抵成本）。
- **协议**：NDJSON，一行一个对象，全部 UTF-8。

```
客户端 → {"type":"request",  "request_id":"…", "mode":"classical", "schema":"classical/1", "payload":{…}}
客户端 → {"type":"cancel",   "request_id":"…"}
daemon ← {"type":"event",    "request_id":"…", "event":"progress",  "data":{"done":1234,"total":5000,"label":"扫描 2026-05-01"}}
daemon ← {"type":"response", "request_id":"…", "schema":"classical/1", "data":{…}, "warnings":[…], "meta":{…}}
daemon ← {"type":"error",    "request_id":"…", "error":{"code":"validation","message":"…","details":{…}}}
客户端 → {"type":"ping"}  /  daemon ← {"type":"pong","stats":{"uptime_s":…,"jobs_done":…,"cache_entries":…}}
客户端 → {"type":"shutdown"}
```

- `schema` 字段是**双向握手**：App 请求指定期望 schema 版本；daemon 启动时报告自身支持的模式/schema 列表。不匹配时 App 可选择重启 daemon（代码过期）或降级冷启动。
- 现有 `{"progress": …}` stderr 行机制整体迁移为协议内 `event/progress`，stderr 只保留 traceback 与诊断。
- `mode` 之外的现行 dispatch 分支（35 个）不变；`payload` 就是现在 `calculate_*` 收到的 request dict。

### 4.3 调度模型

- **串行任务队列**（FIFO）+ 每任务协作式取消检查点。串行的理由：pyswisseph 在 GIL 下的并发行为未经验证，串行是唯一可证明正确的调度；扫描/rectify 的长任务在检查点响应 `cancel`（检查点放在窗口循环每 N 次迭代处，沿用现有 rectify progress 的写法）。
- **per-job 超时**：现有 300s 硬超时改为按 mode 配置（`scan`/`rectify`/`modern_timing` 可放宽，`moment`/`natal` 收紧到 60s），超时杀掉计算协程并回 `error/timeout`。
- **快速路径**：`moment`/`natal` 类 <100ms 的请求跳过排队直接同步执行。
- **并发预留**：调度器接口按"可配置 worker 数"设计，初版固定 1；若未来确认 pyswisseph 释放 GIL，改配置即可。

### 4.4 缓存层

- 进程内存 `functools.lru_cache` 化行星位置计算：键 `(jd_ut 量化到秒, body_id, sidereal_flag)`。同一时刻跨模式（natal→moment→scan 起始帧）与 rectify 级联的重算全部命中。
- 缓存只对**纯函数**（`calculate_positions`、`build_houses`、sign/bounds 查表）开放；任何带 request 语义的函数不进缓存。
- 失效：ephemeris path 或 zodiac/ayanamsa 配置变更时整表清空（键已含 flag，配置变更触发 daemon 重启，天然失效）。
- 不做磁盘缓存（第一版）。星历文件本身是磁盘缓存，进程缓存只服务会话内重复计算。

### 4.5 daemon 代码结构

遵循现有平铺约定（`conftest.py` 把 backend 目录注入 `sys.path`，模块按文件名互 import）：

```
Resources/backend/
  astro_backend_daemon.py      # 新增：socket accept 循环、握手、任务队列、取消、空闲/退出（目标 <400 行）
  astro_backend_protocol.py    # 新增：envelope 类型、请求校验、event 序列化（目标 <200 行）
  transit_calc.py              # 保留：冷启动入口（main() 不变）
  astro_backend_api.py         # 瘦身：main() 的 dispatch 抽为 handle_request(mode, payload, warnings)
                               #        → 被 transit_calc 与 daemon 共用；逐模式验证逻辑留在 api 不动
  其余 66 个模块                 # 零改动
```

`handle_request` 的抽取是关键动作：它让"冷启动"与"常驻"变成同一函数的两种外壳，契约双跑测试因此成为可能。

### 4.6 运行时环境管理（解决 P4）

- **EnvironmentDoctor**（App 侧）：启动与设置页触发，检查 ① python 可执行且版本 ≥3.10 ② `pyswisseph` 可导入 ③ 星历文件可达（bundled 或用户目录）。结果三态：健康 / 可降级（daemon 不可用但冷启动可用）/ 不可用。
- **引导 UX**：不可用时设置页给出明确面板（而非现在的 `processFailed` 报错），提供：一键复制安装命令（`pip3 install pyswisseph`）、python.org/homebrew 安装链接、`pythonPath` 手动指定。检出逻辑复用 `swissephStatus()` 并扩展为结构化结果。
- **本方案不内嵌运行时**（PyInstaller 体积、启动与调试成本不划算；已确认不做）。

## 5. 契约层

### 5.1 响应 envelope 与 schema 版本化

所有模式响应统一为：

```json
{
  "schema": {"schema_id": "classical-data-packet/1.0", "version": "1.0"},
  "data": { …现状 24 个顶层键… },
  "warnings": [],
  "meta": {"backend": "daemon", "elapsed_ms": 42}
}
```

- **`schema_id` 是解码器选择键**。Swift 侧 `ContractRegistry` 按 schema_id+version 路由到对应 `Decodable` 模型；未知版本走 `LegacyFallback`（原始 JSON 展示 + 警告），不再静默白屏。
- 已具备 schema 雏形的四个包（`docs/schemas/horary-data-packet-2.0|2.1.json`、`kp-horary-data-packet-1.0.json`、`rectification-evidence-packet-1.0.json`）保持原 `schema` 字段不动，envelope 与其内层 schema 字段并存（外层是传输元数据，内层是数据包自描述）。
- 新增/变更字段流程固定为：改 JSON Schema → 改后端 → 重新生成 fixture → 改 Swift 模型 → `BackendContractTests` 全绿。**契约变更是唯一需要同时动两端的行为**，其余改动互不阻塞。
- 每模式补一份 JSON Schema 纳入 `docs/schemas/`（迁移阶段 0 逐模式补齐，不求一次性全量）。

### 5.2 弃用流程

沿用 horary v1→v2 先例并推广：旧 schema 保留解码与后端支持 ≥2 个大版本；deprecated 标记进 schema 文档；用户数据（presets 等）迁移独立于 schema 弃用。

## 6. 前端：TCA 风格状态机

### 6.1 决策：自研轻量内核（不引官方 TCA 库）

理由：项目零第三方依赖是隐性资产（纯 SwiftPM 构建、无供应链风险）；官方 swift-composable-architecture 引入约 30K 行依赖与版本维护负担，而本项目需要的核心能力（单向数据流、Effect 取消、依赖注入）可用 ~300 行内核覆盖。若未来需要更高级能力（navigation 栈、测试时钟），再评估引入，届时本内核的 `Store/Effect` 接口与 TCA 同构，迁移成本可控。

### 6.2 内核四要素

```swift
// Effect：显式副作用。task 的 Action 产出回投 Store；带 id 者可取消。
struct Effect<Action>: Sendable {
    let id: UUID?                          // 非 nil 则可取消（cancel(id)）
    let run: @Sendable (_ send: @escaping @MainActor (Action) -> Void) async -> Void
    static func cancel(_ id: UUID) -> Effect { … }   // 匹配现有 withTaskCancellationHandler 语义
}

// Reducer：纯函数。State 值类型，Action 由 store 串行投递。
protocol Reducer<State, Action> {
    associatedtype State
    associatedtype Action
    func reduce(state: inout State, action: Action) -> [Effect<Action>]
}

// Store：与 SwiftUI 的桥。@MainActor，持有 state 与 effect 任务表。
@MainActor final class Store<R: Reducer>: ObservableObject {
    @Published private(set) var state: R.State
    private let reducer: R
    func send(_ action: R.Action)   // 串行：reduce → 执行 Effect → 产出 Action 再 send
    func cancel(_ id: UUID)
}
```

设计约束（来自现有踩坑经验，必须写进内核注释）：

1. **Reducer 内禁止任何 I/O**（网络/进程/UserDefaults 均走 Effect）。
2. **Effect 产出 Action 的节流在 Effect 内部做**（对应现有 AI 流式 100ms 节流，见 6.4）。
3. **状态不可跨 Store 直接写**；跨域协调用 `SessionStore` 发布 + 各 Store 订阅（SwiftUI `onChange` 桥接，等价于现有 `onChange(of:)` 用法）。

### 6.3 状态域划分（149 个 @State 的迁移地图）

| 域 | 组成 | 现状归属 |
|---|---|---|
| `SessionState` | pythonPath、ephemerisPath、noAsteroids、requireEphemeris、autoDownloadAsteroids、LLM 全套配置、AI prompts、natalProfiles、momentPresets、scanPresets、practiceMode、appearance | `AppState` + ContentView 约 30 个 @State |
| `NatalModeState` | natalDate、经纬度、houseSystem、zodiac、bounds、triplicity、classicalAspectOrb、selectedNatalBodies | 约 20 个 |
| `HoraryModeState` | horaryDate、place、经纬度、question、horaryHouseSystem、horaryAspectOrb | 约 8 个 |
| `KPModeState` | kpHoraryNumber、kpFocusHouse、kpNodeMode | 3 个 |
| `MomentModeState` | transitDate、targetSource、targets、bodies、aspects、customAsteroids、globalOrb | 约 15 个 |
| `ScanModeState` | scanStart/End、scanKind、scanWorkspaceMode、scanTargets、scanMoonFilter、scanPreset 选择 | 约 20 个 |
| `RectifyModeState` | centerTime、window、三级级联当前选择、rectifyInputHash | 约 10 个 |
| `TimingModeState` | displayTimezone、techniques、各事件类型/天体/aspect/orb、timingTargetChart | 约 20 个 |
| `AIState`（每模式内嵌） | streamKey、streamBuffer、最终文本 | 迁移自 `aiVM`，规则见 6.4 |
| UI chrome（**留在 SwiftUI**） | isNavigationCollapsed、isMiddleSidebarCollapsed、collapsedSections、isParamDrawerPinned、isAIPanelOpen | 约 10 个 |

结果状态统一为泛型 `RunState<Result>`：

```swift
enum RunState<Result> { case idle
                        case running(progress: Progress?)   // 对应 calcVM.isRunning
                        case finished(Result)
                        case failed(message: String) }
```

每个 ModeState 内嵌 `var run: RunState<…>`；`CalculationViewModel` 随之退休。**结果窗格 tab 契约**（`(id,title)` 列表 + `selectedResultView` switch）保留，但 tab id 改为 pane 专属枚举且 switch 不写 default，编译期穷尽——修复"漏 case 静默显示默认视图"的既有坑。

### 6.4 现有特殊机制 → 新架构映射

| 现状机制 | 新架构落点 |
|---|---|
| `BackendClient.run` 的 spawn/超时/取消/stderr 进度 | `DaemonTransport`（协议 `BackendTransport.submit(_:) -> AsyncThrowingStream<Envelope, Error>`）+ `Effect(id:)` 取消；`ColdStartTransport` 封装现有 Process 逻辑 |
| `RectifyClient` 的 stderr `{"progress":…}` | daemon `event/progress`；RectifyStore 的 Effect 订阅事件流并投 `Action.progress(…)` |
| rectify 三级级联（L1 手动触发，L2/L3 slider 停止自动触发） | RectifyReducer 内 `Action.levelDidSettle(level)` → 副作用 Effect 发起下一级请求；级联逻辑从 View 移入 reducer，成为可单测纯逻辑 |
| AI 流式（`LLMAnalysisClient` SSE + 100ms 节流 + 流末落盘） | AI Effect：`Effect.stream(bytes.lines)` 内部 `throttle(100ms)` 投 `Action.chunk`；`Action.streamEnd` 时一次性写 per-mode 存储与持久化。**禁止 per-token 写 @Published 存储、禁止 body 内解析 markdown**——O(n²) 教训固化为内核注释 |
| `streamKey` 唯一性 | `AIState` 的 streamKey 由 `StreamKeyRegistry`（全局单调）分配，新 AI surface 必须注册，测试断言唯一 |
| 300s watchdog | daemon per-job 超时（§4.3）+ App 侧 Effect 取消兜底 |
| UserDefaults 直写（AppState didSet） | `SessionStore` 唯一写入口；`AppState` 退化为纯 UserDefaults 适配器 |
| profiles/presets JSON 持久化 | `Persistence` 协议注入 SessionStore，effect 写盘；现有 JSON 格式与键名不变（数据迁移零成本） |
| 结果导出 | 见 §7 |

### 6.5 前端目录结构（迁移完成后）

```
Sources/TransitStudio/
  App/                    # TransitStudioApp、AppShell（现 ContentView 的 chrome 骨架）
  Core/
    Store/                # Store/Reducer/Effect/RunState（内核）
    Contract/             # Envelope、ContractRegistry、全部模式 Codable 模型 + fixtures
    Backend/              # BackendTransport、DaemonTransport、ColdStartTransport、EnvironmentDoctor
    Export/               # ExportSection/ExportEngine/ExportRenderer（§7）
    Session/              # SessionState/SessionStore/AppState 适配器
    LLM/                  # LLMAnalysisClient（不变）、AIState、StreamKeyRegistry
    UI/                   # DesignTokens、CollapsibleSection、结果窗格 tab 契约、共享控件
  Modes/
    Natal/  Horary/  KPHorary/  Moment/  Scan/  Rectify/  Vedic/
    Classical/            # classical + 8 个扩展 workspace
    Modern/               # synastry/composite/… 等现代 sub-modes
    （每 Mode 包内：State.swift、Reducer.swift、Views/、ExportSections.swift）
```

迁移期旧文件与新目录并存；旧文件逐个删除，`ContentView` 在最后一个模式迁走后退休。

## 7. 导出体系统一（解决 P1）

核心动作：**每模式只描述一次"导出内容"（Section 树），三种格式由引擎渲染**。

```swift
struct ExportSection { let id: String; let title: String; let rows: [[String]]; let prose: [String] }
enum ExportRenderer { case markdown, plainText, csv }
protocol ExportableResult { func exportSections() -> [ExportSection] }
enum ExportEngine { static func render(_ sections: [ExportSection], as: ExportRenderer) -> String }
```

- 现有 19 个 `*Exports.swift` 的职责从"拼三种格式字符串"收窄为"构造 Section 树"（模式专属映射逻辑保留，格式模板进引擎）。
- 过渡护栏：引擎的 markdown/plainText/csv 输出必须与现有 `TextExportBuilder`/`Markdown*ExportBuilder` 输出**逐字符一致**（用现有导出测试锁死），不一致视为 bug；逐模式切换，切一个删一套旧 builder。
- 预期收益：约 5,000 行导出代码收敛到约 2,500 行，新增模式的导出成本从三份格式代码降到一份结构描述。

## 8. 打包与分发

- 打包流程不变：`package_app.sh` 继续产出 Swift 二进制 + resource bundle + ad-hoc 签名 + 覆盖 `/Applications`。
- daemon 不随包分发，随 App 首次计算拉起（§4.1）。包内新增 resource：`daemon.port` 模板与 EnvironmentDoctor 文案不需要——daemon 脚本已随 resource bundle 打包，端口文件运行时生成。
- 用户机器缺 python/pyswisseph 时走 §4.6 引导；冷启动路径保持现状行为作为最终兜底。
- 版本策略不变：`package_app.sh` 的 `APP_VERSION/BUILD_VERSION` 是唯一版本源。

## 9. 测试策略

| 层 | 测试 | 说明 |
|---|---|---|
| 契约 | `ContractParityTests`（新） | 同一请求分别走 daemon 与冷启动，深比较输出 JSON（忽略顺序）。全部 `Examples/` 样例 + fixtures 双跑。**这是迁移安全的基石**：任何 daemon 化引入的差异在此暴露 |
| 契约 | `BackendContractTests`（现有，保留） | fixture 解码 + 字段级断言；envelope 化后 fixture 格式更新一次 |
| 后端 | 现有 60+ pytest 文件（保留） | 计算规则回归网不动；daemon 新增 `test_daemon.py`（握手/取消/超时/空闲退出/崩溃重连） |
| 前端 | Reducer 纯函数测试（新） | 状态快照 + Action 序列断言（`ClassicalWorkspaceTests` 风格的全面推广）；rectify 级联、AI 节流、取消竞态都成为纯逻辑测试 |
| 前端 | 现有 Swift 测试（保留） | 视图/导出/请求编码测试按迁移进度改写等价版本，**迁移期间总数只增不减** |
| 集成 | daemon 生命周期 XCTest（新） | 真实 python：spawn→请求→kill→自动重启重放→idle 退出 |

迁移期门禁（每次提交）保持现状：`bash check_vibe_changes.sh`、`swift build && swift test`、pytest、全部 sample smoke（增加 daemon 双跑）。

## 10. 迁移路线图（阶段 0–5，每阶段独立可发布、可停）

| 阶段 | 内容 | 完成判据 | UI 影响 |
|---|---|---|---|
| **0 契约固化** | 逐模式补 JSON Schema；`astro_backend_api.main` 抽 `handle_request`；响应加 envelope（`schema/meta`，`data` 包现状内容）；fixtures 再生成；`ContractRegistry` 上线 | 全部模式有 schema 文档；冷启动响应 envelope 化且 Swift 全绿 | 无（decode 层透明） |
| **1 daemon 上线** | `astro_backend_daemon.py` + `astro_backend_protocol.py`；`DaemonTransport` + `BackendTransport` 协议；`ContractParityTests`；EnvironmentDoctor | daemon 与冷启动输出全样例等价；pytest 新增 daemon 测试全绿；300s 超时按 mode 化 | 无（BackendClient 内部换实现，RectifyClient 先行合流消除 P3） |
| **2 mini-TCA 内核 + 样板模式** | 内核三文件 + 测试；`moment`（最简）完整迁移：MomentState/Reducer/Store/Views/ExportSections，旧 moment 代码删除 | moment 全功能等价（新旧结果 diff 护栏）；reducer 测试落地；内核 ≤500 行 | 无（视觉不变） |
| **3 模式逐个迁移** | 顺序：natal → scan → horary → kp_horary → rectify（级联样板）→ vedic → classical+8 扩展 → 现代家族其余 | 每模式一个分支/PR：该模式新旧等价 + 旧文件删除 + 测试改写 | 逐模式无感替换 |
| **4 导出统一** | `ExportEngine` 上线，逐模式切换 Section 树，删旧 builder | 三种格式输出与现状逐字符一致（测试锁死）；导出代码量减半 | 无 |
| **5 退休 ContentView** | 最后一个模式迁完后删除 `ContentView*` 巨型扩展、`CalculationViewModel`、`RectifyClient` 残留 | 149 @State 归零；`ContentView.swift` 只剩 AppShell chrome | 无（架构性收尾） |

阶段 3 是主战场：每个模式独立垂直切片，单 PR 规模可控，任何一步的回归只影响该模式，CI + 双跑护栏全程兜底。

## 11. 风险与对策

| 风险 | 对策 |
|---|---|
| pyswisseph 在 daemon 长生命周期下内存泄漏/线程问题 | 串行队列 + 空闲自退（10 分钟）把泄漏窗口限在会话内；`ping/stats` 暴露内存与 job 计数 |
| daemon 与 App 版本错配（升级后残留旧 daemon） | 握手交换 schema 列表；不匹配先 kill 再拉起 |
| 迁移期双轨维护成本 | 每模式迁移 PR 必须删除旧实现，不允许并存超过一个 PR 周期；阶段 0/1 是纯增量 |
| 用户环境 python 缺失 | EnvironmentDoctor 引导 + 冷启动兜底（§4.6）；本方案不内嵌运行时是已确认决策 |
| 大范围重构引发功能回归 | 契约双跑 + "新旧结果 diff"护栏 + 迁移期间测试总数只增不减 |
| 内核与官方 TCA 分歧 | 接口保持与 TCA 同构（Store/Reducer/Effect 语义一致），必要时可平移 |

## 12. 与既有文档的关系

- `docs/frontend-refactor/05-viewmodel-extraction.md`：其 ViewModel 抽取思路是本方案 Store 层的先行版本；本方案把"每模式 ViewModel"推进为"值类型 State + 纯 Reducer + 显式 Effect"。
- `docs/schemas/`：已有 4 个包级 JSON Schema 是阶段 0 的种子，其余模式照此补齐。
- `docs/backend-contracts.md`：契约工作流不变，envelope 化后更新该文档。
- `docs/frontend-redesign-2026-07/02-workbench-layout.md`：布局（四栏工作台）与本方案正交，互不冲突。
- `docs/project-audit-2026-07-06.md`：本方案解决的 P0–P5 即该审计的结构性发现。

---

*本方案为设计稿。任何阶段开始实施前，按仓库纪律在 `PLANS.md` 登记任务、开独立分支、遵守契约与测试门禁。*
