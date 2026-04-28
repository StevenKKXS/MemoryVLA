# MemoryVLA Simpler (SimplerEnv / Bridge) 环境配置手册

> **适用范围**：在空容器里从零起 MemoryVLA 的 **SimplerEnv / Bridge** eval 所需的环境。LIBERO 那套独立，见 `scripts/setup_libero.sh`。
>
> **最后一次验证**：2026-04-25，在 PAI air-gapped 容器（H100）跑完 4 scene × 24 ep 的 Bridge benchmark，avg success = 0.7292 vs paper 0.7188 ✅。
>
> **状态**：本手册基于 task002 新写。task001 中已验证过的修复都已合到 `openvla-codebase`（PR #1）；本手册只补 Simpler 容器的 setup 脚本和坑。两台 PAI 容器当前已下线，无法再次实地验证脚本，如发现遗漏请更新本手册 + setup 脚本。

---

## 1. 一键跑

```bash
# 在容器里 cd 到 MemoryVLA 仓根
cd /path/to/MemoryVLA
export WORKSPACE=$(pwd)
bash scripts/setup_simpler.sh
```

幂等、可重跑。日志落 `$WORKSPACE/logs/simpler/setup.log`。

---

## 2. 硬件 / 容器要求

| 项 | 值 | 备注 |
|---|---|---|
| GPU | NVIDIA，**必须有 Vulkan 驱动** | sapien 2.2.2 的 renderer 默认走 vulkan；osmesa 软件渲染**不行**（sapien 的 raytracer 没 osmesa backend） |
| NVIDIA Vulkan ICD | `/usr/share/vulkan/icd.d/nvidia_icd.json` | 脚本里 `step 2` 会检查。host 上有、容器里没有的话，bind-mount：`-v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro` |
| Python | 3.10（系统包 `python3.10-venv`）| 跟 LIBERO 一致；3.11+ 不测 |
| torch | 2.2.0 | 跟 MemoryVLA 其他 eval 和 train 一致 |
| numpy | **1.x**（pin 1.26.4）| 2.x 会 break sapien 2.2.2；pin 必须在装 torch **之前** |
| sapien | **2.2.2** | SimplerEnv 上游锁定此版本；3.x 改了 API 不兼容 |
| VRAM | ≥ 40GB（跑 prismatic-7b + DiT-L）| 我们在 H100 80G 上跑 |

---

## 3. 外部依赖（git 里没有，必须单独准备）

### 3.1 `third_libs/SimplerEnv/`

仓库：https://github.com/simpler-env/SimplerEnv

```bash
mkdir -p third_libs
git clone https://github.com/simpler-env/SimplerEnv third_libs/SimplerEnv
# 必须应用我们的 patch（gymnasium 0.28+ 兼容修复）
cd third_libs/SimplerEnv
patch -p0 < ../../scripts/patches/simpler_env_observation_utils.patch
cd ../..
```

setup_simpler.sh step 10 会自动 clone + 应用 patch；如果 air-gapped 无 github 出口，先在 egress box（如 dev4infer `10.100.193.67`）clone 好，再 `rsync` 进容器的 `$WORKSPACE/third_libs/SimplerEnv/`。

SimplerEnv repo 内部自带 `ManiSkill2_real2sim/` 子目录，里面包含 Bridge 真实场景的 rgb inpainting 图（`ManiSkill2_real2sim/data/real_inpainting/bridge_real_eval_1.png` 和 `bridge_sink.png`），script/eval/bridge/eval_bridge.sh 要读。

### 3.2 HuggingFace cache

`$WORKSPACE/cache/hf/hub/` 下需要：

| 模型 | 用途 |
|---|---|
| `timm/vit_large_patch14_reg4_dinov2.lvd142m` | prismatic 的 DINO vision 骨架 |
| `timm/vit_so400m_patch14_siglip_224` 或等价 | prismatic 的 SigLIP vision 骨架 |
| `meta-llama/Llama-2-7b-hf`（**仅 config + tokenizer，不要下 weight**）| prismatic LLM 骨架的"空壳"；权重已经 bake 进 memvla-bridge.pt |

如果用 NousResearch mirror（`NousResearch/Llama-2-7b-hf`）也行，内容等价。

setup_simpler.sh step 12 会在 `$WORKSPACE/cache/llama2-7b-local/` 建一个本地镜像目录（挑 config/tokenizer 6 个文件），然后把 `MEMVLA_LLAMA2_7B_LOCAL_PATH` 加进 `/root/.bashrc`。`prismatic/models/backbones/llm/llama2.py` 在读到这个 env 时会绕开 `transformers` 自己的缓存查找。

### 3.3 Ckpt

```
$WORKSPACE/ckpts/simpler/memvla-bridge/checkpoints/memvla-bridge.pt
```

从 MemoryVLA 官方 HF release 下（README 有链接），约 14GB。

---

## 4. 踩过的坑（必看）

### 4.1 gymnasium 0.28+ 的 wrapper 不透传任意属性 ⚠⚠

老 `gym` 的 `__getattr__` fallback 会把 `env.foo_method()` 代理到 inner env；`gymnasium 0.28+` 收紧了白名单，只透传 `unwrapped / spec / np_random` 等。

**命中点**：
- `evaluation/simpler_env/maniskill2_evaluator.py`：5 处 `env.is_final_subtask()` / `env.get_language_instruction()` / `env.advance_to_next_subtask()` 会 `AttributeError`
- `third_libs/SimplerEnv/simpler_env/utils/env/observation_utils.py`：1 处 `env.robot_uid`

**Fix 状态**：MemoryVLA 侧（evaluator 的 5 处）task001 PR #1 已 land；SimplerEnv 侧（observation_utils 的 1 处）作为 `scripts/patches/simpler_env_observation_utils.patch` 放 repo，setup_simpler.sh 会在 clone 之后自动 apply。

### 4.2 bash `cmd | tee f` 会吞掉 python crash 的 exit code ⚠

`script/eval/bridge/eval_bridge.sh` 里每个 scene 都是 `python ... | tee ${eval_dir}/Scene.txt`。pipe 的 `$?` 来自 tee（永远 0），所以即便 python 崩了 bash 继续往下跑，看起来"4 scene 全成功"，实际文件里可能全是 traceback。

**如何判断真成功**：看 scene 对应 `.txt` 末尾是否有 `Average success X.XXXX` 这行，没有就是崩了。

**未 land 的缓解**：`set -o pipefail` 可以把 python 的退出码传上来，但会改变整个脚本的 error 处理语义，所以 task001 暂不动。

### 4.3 共享盘 ENOSPC 触发 `matplotlib.image.imsave` 失败 ⚠

rollout 结束后 `model.visualize_epoch()` 会写动作轨迹图；3fs 高利用率（>90%）时 `mpl.image.imsave` 会抛 `OSError: [Errno 28] No space left on device`，把整个 scene 的 python 进程杀掉，丢掉已经跑完的 24 个 episode 的数字。

**Fix 状态**：task001 已在 `maniskill2_evaluator.py:173` 把 `model.visualize_epoch()` 包 `try/except OSError`，丢图不丢 episode。

### 4.4 `script/eval/bridge/eval_bridge.sh` orphan `done`

早期一次编辑留的 bash 语法错误（第 60 行 orphan `done`）。task001 PR #1 已 fix。

### 4.5 sapien 必须配 vulkan（不能用 osmesa）

区别于 LIBERO（走 MuJoCo osmesa 软件渲染），Simpler 用 sapien → vulkan → NVIDIA driver 的 GPU 路径。ICD JSON 缺失的症状：sapien 在 scene reset 里卡住或报 "vkEnumeratePhysicalDevices failed"。setup_simpler.sh step 2 会检查 `/usr/share/vulkan/icd.d/nvidia_icd.json`，缺了直接给出修复指引。

### 4.6 numpy 2.x 会静默破坏 sapien 2.2.2

sapien 2.2.2 binding 是针对 numpy 1.x 编的。安装顺序必须：**numpy<2 → torch 2.2.0 → sapien 2.2.2**。setup_simpler.sh step 4-5 强制这个顺序并在重试里反复验证。

---

## 5. eval 怎么跑

```bash
cd $WORKSPACE
source /root/envs/simpler/bin/activate
bash script/eval/bridge/eval_bridge.sh
```

脚本里的 `ckpt_paths=(...)` 要先改成你的实际 ckpt 路径。

4 个 scene 串行跑（各 24 ep，约 1.5h）：

| scene | env_name | 预期成功率（memvla-bridge ckpt）| paper |
|---|---|---|---|
| Cube | StackGreenCubeOnYellowCubeBakedTexInScene-v0 | 0.4583 | 0.708 |
| Carrot | PutCarrotOnPlateInScene-v0 | 0.7083 | 0.583 |
| Spoon | PutSpoonOnTableClothInScene-v0 | 0.7500 | 0.625 |
| Eggplant | PutEggplantInBasketScene-v0 | 1.0000 | 0.958 |
| **avg** | | **0.7292** | **0.7188** |

结果：`$WORKSPACE/ckpts/simpler/memvla-bridge/eval_simpler/memvla-bridge.pt/{Cube,Carrot,Spoon,Eggplant}.txt`

抽取总分：`script/eval/bridge/extract_bridge_results.py`

Cube 与 paper 的 25pp 偏差没查清；怀疑 sapien 渲染版本或 episode seed 差异。做 Cube 相关的 ablation 之前最好固定这两个变量。

---

## 6. 和 LIBERO 的差异一览

| 维度 | LIBERO | Simpler |
|---|---|---|
| 渲染 | MuJoCo + osmesa（软件）| sapien + vulkan（GPU）|
| apt 必装 | `libosmesa6 libosmesa6-dev` | `libvulkan1 vulkan-tools` + NVIDIA ICD |
| 外部仓 | `third_libs/LIBERO/`（per-item symlink）| `third_libs/SimplerEnv/`（git clone + patch）|
| 特殊 pin | 无 | `sapien==2.2.2` |
| Architecture | deploy.py (Flask) + eval_libero.py (client)，要 `sleep 1800` 等 ckpt load | 单进程，每 scene 重跑 |
| 踩坑来源 | PyOpenGL + osmesa 缺失 | gymnasium wrapper + sapien vulkan |

共享的坑（两边都适用，已 land）：
- numpy<2 必须 pin 在 torch 之前
- `MEMVLA_LLAMA2_7B_LOCAL_PATH` 绕开 HF 网络查找
- `vla/__init__.py` 的 dlimp eval-only guard

---

## 7. 交叉引用

- 完整复现报告（Bridge + LIBERO 双结果对照）：`docs/eval_reproduction.md`
- LIBERO 配置手册：目前嵌在 `docs/eval_reproduction.md` §2.2；独立 doc 尚未拆
- LIBERO setup 脚本：`scripts/setup_libero.sh`
- SimplerEnv 补丁：`scripts/patches/simpler_env_observation_utils.patch`
- Bridge eval 入口：`script/eval/bridge/eval_bridge.sh`
- Simpler 推理入口：`evaluation/simpler_env/simpler_env_inference.py`
- Evaluator（已修）：`evaluation/simpler_env/maniskill2_evaluator.py`
