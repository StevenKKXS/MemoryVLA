# intern_memvla_developer - 个人知识库

<!-- METADATA:SESSION=7 -->

> 只沉淀跨任务、长期有用的条目。任务专属的踩坑详解留在 `workspace/tasks/<task_id>/task_knowledge.md`。

---

## 知识条目

### 1. gymnasium 0.28+ 的 wrapper 不透传任意属性

老 `gym` 的 `__getattr__` fallback 会把 `env.foo_method()` 代理到 inner env；`gymnasium 0.28+` 收紧了，只透传 `unwrapped / spec / np_random` 等白名单。凡是要调 wrapper 下自定义方法/属性（如 `env.is_final_subtask()` / `env.robot_uid`），必须 `env.unwrapped.X`。

**来源**：task001，SimplerEnv + MemoryVLA evaluator 有 7 处因此 crash。

### 2. LIBERO 的 `MUJOCO_GL=osmesa` 隐含要装 `libosmesa6`

`evaluation/libero/eval_libero.py:8` 硬编码 `os.environ["MUJOCO_GL"] = "osmesa"`；如果容器只装了 egl/vulkan，PyOpenGL 找不到 backend lib 会抛 `'NoneType' has no attribute 'glGetError'`。apt `libosmesa6 libosmesa6-dev` 修。

### 3. bash `cmd | tee f` 会吞掉 python crash 的 exit code

pipe 的 `$?` 来自最后一个 stage（tee，永远 0）。bash 默认不检查中间 stage，所以 `set -e` 也没用。要么 `set -o pipefail`（可能改变脚本语义），要么直接读 python 输出/检查 return code 而非依赖 bash `$?`。

### 4. MemoryVLA 仓 `.gitignore` 的 `env/` pattern 会误伤 `third_libs/SimplerEnv/.../env/`

不带前导 `/` 的 gitignore pattern 在任何层级匹配。`env/` 本意是屏蔽根目录 venv，结果把 SimplerEnv 的 utility `env/` 子目录也 ignore 了，导致 `git add third_libs/SimplerEnv/.../observation_utils.py` 静默失败。修法：`env/` → `/env/`（task001 PR #1 已 land）。

### 5. load_vla 只要 LLaMA-2-7b 的 config + tokenizer，权重在 ckpt .pt 里

air-gapped 场景下无需下载 LLaMA-2-7b weight 文件；只需要 config.json / tokenizer.model / tokenizer_config.json 的本地镜像，用 `MEMVLA_LLAMA2_7B_LOCAL_PATH` 环境变量指过去即可。`prismatic/models/backbones/llm/llama2.py` 先用 `AutoConfig.from_pretrained` 搭骨架、再从 .pt 灌权重。

### 6. 跨 fork PR 的 base 一旦创建无法跨 fork 修改

GitHub UI 在 "Create PR" 时默认把 base 选到 upstream fork（"compare across forks"）。一旦创建，base 下拉只能切同 repo 内的分支，不能换 fork owner。想把 PR 从 upstream 改回自己 fork，只能 close + 重开。

**避坑**：用直达链接 `https://github.com/<YourFork>/<Repo>/compare/<base>...<head>?expand=1` 强制在自己 repo 内 compare，避免 GitHub UI 默认挑 upstream。

### 7. MemoryVLA eval baseline（2026-04-25 复现）

- **Bridge avg = 0.7292** vs paper 0.7188（差 +1pp 吻合；per-scene: Cube 0.458 / Carrot 0.708 / Spoon 0.750 / Eggplant 1.000）
- **LIBERO-Spatial = 0.886 (443/500)** vs paper 0.984；Task 6 "pick up the black bowl on the ramekin" 是 outlier 0/50，其余 9 task 全 ≥0.94，排除 Task 6 后 avg = 0.984 = paper 精确一致。怀疑 ac_chunking_window=8 + 该 task 初始姿态触发边界。

后续做 ablation 直接引用此 baseline，无需重跑完整 benchmark。完整数据 + 复现命令在 `docs/eval_reproduction.md`。

### 8. 本 fork 的 feature branch 复现完整流程

`git checkout <feature-branch>` 只拿到代码差异。还要：(1) 跑 `scripts/setup_libero.sh` / setup_simpler.sh 装 venv；(2) clone `third_libs/SimplerEnv` 并 apply `scripts/patches/simpler_env_observation_utils.patch`；(3) 下 ckpt 到 `ckpts/{libero,simpler}/`；(4) 下 HF cache 到 `cache/hf/`（DINO + SigLIP + LLaMA-2 config/tokenizer）。外部资产 `third_libs/ / cache/ / ckpts/` 都 gitignore 了，任何 branch 都要单独准备。
