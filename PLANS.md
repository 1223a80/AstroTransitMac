# 规范化计划

## 2026-06-02 — 为项目引入 Git 仓库

**任务**：将当前 `AstroTransitMac` 目录从普通文件夹转换为可审查、可追踪的 Git 仓库，为后续分支与 worktree 协作打基础。

**方案**：
1. 检查并补齐 `.gitignore`，确保 `.build/`、`dist/`、缓存和本地工具目录不会进入基线版本
2. 在项目根目录执行 `git init`，建立本地仓库并固定默认主分支为 `main`
3. 校验 Git 身份配置；若本机已配置 `user.name` / `user.email`，则将当前源码树作为首个基线提交，否则保留未提交状态并记录下一步

**验证**：
- `git status --short --branch`
- `git rev-parse --is-inside-work-tree`
- 如可提交，再验证 `git log --oneline -1`

**执行记录**：
- 已补充 `.gitignore`：忽略 `.opencode/`
- 已执行 `git init -b main`，仓库初始化成功
- `git rev-parse --is-inside-work-tree` 返回 `true`
- `git status --short --branch` 显示当前为 `No commits yet on main`
- `git config --get user.name` / `user.email` 均为空，首个基线提交暂不能安全创建
- 用户已提供提交身份，下一步将写入仓库本地配置并创建首个基线提交
- 用户随后更正提交身份为 `katou <whatismorethat@gacu.com>`；需同步修正本地仓库配置并改写刚创建的基线提交作者
- 用户已在 GitHub 创建空仓库 `1223a80/AstroTransitMac`；下一步为添加 `origin` 并执行首次 `git push -u origin main`
- 已添加 `origin = https://github.com/1223a80/AstroTransitMac.git`
- 首次 `git push -u origin main` 失败：`could not read Username for 'https://github.com': Device not configured`
- 本机不存在 `~/.ssh` 目录，当前最短路径是补 GitHub HTTPS 认证（PAT）或改走 SSH 配置

## 2026-06-02 — 现代占星计算规则文档

**任务**：为后续小模型驱动的 coding agent 提供一份可直接参考的现代占星计算规则，避免其自行猜测 synastry / composite / davison / progressions / solar arc / pattern detection 的算法。

**方案**：
1. 新增根目录 `计算规则.md`，只写计算规则、输入输出约定、边界条件与测试重点
2. 规则按“公共规则 + 各模块算法 + 验证要求”组织，尽量贴近现有 Python/Swift 架构
3. 明确哪些是外部通行定义，哪些是本项目 v1 约定，降低实现分歧

**验证**：文档型改动，不跑编译；人工核对与现有 `astro_backend_core.py` / `astro_backend_scan.py` / `OptionModels.swift` 一致

## 三阶段路线

### 阶段 A：跨语言错误协议（止血）

**问题**：Python 5 处 `except Exception` 静默吞掉子模块错误（primary_directions / circumambulations / prenatal_syzygy / almuten / hyleg），Swift 端展示空列表而非"计算失败"。

**方案**：
1. Python `calculate_classical()` 收集 `section_errors: dict[str, str]`，每个 `except` 同时记录 `section_errors[name] = str(exc)`
2. Swift `ClassicalResult` 新增 `sectionErrors: [String: String]?`
3. UI + 导出端展示 sectionErrors

**验证**：`swift build` + `swift test` + `pytest python_tests/test_classical.py`

---

### 阶段 B：共享常量 + 契约测试（防漂移）

**问题**：~50 个 magic string（mode/house/zodiac/bounds/triplicity/body_id/aspect_id）在 Swift 和 Python 各自硬编码，无编译期检查。

**方案**：
1. Python 新建 `astro_backend_constants.py` 导出所有常量枚举
2. Swift 新建 `AstroConstants.swift` 声明匹配 enum
3. 新建 `test_constants.py` — 从 Swift 解析枚举值，断言与 Python constants 完全匹配

**验证**：`python3 -m pytest python_tests/test_constants.py` — 失败时明确列出不一致字段

---

### 阶段 C：RectifyClient 超时 + 请求/响应验证

**问题**：`RectifyClient` 无超时机制；Swift 和 Python 均无输入校验。

**方案**：
1. `RectifyClient` 增加与 `BackendClient` 对等的超时机制
2. Swift `run*()` 方法在序列化前增加轻量校验（必填字段、经纬度范围）
3. Python 入口增加 `validate_request()` 返回 `{"missing": [...]}`

**验证**：非法输入显示 Swift 端错误而非 Python `KeyError`

---

## 当前进度

### 2026-06-01

**阶段 A 完成** ✓

- Python: `astro_backend_api.py` — 5 个子模块 `except Exception` 同时记录 `section_errors[name] = str(exc)`
- Swift: `ClassicalResult` 新增 `sectionErrors: [String: String]?`
- UI: `SectionErrorList` 视图展示在 `WarningList` 下方
- Markdown 导出: `sectionErrorBlock()` 在「警告」节下方输出子模块错误
- Text 导出: 增加 `section_error` 类型的 CSV 行
- 验证: `swift build` 通过, `swift test` 10 passed, `pytest` 155 passed
- Smoke test 确认正常响应时 `section_errors: null`

**阶段 B 完成** ✓

- Python: `astro_backend_constants.py` — 11 组共享常量 + 中文标签
- Swift: `AstroConstants.swift` — 对称枚举
- Python 契约测试: `test_constants.py` — 3 个测试，regex 提取 Swift 源并与 Python 值逐项比较
- 验证: `pytest` 158 passed (+3), `swift build` 通过, `swift test` 10 passed

**阶段 C 完成** ✓

- `RectifyClient` — 新增 60s 超时 + `ContinuationGuard` 防重复 resume
- `astro_backend_api.py` — `validate_required_fields()` 入口输入校验
- 验证: `pytest` 158 passed, `swift build` 通过, `swift test` 10 passed

### 三阶段全部完成 ✓

### 补丁（同一 session）

修正三项未完全落地的问题：
1. **Rectify 验证不完整** — 补全 `timezone`/`latitude`/`longitude` 校验；`BackendErrorResponse` + `tryDecodeBackendError()` 使两种客户端都能解析后端错误 dict
2. **常量文件非 source of truth** — 补全 `quintile`/`biquintile`（仍属契约测试层级，非运行时强制引用）
3. **RectifyClient 进度非实时** — `stderr` 改为 `Pipe` + `readabilityHandler` 实时解析 progress

### 2026-06-02

**现代占星计算规则文档完成** ✓

- 新增根目录 `计算规则.md`
- 覆盖公共规则、Synastry、Composite、Davison、Secondary Progressions、Solar Arc、Pattern Detection
- 明确节点/Lilith/Vertex、circular midpoint、orb、pattern 阈值、输出字段、测试重点
- 文档面向“小模型 + agent 实现”场景，强调 deterministic project rules

## 2026-06-02 — 三阶段规范化改动核查

**任务**：核查“三阶段规范化”报告中的 A/B/C 改动是否真实落地，重点找出协议遗漏、契约不一致、验证缺口与潜在回归。

**方案**：
1. 逐个阅读报告列出的 Swift / Python / 测试文件，确认实现与对外契约一致
2. 按代码审查方式检查错误路径、常量同步策略、超时与 continuation 生命周期是否存在漏洞
3. 运行最小必要验证，核对报告中声称的测试覆盖与实际行为是否匹配

**验证**：优先运行相关 Python 契约测试；如环境允许，再运行 `swift build` / `swift test`

**执行记录**：
- 已核对阶段 A/B/C 涉及的 Swift、Python、导出与测试文件
- `python3 -m pytest python_tests/test_contracts.py python_tests/test_constants.py` 通过（26 passed）
- `swift build` 通过
- `swift test` 需沙箱外模块缓存权限；经授权后通过（10 tests passed）
- 额外 smoke：`{"mode":"rectify","birth_date":"1990-01-01","center_time":"12:00"}` 实际返回 `{"error":"Invalid request: 'timezone'"}`，并非报告声称的结构化 `missing` 响应

## 2026-06-02 — 现代占星实现（Python + Swift 模型层）

按 `计算规则.md` 实现 6 个现代占星模块的 Python 计算层 + Swift 模型层。

### 完成情况

| 阶段 | 内容 | Python | Swift 模型 | 测试 | 状态 |
|------|------|--------|-----------|------|------|
| 1 | circular_midpoint + Pattern Detection | ✓ | ✓ | 25 tests | 完成 |
| 2 | Synastry | ✓ | ✓ | 6 tests | 完成 |
| 3 | Composite | ✓ | ✓ | 5 tests | 完成 |
| 4 | Davison | ✓ | ✓ | 5 tests | 完成 |
| 5 | Secondary Progressions | ✓ | ✓ | 10 tests | 完成 |
| 6 | Solar Arc | ✓ | ✓ | 8 tests | 完成 |
| 7 | 收尾 — sample requests + CHANGELOG | ✓ | ✓ | ✓ | 完成 |

**未完成（需下一 session）：**
- Swift UI 层：侧边栏控件、结果面板视图、导出、ChartWheel 适配
- `ModernSubMode` 需接入 `AppNavigationRail` + `ContentView` 调度
- Python 端 contract test (`test_contracts.py`) 新增 5 个新模式的 subprocess 测试
- 需用户确认 UI 布局方案

## 2026-06-02 — 现代模块交付核查

**任务**：核查现代占星模块交付报告是否与当前代码一致，重点确认 mode 分发、Swift 模型可解码性、测试覆盖与“剩余风险”表述是否准确。

**方案**：
1. 阅读 Python 新模块、`astro_backend_api.py`、Swift 模型与客户端，核对报告中的文件级变更
2. 检查新 mode 是否已接入运行时分发，但尚未接入 UI 调度
3. 运行针对性的 pytest / smoke / Swift 构建，确认报告中的验证数据与实际相符

**验证**：优先运行现代模块相关 pytest；如环境允许，再跑 `swift build`

**执行记录**：
- 已核对 `astro_backend_api.py`、6 个现代 Python 模块、`ModernResultModels.swift`、`ModernBackendClient.swift`、`AstroConstants.swift`
- `python3 -m pytest python_tests/test_patterns.py python_tests/test_modern_relationship.py python_tests/test_modern_timebased.py` 通过（58 passed）
- `python3 -m pytest python_tests` 通过（216 passed）
- `swift build` 通过
- 5 个 sample request 已跑 smoke；其中 `synastry` / `progression` 正常，`composite` / `davison` / `solar_arc` 均返回 `patterns` 子模块错误
- 额外缺字段 smoke 显示：现代新 mode 的 `validate_required_fields()` 仍未覆盖嵌套字段，缺 `person_a.latitude` 或 `reference.year` 时仍直接报 `计算失败：'latitude'` / `计算失败：'year'`

## 2026-06-02 — 现代 UI + Harmonic 交付核查

**任务**：核查现代模式 Swift UI 全链路和 Harmonic 模块交付是否与报告一致，重点确认导航/运行调度/结果面板已接通，剩余风险表述是否准确。

**方案**：
1. 核对 Swift 导航、侧边栏、run action、结果页、ChartWheel/导出/AI tab 的实现状态
2. 核对 Python `astro_backend_harmonic.py` 与 `astro_backend_patterns.py` 的新增能力
3. 复跑 `pytest`、`swift build`、`swift test` 和 harmonic smoke

**验证**：`python3 -m pytest python_tests`、`swift build`、`swift test`、harmonic smoke
