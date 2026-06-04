# Vedic AI Export Full Port Plan

本文件是给后续实现 agent 的直接执行说明。目标不是“补几个字段”，而是把当前 `vedic` 模式扩展到接近 `Examples/sample-vedic-ai-expected.txt` 的完整 AI 导出能力。

## 0. 先读这些文件

### 本地产品代码（source of truth）

- Python 入口
  - `Sources/TransitStudio/Resources/backend/transit_calc.py`
  - `Sources/TransitStudio/Resources/backend/astro_backend_api.py`
- 当前 Vedic 实现
  - `Sources/TransitStudio/Resources/backend/astro_backend_jyotish.py`
  - `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_data.py`
  - `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_varga.py`
  - `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_shadbala.py`
  - `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_yoga.py`
- Swift 接线
  - `Sources/TransitStudio/RequestModels.swift`
  - `Sources/TransitStudio/BackendClient.swift`
  - `Sources/TransitStudio/ContentView+RunActions.swift`
  - `Sources/TransitStudio/VedicResultModels.swift`
  - `Sources/TransitStudio/VedicResultViews.swift`
  - `Sources/TransitStudio/ContentView+ResultsPanes.swift`
  - `Sources/TransitStudio/MarkdownVedicExportBuilder.swift`
  - `Sources/TransitStudio/MarkdownExportBuilder.swift`
  - `Sources/TransitStudio/TextExportBuilder.swift`
- 当前测试
  - `python_tests/test_jyotish_smoke.py`
  - `python_tests/test_jyotish_reference_verify.py`

### 本地离线参考仓库（已抓下）

- 仓库根目录：`maitreya8-reference/`
- 重点目录：`maitreya8-reference/src/jyotish/`

### 必须对照的 `maitreya8` 计算文件

这些文件的算法、表、输出组织要被**重写为 Python**，不要在 Swift 重算：

- `maitreya8-reference/src/jyotish/Nakshatra.cpp`
- `maitreya8-reference/src/jyotish/Nakshatra.h`
- `maitreya8-reference/src/jyotish/Varga.cpp`
- `maitreya8-reference/src/jyotish/Varga.h`
- `maitreya8-reference/src/jyotish/VargaHoroscope.cpp`
- `maitreya8-reference/src/jyotish/VargaHoroscope.h`
- `maitreya8-reference/src/jyotish/VimsottariDasa.cpp`
- `maitreya8-reference/src/jyotish/VimsottariDasa.h`
- `maitreya8-reference/src/jyotish/AshtottariDasa.cpp`
- `maitreya8-reference/src/jyotish/AshtottariDasa.h`
- `maitreya8-reference/src/jyotish/KalachakraDasa.cpp`
- `maitreya8-reference/src/jyotish/KalachakraDasa.h`
- `maitreya8-reference/src/jyotish/Dasa.cpp`
- `maitreya8-reference/src/jyotish/Dasa.h`
- `maitreya8-reference/src/jyotish/DasaConfig.cpp`
- `maitreya8-reference/src/jyotish/DasaConfig.h`
- `maitreya8-reference/src/jyotish/DasaTool.cpp`
- `maitreya8-reference/src/jyotish/DasaTool.h`
- `maitreya8-reference/src/jyotish/ShadBala.cpp`
- `maitreya8-reference/src/jyotish/ShadBala.h`
- `maitreya8-reference/src/jyotish/Yoga.cpp`
- `maitreya8-reference/src/jyotish/Yoga.h`
- `maitreya8-reference/src/jyotish/YogaConfig.cpp`
- `maitreya8-reference/src/jyotish/YogaConfig.h`
- `maitreya8-reference/src/jyotish/Jaimini.cpp`
- `maitreya8-reference/src/jyotish/Jaimini.h`
- `maitreya8-reference/src/jyotish/Ashtakavarga.cpp`
- `maitreya8-reference/src/jyotish/Ashtakavarga.h`
- `maitreya8-reference/src/jyotish/VedicPlanet.cpp`
- `maitreya8-reference/src/jyotish/VedicPlanet.h`
- `maitreya8-reference/src/jyotish/Horoscope.cpp`
- `maitreya8-reference/src/jyotish/Horoscope.h`
- `maitreya8-reference/src/jyotish/BasicHoroscope.cpp`
- `maitreya8-reference/src/jyotish/BasicHoroscope.h`
- `maitreya8-reference/src/jyotish/Ephemeris.cpp`
- `maitreya8-reference/src/jyotish/Ephemeris.h`

### 只作输出组织参考，不要移植成 Swift 算法

- `maitreya8-reference/src/jyotish/GenericTableWriter.cpp`
- `maitreya8-reference/src/jyotish/GenericTableWriter.h`
- `maitreya8-reference/src/jyotish/TextHelper.cpp`
- `maitreya8-reference/src/jyotish/TextHelper.h`
- `maitreya8-reference/src/jyotish/Sheet.cpp`
- `maitreya8-reference/src/jyotish/Sheet.h`
- `maitreya8-reference/src/jyotish/HtmlExporter.cpp`
- `maitreya8-reference/src/jyotish/PrintoutTextHelper.cpp`
- `maitreya8-reference/src/jyotish/PrintoutTextHelper.h`

## 1. 许可与实现边界

- 允许做“规则移植 / 公式重写 / 常量表重录入”。
- 不允许大段直接复制 GPL 源码文本到本项目。
- Python 负责所有占星计算。
- Swift 只负责：
  - 请求发起
  - Codable 模型
  - 结果视图
  - Markdown / CSV / JSON 导出

## 2. 交付目标

把当前 `vedic` 输出扩展到至少覆盖 `Examples/sample-vedic-ai-expected.txt` 的这些 section：

1. 基本信息
2. 重要设置
3. 星座索引表（可选，若已有静态映射可导出）
4. Panchanga
5. 日出日落
6. 分盘信息
7. Moon Chart
8. Bhava Chart
9. D1 星体敌友关系（天然 / 临时 / 复合）
10. Arudha
11. Yogas
12. Jaimini Karakas
13. Ashtakavarga（BAV + SAV）
14. Vimsottari Dasa（含 Antardasha）
15. Shadbala

目标是**输出能力接近样例**，不是逐字符复制样例文本。

## 3. 后端结果契约

扩展 `calculate_vedic()` 返回 JSON。所有新增字段先定义成稳定 schema，再接 Swift。

### 3.1 `meta` 扩展

保留现有字段，并新增：

- `timezone_label`
- `utc_offset_text`
- `sidereal_mode_label`
- `ayanamsha_value`
- `node_mode`
- `planet_position_mode`
- `sign_index_table`

### 3.2 Panchanga / solar day

新增：

- `panchanga`
  - `tithi`
  - `vara`
  - `nakshatra`
  - `yoga`
  - `karana`
- `solar_day`
  - `sunrise_local`
  - `sunset_local`

每项保留：

- `index`
- `name_sa`
- `name_zh`
- `start_longitude` 或同等区间字段
- `end_longitude` 或同等区间字段

### 3.3 分盘总结构

新增：

- `divisional_charts`

`divisional_charts` 至少包含这些 key：

- `D1`
- `D2`
- `D3`
- `D4`
- `D7`
- `D9`
- `D10`
- `D12`
- `D16`
- `D20`
- `D24`
- `D27`
- `D30`
- `D40`
- `D45`
- `D60`

每个 chart 至少包含：

- `chart_id`
- `chart_name`
- `angles`
- `planets`

其中：

- `D1`、`D9` 需要额外输出：
  - `upagrahas`
  - `special_lagnas`
- 其他分盘至少输出“主星摘要”级别的数据。

### 3.4 Moon / Bhava

新增：

- `moon_chart`
- `bhava_chart`

结构尽量复用 `D1` 的 chart schema，不要再发明一套平行结构。

### 3.5 敌友关系

新增：

- `planet_relationships`
  - `naisargika`
  - `temporary`
  - `compound`

`compound` 输出五级结果，直接支持样例里的“大友 / 友 / 中 / 敌 / 大敌 / 临时友 / 临时敌”文本。

### 3.6 Jaimini / Arudha / Ashtakavarga

新增：

- `arudha`
- `jaimini_karakas`
- `ashtakavarga`

`ashtakavarga` 至少包括：

- `sav`
- `bav`

### 3.7 Vimshottari 扩展

现有 `vimshottari.maha_dasas` 继续保留，但每个 Mahadasha 新增：

- `antardashas`

每个 Antardasha 至少包括：

- `lord`
- `start`
- `end`
- `duration_years`

### 3.8 Shadbala 扩展

保留现有：

- `sthāna_bala`
- `dig_bala`
- `kāla_bala`
- `ceṣṭa_bala`
- `naiṣargika_bala`
- `dṛg_bala`
- `shadbala_total`
- `shadbala_rupas`
- `required`
- `percent`

再补：

- `meets_required`
- `required_rupas`
- `display_summary`

## 4. Python 文件拆分要求

不要继续把所有逻辑塞进 `astro_backend_jyotish.py`。新增模块并从主文件调用：

- `astro_backend_jyotish_panchanga.py`
  - Panchanga
  - sunrise / sunset
- `astro_backend_jyotish_divisional.py`
  - divisional chart builder
- `astro_backend_jyotish_aux_points.py`
  - upagrahas
  - special lagnas
- `astro_backend_jyotish_relationships.py`
  - natural / temporary / compound friendship
- `astro_backend_jyotish_arudha.py`
  - AL / A2-A11 / UL
- `astro_backend_jyotish_jaimini.py`
  - Jaimini karakas
- `astro_backend_jyotish_ashtakavarga.py`
  - BAV / SAV

已有文件改造：

- `astro_backend_jyotish.py`
  - 做 orchestration
  - 组装 JSON
- `astro_backend_jyotish_data.py`
  - 集中维护常量与名称表
- `astro_backend_jyotish_varga.py`
  - 继续做分盘公式 source of truth
- `astro_backend_jyotish_shadbala.py`
  - 提升输出细度
- `astro_backend_jyotish_yoga.py`
  - 扩充到样例级 yoga 覆盖

## 5. Swift 改造要求

### 必改

- `Sources/TransitStudio/VedicResultModels.swift`
  - 新增所有 optional Codable 模型
  - 尽量复用现有 `VedicPlanetPosition`、`VedicRasiChart` 风格
- `Sources/TransitStudio/MarkdownVedicExportBuilder.swift`
  - 作为主交付物之一，按样例 section 重构
- `Sources/TransitStudio/TextExportBuilder.swift`
  - 补 CSV 导出
- `Sources/TransitStudio/VedicResultViews.swift`
  - 增加基础 section 浏览能力
- `Sources/TransitStudio/ContentView+ResultsPanes.swift`
  - 给新的结果 section 留入口，不要求复杂交互

### 非目标

- 不要在 Swift 里重写 Panchanga / Ashtakavarga / Jaimini / Upagraha 计算。

## 6. 导出文本的组织顺序

Markdown 导出按这个顺序输出：

1. 基本信息
2. 重要设置
3. 星座索引表
4. Panchanga
5. 日出日落
6. 分盘信息
7. Moon Chart
8. Bhava Chart
9. D1 星体敌友关系
10. Arudha
11. Yogas
12. Jaimini Karakas
13. Ashtakavarga
14. Vimsottari Dasa
15. Shadbala
16. warnings

文本目标：

- 对人类可读
- 对 AI 结构稳定
- 同一 section 的字段顺序固定

## 7. 样例测试基准

实现时使用这两个本地基准文件：

- 请求基准：`Examples/sample-vedic-ai-request.json`
- 期望样例：`Examples/sample-vedic-ai-expected.txt`

要求：

- 用请求基准跑一次 `transit_calc.py`
- 对照期望样例检查 section 是否齐全
- 关键计算（至少 D1、D9、Vimsottari、Shadbala、Ashtakavarga、Jaimini）要做 focused assertions

## 8. 必跑验证

### Python

```bash
python3 -m pytest python_tests/test_jyotish_smoke.py -q
python3 -m pytest python_tests/test_jyotish_reference_verify.py -q
```

新增 focused tests，至少覆盖：

- `panchanga`
- `solar_day`
- `divisional_charts`
- `moon_chart`
- `bhava_chart`
- `planet_relationships`
- `arudha`
- `jaimini_karakas`
- `ashtakavarga`
- `vimshottari.antardashas`

### Swift

```bash
swift build
swift test
```

### End-to-end

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json
```

要求：

- JSON 可成功输出
- Swift `VedicResult` 能解码
- Markdown 导出含所有主要 section

## 9. 实现纪律

- 不要编辑 `dist/`、`.build/`、`__pycache__/`、`.pytest_cache/`
- 查询现有模型和调用点后再改 JSON shape
- 优先扩展现有结构，不新造平行 request/result 类型
- 每做一轮改动都更新 `CHANGELOG.md`
- 完成前看 `git diff --stat` 和完整 `git diff`
- 如果发现与当前工作树里的未提交 Vedic/UI 变更冲突，先读懂再继续，不要覆盖

## 10. review 目标（给后续 reviewer）

review 时重点拷打这些点：

- 有没有偷懒把算法塞到 Swift
- 有没有直接照抄 GPL 大段代码
- 分盘是不是只做了名字没做真实 chart output
- Vimshottari 是否只做 Mahadasha 没做 Antardasha
- Ashtakavarga / Jaimini / Arudha 是否只是占位
- Markdown 导出是不是拼凑文本而不是结构化字段驱动
- 新增 JSON 字段是否都有 Swift Codable 对应
- 是否真的用 `Examples/sample-vedic-ai-request.json` 跑过
