# task002_setup_simpler - 历史日志

<!-- METADATA:SESSION=1 -->

---

## Session 0 — 2026-04-28 — 初始化

**执行人**: intern_memvla_developer

主管要求补 Simpler 一键配置脚本 + 独立配套 doc。task001 漏掉了这块。两台 PAI 容器已下线，只能基于 repo 现有记录（docs/eval_reproduction.md / setup_libero.sh / eval_bridge.sh / task001 task_knowledge 等）+ 我 Session 1-3 的 knowledge 整一个"差不多"版本，不再靠 3fs 残留。

---

## Session 1 — 2026-04-28 — 落盘 setup_simpler.sh + simpler_env_setup.md

**执行人**: intern_memvla_developer

### 动作
1. 创建 task 目录 + 推 openvla-codebase（commit `b626250`）
2. 开分支 `intern_memvla_developer/task002_setup_simpler`，WIP 初始化（commit `acb5eaf`）
3. 新写 `scripts/setup_simpler.sh`（255 行）
4. 新写 `docs/simpler_env_setup.md`（175 行）
5. 小改 `docs/eval_reproduction.md` §2.1 引用行

### setup_simpler.sh 与 setup_libero.sh 的关键差异
- apt：加 `libvulkan1 vulkan-tools` + `patch`（用来 apply SimplerEnv patch）；保留 osmesa 防身
- step 2 新增：检查 NVIDIA Vulkan ICD `/usr/share/vulkan/icd.d/nvidia_icd.json`
- step 9 新增：`pip install sapien==2.2.2 transforms3d mediapy opencv-python-headless`
- step 10 新增：`git clone simpler-env/SimplerEnv third_libs/SimplerEnv` + 幂等 apply patch（dry-run reverse 检测已应用状态）
- step 11 新增：`pip install -e third_libs/SimplerEnv/ManiSkill2_real2sim` + `pip install -e third_libs/SimplerEnv`
- 移除：LIBERO 专属的 per-item symlink 构造、libero-repo.pth
- smoke：导入 `sapien` + `simpler_env` + `vla.load_vla`，不 import LIBERO benchmark

### 未完
- commit + push 产出
- 主管打 PR
- 等 review

---

