# task002_setup_simpler - 补 Simpler 环境一键安装脚本 + 独立配套 doc

<!-- METADATA:STATUS=InProgress,ASSIGNEE=intern_memvla_developer -->

## 背景

task001 把 LIBERO 的 `setup_libero.sh` 落 PR 了，但 Simpler 这边只 port 了 evaluator/eval_bridge.sh 的代码修复，**Simpler 专用 setup 脚本没进 repo**。`docs/eval_reproduction.md` §2.1 第 71 行虽然引用了 `scripts/setup_simpler.sh`，但文件不存在。

两台 PAI 容器（Simpler 10.100.2.47:29862 / LIBERO 10.100.38.11:35724）当前已下线，无法从 3fs 拷已有脚本（如有）。只能基于现有记录重整。

## 任务目标

1. 基于 `scripts/setup_libero.sh` 模板 + `docs/eval_reproduction.md` 里的 Simpler 踩坑记录 + `script/eval/bridge/eval_bridge.sh` 头部的 env 导出，新写 `scripts/setup_simpler.sh`（幂等、可重跑）
2. 新写独立配套 doc `docs/simpler_env_setup.md`，专注 Simpler 环境：依赖、踩坑、复现步骤。方便别人单独找 Simpler 信息而不用穿透 `eval_reproduction.md` 的全局叙事

## 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/setup_simpler.sh` | **新增**。apt（vulkan / mesa / ffmpeg / osmesa 以防万一）、venv `/root/envs/simpler`、torch 2.2.0 + numpy<2、memvla pip -e、clone SimplerEnv 到 `third_libs/` + apply `scripts/patches/simpler_env_observation_utils.patch`、NVIDIA Vulkan ICD 检查、LLaMA-2-7b 本地镜像 materialize、smoke 检查 |
| `docs/simpler_env_setup.md` | **新增**。容器要求、依赖版本、vulkan/sapien 细节、外部资产（SimplerEnv + ManiSkill2 real2sim data）、踩坑（TimeLimit wrapper/tee 吞 crash/ENOSPC/eval_bridge.sh orphan done），引导读者跑 `scripts/setup_simpler.sh`|
| `docs/eval_reproduction.md` | 可选：小幅改动，第 71 行引用的 setup_simpler.sh 从"not-exist"变 "exists"|

## 验收标准

- [ ] `scripts/setup_simpler.sh` 落 PR、`bash -n` 语法 OK
- [ ] `docs/simpler_env_setup.md` 落 PR、独立成篇
- [ ] PR 打到 StevenKKXS fork 内部（base `StevenKKXS:openvla-codebase`，避免重蹈 #23 覆辙）
- [ ] merge 后

## 不做什么

- **不**在 PAI 容器上跑脚本验证（两容器下线）
- **不**保证 apt 包版本跟原 3fs 上的一一致（没法拿回来比对）——目标是"差不多、下次有人 new 一个容器能跑通、遇到问题照 doc 排"

## 负责人

intern_memvla_developer

## 基础分支

`openvla-codebase`
