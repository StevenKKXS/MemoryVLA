#!/usr/bin/env bash
# MemoryVLA Simpler (SimplerEnv / Bridge / widowx) eval env — installs into
# container-local /root/envs/simpler. Idempotent; safe to re-run.
#
# Usage:  WORKSPACE=/path/to/MemoryVLA bash scripts/setup_simpler.sh
#
# This is the Simpler counterpart of scripts/setup_libero.sh. Shares most of the
# MemoryVLA-side steps (memvla pip -e, numpy<2 pinning, LLaMA-2-7b local mirror,
# dlimp eval-only guard) but swaps the graphics stack:
#
#   LIBERO -> osmesa (software mujoco rendering)
#   Simpler -> vulkan via sapien 2.2.2 (GPU; needs NVIDIA Vulkan ICD JSON)
#
# Tested context: PAI air-gapped container with an internal pypi mirror and
# dev4infer (10.100.193.67) doing the github/HF staging. The script itself is
# network-agnostic — if your box has upstream access, ignore the staging notes.

set -e
JOB=simpler
WORKSPACE=${WORKSPACE:-$(pwd)}
VENV=/root/envs/$JOB
LOG=$WORKSPACE/logs/$JOB/setup.log

# HF/ckpts on shared storage (large files OK); pip cache + TMPDIR on local /root
# (small files — avoid 3fs RIO when running in PAI).
export HF_HOME=$WORKSPACE/cache/hf
export HF_HUB_CACHE=$WORKSPACE/cache/hf/hub
export TRANSFORMERS_CACHE=$WORKSPACE/cache/hf/transformers
export TORCH_HOME=$WORKSPACE/cache/torch
export PIP_CACHE_DIR=/root/.cache/pip
export XDG_CACHE_HOME=/root/.cache
export TMPDIR=/root/tmp
export PYTHONNOUSERSITE=1
export DEBIAN_FRONTEND=noninteractive

mkdir -p "$WORKSPACE/logs/$JOB" "$WORKSPACE/ckpts/$JOB" "$WORKSPACE/third_libs" \
  "$WORKSPACE/cache/hf/hub" "$WORKSPACE/cache/hf/transformers" "$WORKSPACE/cache/torch" \
  /root/envs /root/.cache/pip /root/tmp

step() { echo "=== [$(date -Is)] $*" | tee -a "$LOG"; }
trap 'echo "FAILED at line $LINENO" | tee -a "$LOG"' ERR

step "$JOB setup start (WORKSPACE=$WORKSPACE, VENV=$VENV)"

step "step 1: apt deps (idempotent)"
# vulkan + mesa: sapien 2.2.2 ships a vulkan renderer; needs libvulkan1 +
#                NVIDIA ICD JSON to find the driver. libGL / libEGL are still
#                linked by some transitive deps.
# libosmesa6: kept as defense-in-depth — if you ever set MUJOCO_GL=osmesa in a
#             shared debug shell it won't crash.
apt-get update -qq >> "$LOG" 2>&1 || true
apt-get install -y git git-lfs curl wget ca-certificates build-essential pkg-config \
  python3 python3-pip python3-venv python3.10-venv ffmpeg \
  libegl1-mesa libgl1-mesa-dev libgles2-mesa-dev libgl1 libglib2.0-0 \
  libglx-mesa0 libopengl0 libglu1-mesa mesa-utils \
  libvulkan1 vulkan-tools \
  libosmesa6 libosmesa6-dev \
  lsof patch >> "$LOG" 2>&1
git lfs install --skip-repo >> "$LOG" 2>&1 || true

step "step 2: verify NVIDIA Vulkan ICD is reachable (sapien will fail silently without it)"
ICD=/usr/share/vulkan/icd.d/nvidia_icd.json
if [ -f "$ICD" ]; then
  step "  found $ICD"
else
  step "  WARN: $ICD missing. Options:"
  step "    (a) ensure the NVIDIA driver is installed inside the container (apt: nvidia-driver-XXX)"
  step "    (b) bind-mount from host: -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro"
  step "    (c) if you can't fix it, set VK_ICD_FILENAMES to a known-good ICD path in eval_bridge.sh"
fi
if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary >> "$LOG" 2>&1 || step "  WARN: vulkaninfo failed (driver may not be loaded)"
fi

step "step 3: venv at $VENV"
torch_ok=0
if [ -x "$VENV/bin/python" ]; then
  if "$VENV/bin/python" -c "import torch; assert torch.__version__.startswith('2.2.0'), torch.__version__; import numpy; assert numpy.__version__.startswith('1.'), numpy.__version__" 2>>"$LOG"; then
    torch_ok=1; step "  venv exists and torch/numpy verified"
  else
    step "  venv exists but torch or numpy broken — wiping"
    rm -rf "$VENV"
  fi
fi
[ -x "$VENV/bin/python" ] || python3 -m venv "$VENV" >> "$LOG" 2>&1
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -V >> "$LOG" 2>&1

step "step 4: pip upgrade + build deps + pin numpy<2 BEFORE torch"
pip install --upgrade pip setuptools wheel >> "$LOG" 2>&1
pip install psutil packaging ninja >> "$LOG" 2>&1
# numpy 2.x breaks sapien 2.2.2 and many maniskill bindings; pin before torch.
pip install "numpy==1.26.4" >> "$LOG" 2>&1

step "step 5: torch 2.2.0 (retry up to 5× against flaky mirrors)"
if [ $torch_ok -ne 1 ]; then
  ok=0
  for i in 1 2 3 4 5; do
    if pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 >> "$LOG" 2>&1 \
       && pip install "numpy==1.26.4" --force-reinstall >> "$LOG" 2>&1 \
       && python -c "import torch; assert torch.__version__.startswith('2.2.0'), torch.__version__; import numpy; assert numpy.__version__.startswith('1.'), numpy.__version__" 2>>"$LOG"; then
      step "  torch+numpy verified on attempt $i"; ok=1; break
    fi
    step "  attempt $i broken, wipe + retry"
    pip uninstall -y torch torchvision torchaudio 2>>"$LOG" || true
    rm -rf "$VENV/lib/python3.10/site-packages/torch"* 2>>"$LOG"
    sleep 5
  done
  [ $ok -eq 1 ] || { step "torch install gave up after 5 retries"; exit 1; }
fi

step "step 6: ensure vla/__init__.py has dlimp-optional guard (no-op if already land — task001 PR merged this)"
if ! grep -q "dlimp" "$WORKSPACE/vla/__init__.py"; then
  step "  WARN: vla/__init__.py lacks dlimp guard; task001 PR should have landed this. Manual check advised."
fi

step "step 7: pip install -e memvla (pyproject.toml must already be patched: requires-python, flash_attn optional, dlimp optional)"
cd "$WORKSPACE"
for i in 1 2 3; do
  if pip install -e . >> "$LOG" 2>&1; then
    step "  memvla install OK on attempt $i"; break
  fi
  step "  memvla install attempt $i failed, retry"; sleep 5
done

step "step 8: SUPPLY-CHAIN CHECK — audit dlimp for the sectest impersonator"
# Internal pypi may carry a dlimp==0.1.0 impostor authored sectest@example.com.
# If it slipped in, rip it out.
if pip show dlimp 2>/dev/null | grep -qiE "sectest|sec-test|yourusername|ipablepytorch"; then
  step "  ⚠️  sec-test dlimp DETECTED — uninstalling"
  pip uninstall -y dlimp >> "$LOG" 2>&1 || true
fi

step "step 9: Simpler-specific deps (sapien 2.2.2 + transforms3d + mediapy + misc)"
# sapien 2.2.2 is the version SimplerEnv pins. Newer sapien (3.x) changed APIs
# and does not work with the vendored ManiSkill2_real2sim.
pip install "sapien==2.2.2" >> "$LOG" 2>&1
pip install transforms3d mediapy opencv-python-headless >> "$LOG" 2>&1

step "step 10: clone third_libs/SimplerEnv and apply our unwrapped patch"
SE_DIR=$WORKSPACE/third_libs/SimplerEnv
if [ ! -d "$SE_DIR/.git" ] && [ ! -e "$SE_DIR/setup.py" ]; then
  # Prefer upstream. If your box is air-gapped, stage it on dev4infer first:
  #   ssh dev4infer 'git clone https://github.com/simpler-env/SimplerEnv /tmp/se && rsync -a /tmp/se/ <WORKSPACE>/third_libs/SimplerEnv/'
  if git clone https://github.com/simpler-env/SimplerEnv "$SE_DIR" >> "$LOG" 2>&1; then
    step "  cloned SimplerEnv upstream"
  else
    step "  ERROR: SimplerEnv clone failed. Stage it manually:"
    step "         1) on a box with egress: git clone https://github.com/simpler-env/SimplerEnv"
    step "         2) rsync/scp the dir to $SE_DIR"
    step "         3) re-run this script"
    exit 1
  fi
fi

# Apply the unwrapped-env patch idempotently. The patch fixes
# `env.robot_uid` -> `env.unwrapped.robot_uid` in utils/env/observation_utils.py.
PATCH=$WORKSPACE/scripts/patches/simpler_env_observation_utils.patch
if [ -f "$PATCH" ]; then
  if (cd "$SE_DIR" && patch -p0 --dry-run -R -s < "$PATCH" >/dev/null 2>&1); then
    step "  patch already applied to SimplerEnv (reverse-dry-run OK) — skipping"
  elif (cd "$SE_DIR" && patch -p0 --dry-run -s < "$PATCH" >/dev/null 2>&1); then
    (cd "$SE_DIR" && patch -p0 < "$PATCH" >> "$LOG" 2>&1) && step "  patch applied"
  else
    step "  WARN: patch neither applies cleanly nor looks already-applied. Inspect $SE_DIR manually."
  fi
else
  step "  WARN: $PATCH missing — skip patch"
fi

step "step 11: install SimplerEnv + ManiSkill2_real2sim as editable (needs sapien already installed)"
# ManiSkill2_real2sim is a vendored ManiSkill2 with real2sim scene assets.
if [ -f "$SE_DIR/ManiSkill2_real2sim/setup.py" ] || [ -f "$SE_DIR/ManiSkill2_real2sim/pyproject.toml" ]; then
  (cd "$SE_DIR/ManiSkill2_real2sim" && pip install -e .) >> "$LOG" 2>&1 \
    && step "  ManiSkill2_real2sim installed" \
    || step "  WARN: ManiSkill2_real2sim install failed (see $LOG)"
fi
if [ -f "$SE_DIR/setup.py" ] || [ -f "$SE_DIR/pyproject.toml" ]; then
  (cd "$SE_DIR" && pip install -e .) >> "$LOG" 2>&1 \
    && step "  SimplerEnv installed" \
    || step "  WARN: SimplerEnv install failed (see $LOG)"
fi

step "step 12: LLaMA-2-7b config+tokenizer mirror (same as LIBERO — deploy/load_vla shares the LLM backbone)"
LLAMA_LOCAL=$WORKSPACE/cache/llama2-7b-local
if [ ! -f "$LLAMA_LOCAL/config.json" ] || [ ! -f "$LLAMA_LOCAL/tokenizer.model" ]; then
  ML_SNAP=$WORKSPACE/cache/hf/hub/models--meta-llama--Llama-2-7b-hf/snapshots
  if [ -d "$ML_SNAP" ]; then
    SHA=$(ls "$ML_SNAP" | head -1)
    mkdir -p "$LLAMA_LOCAL"
    for f in config.json tokenizer.json tokenizer.model tokenizer_config.json special_tokens_map.json generation_config.json; do
      [ -e "$ML_SNAP/$SHA/$f" ] && cp -L "$ML_SNAP/$SHA/$f" "$LLAMA_LOCAL/"
    done
    step "  llama2-7b-local materialized at $LLAMA_LOCAL ($(ls "$LLAMA_LOCAL" | wc -l) files)"
  else
    step "  WARN: $ML_SNAP missing — pre-stage HF cache for meta-llama OR NousResearch/Llama-2-7b-hf on dev4infer"
  fi
fi
# Make sure future shells find the mirror (prismatic/models/backbones/llm/llama2.py reads this).
grep -q "MEMVLA_LLAMA2_7B_LOCAL_PATH" /root/.bashrc 2>/dev/null \
  || echo "export MEMVLA_LLAMA2_7B_LOCAL_PATH=$LLAMA_LOCAL" >> /root/.bashrc

step "step 13: smoke (torch + sapien + simpler_env imports, no ckpt load)"
cd "$WORKSPACE"
find vla -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
# IMPORTANT: pass env vars via separate export lines.
export HF_HUB_OFFLINE=${HF_HUB_OFFLINE:-1}
export TRANSFORMERS_OFFLINE=${TRANSFORMERS_OFFLINE:-1}
export MEMVLA_LLAMA2_7B_LOCAL_PATH=$WORKSPACE/cache/llama2-7b-local
export VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}

SMOKE=$WORKSPACE/scripts/_smoke_simpler_inline.py
cat > "$SMOKE" <<'PY'
import sys
print("Python:", sys.version.split()[0])
import torch
print("torch:", torch.__version__, "cuda:", torch.version.cuda, "avail:", torch.cuda.is_available(),
      "dev count:", torch.cuda.device_count())
import numpy, transformers
print("transformers:", transformers.__version__, "numpy:", numpy.__version__)
try:
    import sapien
    print("sapien:", sapien.__version__)
except Exception as e:
    print("sapien: FAIL ->", repr(e))
try:
    import simpler_env  # vendored third_libs/SimplerEnv package name
    print("simpler_env: OK (module found)")
except Exception as e:
    print("simpler_env: FAIL ->", repr(e))
try:
    from vla import load_vla
    print("vla.load_vla: OK")
except Exception as e:
    print("vla.load_vla: FAIL ->", repr(e))
print("=== smoke done ===")
PY
python "$SMOKE" 2>&1 | tee -a "$LOG"
rm -f "$SMOKE"

step "$JOB setup DONE — venv: $VENV, repo: $WORKSPACE"
echo "  pip list installed: $(pip list 2>/dev/null | wc -l) packages" | tee -a "$LOG"
echo "  du -sh $VENV: $(du -sh "$VENV" 2>/dev/null | cut -f1)" | tee -a "$LOG"
echo "  du -sh third_libs/SimplerEnv: $(du -sh -L "$WORKSPACE/third_libs/SimplerEnv" 2>/dev/null | cut -f1)" | tee -a "$LOG"

cat <<BANNER

Next steps:
  1) Put your ckpt at $WORKSPACE/ckpts/simpler/memvla-bridge/checkpoints/memvla-bridge.pt
  2) Ensure HF cache is seeded (DINO + SigLIP + LLaMA-2-7b config/tokenizer).
  3) Run:   bash $WORKSPACE/script/eval/bridge/eval_bridge.sh
  4) Full context + gotchas: docs/simpler_env_setup.md

BANNER
