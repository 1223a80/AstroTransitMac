# 执行 Agent 开工提示词

把下面这段话原样发给执行 Agent：

---

请在仓库 `AstroTransitMac` 中执行 UI 重设计的第 1 期任务。

1. 先切换/创建分支 `codex/frontend-redesign-2026-07`（从最新 `main` 创建；若分支已存在则直接使用）。
2. 通读 `docs/frontend-redesign-2026-07/00-overview.md` 的全局强约束。
3. 严格按 `docs/frontend-redesign-2026-07/01-dark-mode-tokens.md` 施工，**逐字遵守约束，不要自由发挥**，不要超出"允许改动的文件"清单。
4. 完成后运行 `bash check_vibe_changes.sh`，必须全绿。
5. 按任务书第 7 节核对 DoD，更新 `CHANGELOG.md`、`PLANS.md`、`package_app.sh` 版本号（1.2.0 / 36），提交一笔 commit（不要 push、不要打包）。
6. 报告：改了哪些文件、门禁输出、DoD 逐条自查结果、以及任何被迫偏离任务书的地方。

第 2 期任务书（`02-workbench-layout.md`）在第 1 期验收通过前**不要开工**。

---

## 验收后

第 1 期 diff 验收通过后，把上面提示词中的 `01-dark-mode-tokens.md` 换成 `02-workbench-layout.md`、版本号换成 `1.2.1 / 37`，再次发给执行 Agent。第 3–5 期任务书由评审模型在第 2 期验收后补写。
