<!-- METADATA:SESSION=4 -->

# task_knowledge — task001_simpler_libero_eval_bringup

> 编写规则：每条知识点一段；写明"触发场景 → 解决方法 → 为什么"。不写泛泛之谈。

## 知识点 1 — gymnasium 0.28+ TimeLimit 不透传任意属性

**触发场景**：simpler_env 老代码里 `env.is_final_subtask()` / `env.get_language_instruction()` / `env.advance_to_next_subtask()` / `env.robot_uid` 这类 "直接调 wrapper 下 maniskill env 自定义方法" 的调用。

**现象**：`AttributeError: 'TimeLimit' object has no attribute 'is_final_subtask'`。

**解决**：一律改 `env.unwrapped.X()`。本 PR 在 `maniskill2_evaluator.py` 命中 5 处，在 SimplerEnv 的 `observation_utils.py` 命中 1 处（用 patch file apply）。

**为什么**：老 gym 有 `__getattr__` fallback 透传任意属性到 inner；gymnasium 0.28+ 收紧了 wrapper，只透传白名单（`unwrapped` / `spec` / `np_random` 等）。

## 知识点 2 — LIBERO 容器用 MUJOCO_GL=osmesa 必须装 libosmesa6

**触发场景**：`evaluation/libero/eval_libero.py:8` 设 `MUJOCO_GL=osmesa`；容器 apt 只装了 egl/vulkan，没装 osmesa。

**现象**：PyOpenGL `_ErrorChecker` 初始化抛 `AttributeError: 'NoneType' object has no attribute 'glGetError'`。

**解决**：`apt-get install libosmesa6 libosmesa6-dev`。本 PR 写进 `scripts/setup_libero.sh`。

**为什么**：PyOpenGL 需要找到 GL backend 的 shared lib；osmesa 是纯软件 backend，`MUJOCO_GL=osmesa` 时必须有 `libOSMesa.so`。

## 知识点 3 — bash `cmd | tee f` 不传播 python crash

**触发场景**：`script/eval/bridge/eval_bridge.sh` 的 `python ... 2>&1 | tee ${eval_dir}/Scene.txt; ...`。

**现象**：python crash 但 bash exit=0，trap 打印"eval end exit=0"误认为成功。

**解决**：`set -o pipefail`（但会改变整个脚本语义，慎用），或直接读 python 的 stdout/stderr 确认成功。本 PR 暂不改，因风险大；后续任务里单独评估。

**为什么**：pipe 的 `$?` 来自最后一个 stage（tee，永远成功）；bash 默认不看中间 stage 的退出码。

## 知识点 4 — MemoryVLA 的 `.gitignore:107` 的 `env/` 误伤 SimplerEnv

**触发场景**：想把 `third_libs/SimplerEnv/.../utils/env/observation_utils.py` 改动 commit。

**现象**：`git add` 没反应；`git check-ignore` 显示 `.gitignore:107:env/`。

**解决**：`.gitignore` 里 `env/` 改成 `/env/`（只匹配 root）。本 PR 包含这个 fix。

**为什么**：gitignore 里不带前导 `/` 的模式会在任何层级匹配；本意屏蔽 python venv 目录，但会误伤所有路径里有 `env/` 段的文件。

## 知识点 5 — `load_vla` 要 LLaMA-2-7b 的 config+tokenizer，权重在 .pt 里

**触发场景**：air-gapped 容器跑 LIBERO / Bridge eval。

**现象**：`transformers.AutoConfig.from_pretrained('meta-llama/Llama-2-7b-hf')` 因 HF 不可达失败。

**解决**：`MEMVLA_LLAMA2_7B_LOCAL_PATH` 指向本地镜像目录（含 config.json / tokenizer.model / tokenizer_config.json）。LLaMA 权重本身在 ckpt .pt 里，不需要从 HF 拉。`scripts/setup_libero.sh` step 9a 自动 materialize 这个本地镜像目录。

**为什么**：`prismatic/models/backbones/llm/llama2.py` 用 `AutoConfig.from_pretrained` 加载 config 骨架，再从 .pt 灌权重。只需要 config+tokenizer 的 "mirror"，不需要 weight 文件。

## 知识点 6 — 跨 fork PR 的 base 选择（重要！）

**触发场景**：GitHub UI 上点 "Create pull request" 时，base 分支下拉默认会 fallback 到 upstream fork 的 default branch。

**现象**：你以为是把 PR 打到自己的 fork（`StevenKKXS:openvla-codebase`），结果 base 被设成了 upstream（`shihao1895:openvla-codebase`）。PR 能开，但 merge 权限在 upstream owner 手里，不在你自己手里；同时也把你的"内部进展"当众 PR 给了 upstream，噪声。

**解决**：
- 跨 fork base 无法通过 API/UI 编辑，必须关掉 PR 重开
- 打直达链接 `https://github.com/<YourFork>/MemoryVLA/compare/<base>...<head>?expand=1` 直接 compare 同 repo 内的两个分支，避免被 GitHub 默认选 upstream
- 例：`https://github.com/StevenKKXS/MemoryVLA/compare/openvla-codebase...intern_memvla_developer/task001_simpler_libero_eval_bringup?expand=1`

**为什么**：GitHub "compare across forks" 默认假设你开 PR 是给 upstream 贡献的。想在 fork 内部 merge，base 必须明确指到自己 fork。一旦 PR 创建后无法再跨 fork 切换 base owner，只能 close + 重开。

## 知识点 7 — Feature branch 自包含、但外部资产不在 git

**触发场景**：别人（或未来的自己）想从本 PR 分支复现。

**解决**：
1. `git checkout intern_memvla_developer/task001_simpler_libero_eval_bringup`
2. 跑 `scripts/setup_libero.sh`（装 venv + 补齐 HF 本地镜像）
3. clone `third_libs/SimplerEnv/` 并 apply `scripts/patches/simpler_env_observation_utils.patch`
4. 下 ckpt + HF cache（git 里没有，太大）

**为什么**：`.gitignore` 屏蔽了 `third_libs/` / `cache/` / `ckpts/`。这是 MemoryVLA repo 的设计选择（这些是外部资产，不进 git）。
