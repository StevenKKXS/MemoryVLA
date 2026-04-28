# intern_memvla_developer - 状态

<!-- METADATA:STATUS=Working,TASK=task002_setup_simpler -->

| 字段 | 值 |
|------|-----|
| Name | intern_memvla_developer |
| Status | Working |
| Current Task | task002_setup_simpler |
| PR | 待主管创建（base `StevenKKXS:openvla-codebase` ← head `StevenKKXS:intern_memvla_developer/task002_setup_simpler`）|
| Session | 8 |

## Session 8（2026-04-28）— task002 补 Simpler setup + doc

主管发现 task001 漏掉 `scripts/setup_simpler.sh`；PAI 容器已下线无法拷 3fs 残留，基于现有记录新写。

### 本次产出
- `scripts/setup_simpler.sh`（255 行，幂等）：apt（vulkan + mesa + osmesa 防身）+ venv `/root/envs/simpler` + numpy<2 pin + torch 2.2.0 + sapien 2.2.2 + transforms3d + clone SimplerEnv + apply `scripts/patches/simpler_env_observation_utils.patch` + ICD 检查 + LLaMA-2-7b 本地镜像 + memvla pip -e + smoke
- `docs/simpler_env_setup.md`（175 行）：独立配套 doc — 硬件/容器要求、外部依赖、6 大踩坑、eval 怎么跑、LIBERO vs Simpler 差异表、交叉引用
- 顺手把 `docs/eval_reproduction.md` §2.1 对 setup_simpler.sh 的引用 + 指向新 doc 完善

### 分支状态
- feature branch `intern_memvla_developer/task002_setup_simpler` 已推 origin
- WIP commit `acb5eaf` 已在 remote；setup_simpler + doc + 接受任务 commit 稍后一并 push

### 下一步
- commit + push 本次产出
- 主管打 PR（直达：`https://github.com/StevenKKXS/MemoryVLA/compare/openvla-codebase...intern_memvla_developer/task002_setup_simpler?expand=1`）
- 等 review

## Session 7（2026-04-26）— task001 merged，收尾

PR #1 已 merge 进 `StevenKKXS:openvla-codebase`（merge commit `2714f4e`），feature branch 完整合入。

### 收尾动作
- status.md → Idle（当前无任务）
- task README METADATA → Completed
- task_knowledge.md 中有价值的知识条目精炼进 `workspace/interns/intern_memvla_developer/knowledge.md`
- 本地 openvla-codebase pull 同步到 2714f4e
- 删除本地 feature branch
- 清理临时 debug/outputs

### task001 最终交付（现已落 openvla-codebase）
- 8 个文件改动 + docs：evaluator unwrap + ENOSPC guard / eval 脚本 / setup_libero.sh / SimplerEnv patch / vla dlimp guard / .gitignore fix / docs/eval_reproduction.md
- 两个 eval 复现结果：
  - Bridge avg **0.7292** vs paper 0.7188 ✅
  - LIBERO-Spatial **0.886**（Task 6 outlier；排除后 9-task avg = 0.984 = paper）

## Session 6（2026-04-26）— PR 重开成功

主管在 StevenKKXS fork 内重开了 PR：**https://github.com/StevenKKXS/MemoryVLA/pull/1**
- base: `StevenKKXS:openvla-codebase`
- head: `StevenKKXS:intern_memvla_developer/task001_simpler_libero_eval_bringup`
- Open，7 commits

### 下一步
- 等主管 review PR #1
- 按 comment 推增量 commit 到 feature branch
- merge 后：删本地分支、status 切回 Idle

## Session 4（2026-04-26 08:00 →）— task001 PR 整合

主管 confirm：一个 PR 整合 6 个 3fs fix + docs，base `openvla-codebase`，task_id `task001_simpler_libero_eval_bringup`。

### 已完成
- 创建 `workspace/tasks/task001_simpler_libero_eval_bringup/`（README/history_log/task_knowledge/PR_BODY）并 push openvla-codebase
- 新建分支 `intern_memvla_developer/task001_simpler_libero_eval_bringup`，WIP 初始化 commit，push -u origin
- 发现 `third_libs/` 被 `.gitignore:107 env/` 规则误屏蔽 → 转为 `scripts/patches/simpler_env_observation_utils.patch` + 顺手 fix `.gitignore`（`env/` → `/env/`）
- 3 个逻辑 commit 推上 feature branch：
  1. `evaluator: unwrap gymnasium wrapper + guard ENOSPC on savefig`（commit 87746c0）
  2. `eval infra: fix scripts + add setup_libero.sh + SimplerEnv patch`（commit 386ef6c）
  3. `vla: guard dlimp import for eval-only envs; add eval reproduction doc`（commit cdbcb13）
- 主管手动在 GitHub UI 创建 PR → https://github.com/shihao1895/MemoryVLA/pull/23（Open，7 commits，base `shihao1895:openvla-codebase`）
- 回答主管"后续复现直接拉 feature branch 是否够用"→ 够（代码层面完整），外部资产 third_libs/cache/ckpts 任何 branch 都要单独准备；详见 history_log Session 1

### Session 3 结果回顾（已在 PR 的 docs/eval_reproduction.md 落档）

| Eval | 我们 | Paper | Δ |
|---|---|---|---|
| Bridge avg | **0.7292** | 0.7188 | +0.010 ✅ |
| LIBERO-Spatial | **0.886** | 0.984 | -0.098 ⚠（Task 6 outlier；排除后 9-task avg = 0.984 = paper）|

### 下一步
- 主管 close PR #23 + 重开到 StevenKKXS fork 内
- 收到新 PR URL 后回写
- 等 review，按 comment 推增量 commit

## Session 6（2026-04-26 → ）— PR 重开成功

主管在 StevenKKXS fork 内重开了 PR：**https://github.com/StevenKKXS/MemoryVLA/pull/1**
- base: `StevenKKXS:openvla-codebase`
- head: `StevenKKXS:intern_memvla_developer/task001_simpler_libero_eval_bringup`
- Open，7 commits

### 下一步
- 等主管 review PR #1
- 按 comment 推增量 commit 到 feature branch
- merge 后：删本地分支、status 切回 Idle

## Session 5（2026-04-26）— PR base 纠偏

### 问题发现
主管发现 PR #23 base 落到了 upstream `shihao1895:openvla-codebase`（不是他自己 fork）。

### 做法
- GitHub 不支持跨 fork 修改 base owner → 必须 close + 重开
- 提供直达 compare URL：`https://github.com/StevenKKXS/MemoryVLA/compare/openvla-codebase...intern_memvla_developer/task001_simpler_libero_eval_bringup?expand=1`
- feature branch 代码未动（remote HEAD = efd403b 维持不变）
- 更新 task_knowledge 知识点 6 强化"base owner 不能跨 fork 修改"

### 结果
主管在 Session 6 成功重开 PR → #1（见上）。
