# Rectification Evidence Packet 字段字典

## 请求

### 顶层

| 字段 | 类型 | 必需 | 说明 |
|---|---|---:|---|
| `mode` | string | 是 | 固定为 `rectify_evidence` |
| `birth` | object | 是 | 标准 BirthSettings；必须含精确 `moment`、经纬度 |
| `events` | array | 是 | 1...20 个事件窗口 |
| `display_timezone` | string | 是 | Modern Timing 输出使用的 IANA 时区 |
| `candidate_window_seconds` | int | 否 | 中心时刻两侧窗口，默认 1800 |
| `candidate_step_seconds` | int | 否 | 候选步长，至少 1，默认 60 |
| `max_candidates` | int | 否 | 工作量硬上限，默认 121 |
| `target_angle_ids` | string[] | 否 | `ASC/MC/DSC/IC` 的非空子集 |
| `primary_direction_keys` | string[] | 否 | `naibod_mean`、`one_degree_per_year` |
| `timing_techniques` | object[] | 否 | Modern Timing technique 子集；这里只允许 aspect |
| `max_age` | number | 否 | 主运动方向年龄上限，默认 120 |
| `max_evidence_rows_per_family` | int | 否 | 每事件/方法返回 1...100 行，默认 12 |
| `confirmed_heavy_scan` | bool | 否 | 透传 Modern Timing 工作量确认；不绕过候选总数上限 |

### `birth`

沿用项目标准 BirthSettings：

- `moment.year/month/day/hour/minute/timezone`
- 可选 `moment.second/fold`
- `latitude`：finite，-90...90
- `longitude`：finite，-180...180
- `houseSystem` / `house_system`
- `zodiac`

候选偏移按绝对 UTC 秒移动，再转换回出生时区，避免把 DST 跳时当作普通墙钟加法。

### `events[]`

| 字段 | 类型 | 必需 | 说明 |
|---|---|---:|---|
| `id` | string | 是 | 非空且唯一 |
| `start` | ChartMoment | 是 | 事件窗口起点 |
| `end` | ChartMoment | 是 | 必须晚于 start |
| `category` | string | 否 | 如 career、relationship、health；后端不解释 |
| `description` | string | 否 | 人类备注 |
| `source_quality` | enum | 否 | 默认 `approximate` |
| `confidence` | number | 否 | finite 0...1；默认 1，不参与当前评分 |
| `holdout` | bool | 否 | 是否保留作样本外复核 |

## 响应

### 顶层

| 字段 | 说明 |
|---|---|
| `schema` | `rectification-evidence-packet/1.0` |
| `meta` | mode、候选/事件数、口径以及非科学验证声明 |
| `requested_config` | 原始出生基准、实际候选上限/窗口、key、角度、年龄、截断与 heavy-scan 配置，以及完整的生效 `timing_techniques` |
| `method_profiles` | 每个方法的状态、角色、独立性组与限制 |
| `events` | 去除内部 datetime 后的规范化原始事件 |
| `candidates` | 候选证据数组 |
| `warnings` | 去重后的计算警告 |
| `calculation_assumptions` | 必须随 packet 保留的解释边界 |

### `candidates[]`

| 字段 | 说明 |
|---|---|
| `offset_seconds` | 相对原出生时刻的绝对秒偏移 |
| `birth_local` / `birth_utc` | 候选时刻 |
| `house_system` | 实际宫制标签 |
| `angles` | 候选轴点及 Swiss Ephemeris 可用的其他角度 |
| `family_hit_counts` | 各方法的原始窗口命中数；不是评分 |
| `evidence_by_event` | 按事件分开的证据包 |
| `warnings` | 仅该候选产生的警告 |

### `evidence_by_event[]`

- `primary_motion`
  - `window_hit_count`
  - `nearest_distance_days`
  - `evidence[]`
- `families.transit`
- `families.secondary_progression`
- `families.solar_arc`
  - `exact_hit_count`
  - `independence_group`
  - `evidence[]`
- `timing_meta`
- `section_errors`

`truncated=true` 只说明返回行数被 `max_evidence_rows_per_family` 截断；命中计数仍基于截断前结果。

## 明确不存在的字段

v1 不输出：

- `aggregate_score`
- `best_candidate`
- `confidence_interval`
- `rectified_birth_time`

这些字段需要独立的校准数据、评分模型和应用层决策，不能由证据计数直接推导。

响应的可机读约束见 `docs/schemas/rectification-evidence-packet-1.0.json`。Schema 固定证据包骨架和本模块生成的字段；复用的 Modern Timing 单条 evidence 允许随其自身契约向后兼容扩展。
