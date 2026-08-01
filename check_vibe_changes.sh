#!/bin/bash
# check_vibe_changes.sh
# 给完全不懂编程的我用的“接受 agent 改动前一键检查”脚本
# 用法：bash check_vibe_changes.sh
# 或者直接在 Finder 里双击（如果有执行权限）

set -euo pipefail

echo "========================================"
echo "Vibe Coding 改动验证脚本"
echo "========================================"
echo

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# 优先用项目自带的 .venv（系统 python3 升级后可能缺 pytest 等依赖）
PY="python3"
if [ -x "$ROOT_DIR/.venv/bin/python" ]; then
  PY="$ROOT_DIR/.venv/bin/python"
fi

echo "1. Python 后端测试..."
"$PY" -m pytest python_tests/ -q || { echo "❌ Python 测试失败"; exit 1; }
echo "✅ Python 测试通过"
echo

echo "2. Swift 构建..."
swift build --disable-sandbox 2>&1 | tail -5 || { echo "❌ Swift build 失败"; exit 1; }
echo "✅ Swift build 成功"
echo

echo "2b. Swift 测试（解码契约 + 导出）..."
swift test --disable-sandbox 2>&1 | tail -2 || { echo "❌ Swift 测试失败"; exit 1; }
echo "✅ Swift 测试通过"
echo

echo "3. 关键 smoke 测试（legacy + modern return/timing/midpoint + rectify）..."
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json > /dev/null && echo "✅ classical smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json > /dev/null && echo "✅ moment smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-scan-request.json > /dev/null && echo "✅ scan smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-horary-request.json > /dev/null && echo "✅ horary smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json > /dev/null && echo "✅ vedic smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-harmonic-request.json > /dev/null && echo "✅ harmonic smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-solar-return-request.json > /dev/null && echo "✅ modern solar return smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-lunar-return-request.json > /dev/null && echo "✅ modern lunar return smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-timing-request.json > /dev/null 2>&1 && echo "✅ modern timing smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-midpoint-request.json > /dev/null && echo "✅ midpoint smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-timing-midpoint-request.json > /dev/null 2>&1 && echo "✅ timing midpoint smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-timing-composite-request.json > /dev/null 2>&1 && echo "✅ timing composite smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-timing-davison-request.json > /dev/null 2>&1 && echo "✅ timing davison smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-progressed-composite-request.json > /dev/null && echo "✅ progressed composite smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-relocation-request.json > /dev/null && echo "✅ relocation smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-cycles-request.json > /dev/null && echo "✅ modern cycles smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-astrocartography-request.json > /dev/null && echo "✅ astrocartography smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-local-space-request.json > /dev/null && echo "✅ local space smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-declination-timing-request.json > /dev/null && echo "✅ declination timing smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-mercury-return-request.json > /dev/null && echo "✅ modern mercury return smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-retrograde-cycles-request.json > /dev/null && echo "✅ retrograde cycles smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-visibility-request.json > /dev/null && echo "✅ classical visibility smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-planetary-synodic-request.json > /dev/null && echo "✅ planetary synodic smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-hellenistic-condition-audit-request.json > /dev/null && echo "✅ hellenistic condition audit smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-draconic-heliocentric-request.json > /dev/null && echo "✅ draconic heliocentric smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-mundane-electional-request.json > /dev/null && echo "✅ mundane_electional smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-orbital-dial-request.json > /dev/null && echo "✅ orbital_dial smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-prenatal-parans-request.json > /dev/null && echo "✅ prenatal_parans smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-distributions-pd-request.json > /dev/null && echo "✅ distributions_pd smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-primary-directions-audit-request.json > /dev/null && echo "✅ primary_directions_audit smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-method-families-request.json > /dev/null && echo "✅ method_families smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-time-lords-extended-request.json > /dev/null && echo "✅ time_lords_extended smoke OK"
"$PY" Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-derivatives-request.json > /dev/null && echo "✅ classical_derivatives smoke OK"

# rectify 简单 smoke（不要求完整 UI）
echo '{"mode":"rectify","birth_date":"2000-01-01","center_time":"12:00","timezone":"Asia/Shanghai","latitude":31.23,"longitude":121.47,"house_system":"whole_sign","zodiac":"tropical","bounds_system":"egyptian","triplicity_system":"dorothean","max_age":30,"window_minutes":5,"step_minutes":5}' | "$PY" Sources/TransitStudio/Resources/backend/transit_calc.py 2>/dev/null | "$PY" -c 'import json,sys; data=json.load(sys.stdin); assert data.get("total_candidates") == 3' && echo "✅ rectify smoke OK"
echo

echo "4. 个人数据 / 作者痕迹扫描（应该只剩少量明确测试数据）..."
echo "扫描结果（如果很多，说明需要让 agent 清理）："
grep -r "31.2304\|121.4737\|/Users/gacu/资料库/ephe" \
  --include="*.swift" --include="*.py" \
  Sources/ python_tests/ Examples/ 2>/dev/null | wc -l || true
echo "(上面数字越小越好。作者测试数据在 tests/examples 里是允许的，但默认值和 UI 里不应该再出现个人路径)"
echo

echo "5. 最近改动文件一览（让你直观看到 agent 到底动了什么）："
git status --porcelain 2>/dev/null | head -20 || echo "(没有 git 或没有变更)"
echo

echo "========================================"
echo "基础检查完成。"
echo "请再手动确认："
echo "- CHANGELOG.md 最上面是否加了本次改动说明？"
echo "- 如果改了模型或导出，是否对比过同一个输入的导出结果？"
echo "- 如果是新功能，PLANS.md 是否更新了进度？"
echo "========================================"
