#!/usr/bin/env bash
# One-time setup on the GPU VM. Installs a CUDA torch + the rest of the deps.
set -e
cd "$(dirname "$0")"

echo "==> [1/4] GPU / driver check"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  echo "WARNING: nvidia-smi not found. If this is a plain Ubuntu image you must"
  echo "install the NVIDIA driver first (see notes). torch will fall back to CPU."
fi

echo "==> [2/4] Python venv"
sudo apt-get update -y && sudo apt-get install -y python3-venv python3-pip
python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate
pip install --upgrade pip wheel

echo "==> [3/4] PyTorch (CUDA 12.1 wheel) + server deps"
pip install torch==2.5.1 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements-vm.txt

echo "==> [4/4] CUDA sanity"
python -c "import torch; print('torch', torch.__version__, 'cuda?', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"

echo "Setup done. Launch with:  ./run_on_vm.sh"
