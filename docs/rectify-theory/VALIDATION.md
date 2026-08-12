# 生时矫正理论内核验证

## 本地自动验证

```bash
python3 -m pytest python_tests/test_rectify_evidence.py -q
python3 Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-rectify-evidence-request.json > /tmp/rectify-evidence.json
python3 -m json.tool /tmp/rectify-evidence.json > /dev/null
```

聚焦测试同时用 `docs/schemas/rectification-evidence-packet-1.0.json` 校验证据包实例，防止文档契约与实现漂移。

聚焦测试应覆盖：

- 含黄纬的黄道→赤道转换；
- 赤道纬度 AD=0 与绕极升降不可得；
- 人为放在四轴上的星体产生零方向弧；
- key profile、方法状态和高精度年龄/时刻字段；
- 事件窗口、source quality、confidence、holdout；
- 候选网格和绝对时间偏移；
- 方法家族与独立性组不合并；
- packet 不输出最佳候选或总分；
- API 必填、坐标范围和工作量限制。

## 外部数值交叉验证

`primary_motion_planet_to_angles_v1` 在进入任何评分、排名或唯一时间推荐前必须完成下列验证。目前状态为 **待完成**，因此 UI 只能按原始证据展示，profile 仍明确标为“角度几何子集”，而不是完整主限。

1. 建立至少 12 个参考盘：南北半球、赤道、高纬、昼夜、四个象限、显著黄纬。
2. 与至少一个公开可审计实现逐项比较：RA、Dec、AD、OA/OD、ARMC、signed arc。
3. 对 MC/IC 与 ASC/DSC 分别设置不超过 1 角分的容差目标；超差必须记录公式和 convention 差异，不能通过放大容差掩盖。
4. 绕极样本必须只降级升降方向，不伪造数值。
5. Naibod 和 1° key 应仅改变年龄换算，不改变方向弧。

## 回测协议（未来评分前置条件）

未来任何候选排名都必须先通过盲化恢复测试：

1. 只使用有原始出生记录、时区和地点可核实的样本。
2. 隐藏真实出生时间，在固定 ±窗口内生成候选。
3. 训练事件与至少两个 holdout 事件分离。
4. 同时加入随机日期或普通日期作为负对照，量化多重比较产生的偶然命中。
5. 在查看真实时间前冻结方法、aspect、orb 和权重。
6. 报告 Top-N 恢复率、分钟绝对误差、候选区间宽度和失败样本，不只展示成功个案。

在该协议完成前，`family_hit_counts` 只能用于调试和可视化，不能解释为概率或可靠度。

## 许可证与参考实现

Morinus 源码采用 LGPL-3.0。当前实现只参考其公开的方法范围和 speculum 术语，核心公式在本项目中独立编写；没有复制或链接 Morinus 代码。如果未来引入其实现或测试数据，必须先单独完成许可证审查和归属记录。
