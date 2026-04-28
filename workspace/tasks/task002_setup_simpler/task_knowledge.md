# task002_setup_simpler - 任务知识

<!-- METADATA:SESSION=1 -->

> **编写规则**：每条一句话，格式：`N. 类别：内容`
>
> 类别包括：主管要求、技术事实、文件修改、调研结论

---

## 知识条目

1. 主管要求：基于现有记录整一个 `scripts/setup_simpler.sh` + 独立配套 doc，PAI 容器已下线无法从 3fs 拷残留。
2. 技术事实：Simpler 用 **sapien 2.2.2 + vulkan** 做 GPU 渲染（LIBERO 走 osmesa 软件渲染；Simpler 不能用 osmesa，sapien 的 raytracer 需要 vulkan GPU path）。
3. 技术事实：`script/eval/bridge/eval_bridge.sh` 头部 export 了 `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json` — setup 脚本需保证这个 ICD JSON 存在（NVIDIA driver 装了通常自带；air-gapped 容器要确认）。
4. 技术事实：Simpler 必须 clone `third_libs/SimplerEnv`（含 `ManiSkill2_real2sim/` 的 rgb_overlay 真实场景 inpainting 图）+ apply `scripts/patches/simpler_env_observation_utils.patch` 的 gymnasium unwrap 修复。
5. 技术事实：所有"通用"坑（numpy<2、LLaMA-2-7b config+tokenizer 本地镜像 + `MEMVLA_LLAMA2_7B_LOCAL_PATH` env、dlimp eval-only guard）和 LIBERO 是共享的，可以复用 setup_libero.sh 的模板。
6. 调研结论：SimplerEnv 官方上游是 `simpler-env/SimplerEnv`（github）；air-gapped 没 github 的话只能从 dev4infer（10.100.193.67）staging 后 rsync 进去。本次容器已下线，脚本里写上命令 + 给 fallback 指引即可。

---
