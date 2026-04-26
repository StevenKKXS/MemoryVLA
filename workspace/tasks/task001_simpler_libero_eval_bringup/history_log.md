<!-- METADATA:SESSION=1 -->

# history_log — task001_simpler_libero_eval_bringup

## Session 0 — 任务创建（2026-04-26）

- 主管 confirm 了 PR 整合方案：一个 PR、base `openvla-codebase`、task_id = `task001_simpler_libero_eval_bringup`
- 扫 clean state 后发现 `third_libs/` 被 `.gitignore:107` 的 `env/` 模式屏蔽 → 改用 patch file + setup 脚本 apply
- 顺手 fix `.gitignore` 的 `env/` → `/env/`（同 PR 内）

## Session 1 — Port + PR 开启（2026-04-26）

### 完成

- 在 openvla-codebase 上建 task 目录（README / history_log / task_knowledge / PR_BODY），commit + push
- 创建 feature branch `intern_memvla_developer/task001_simpler_libero_eval_bringup`，WIP 占位 commit，`push -u origin`
- 3 个逻辑 commit：
  - `87746c0` evaluator: unwrap gymnasium wrapper + guard ENOSPC on savefig
  - `386ef6c` eval infra: fix scripts + add setup_libero.sh + SimplerEnv patch
  - `cdbcb13` vla: guard dlimp import for eval-only envs; add eval reproduction doc
- `63273f8` 接受任务（task README InProgress 标记 + status.md Working + PR_BODY.md）
- setup_libero.sh 去掉 3fs 硬编码，改为 `WORKSPACE=${WORKSPACE:-$(pwd)}`，让任何 clone 都能跑
- `gh` CLI 未装、GH_TOKEN 未暴露 → PR 创建由主管手动完成

### PR 状态

- URL：https://github.com/shihao1895/MemoryVLA/pull/23
- Base：`shihao1895:openvla-codebase`（upstream；原计划是打到主管自己的 fork StevenKKXS:openvla-codebase，但 GitHub UI 默认 fallback 到 upstream 也能用，只是意味着 merge 权限在 shihao1895 那里）
- Head：`StevenKKXS:intern_memvla_developer/task001_simpler_libero_eval_bringup`
- State：Open，7 commits（5 个我这 session push + 此前分支上 2 个 upstream commit 未看）

### 主管提问 & 回答

**Q：后续复现直接拉 `intern_memvla_developer/task001_simpler_libero_eval_bringup` 分支够不够？**

A：够（代码层面完整）。需要补充：
1. 外部资产（third_libs/ / cache/hf/ / ckpts/）任何 branch 都需要
2. 跑 setup_libero.sh / setup_simpler.sh 装 venv
3. 若 PR merge 进 openvla-codebase，clone default branch 更干净（无 WIP.md 占位）
4. 复现手册见 `docs/eval_reproduction.md`（已在本 PR 里）

### 未完

- 等主管 review / 反馈，按 PR comment 推增量 commit
- merge 后：删 WIP.md、本地分支、把 status 切回 Idle
