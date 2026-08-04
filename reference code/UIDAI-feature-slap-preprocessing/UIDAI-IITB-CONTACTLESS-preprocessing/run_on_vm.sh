#!/usr/bin/env bash
# Launch the slap pipeline server on the VM (GPU via torch, TF stays on CPU).
set -e
cd "$(dirname "$0")"
source venv/bin/activate
export SLAP_MODELS_DIR="$(pwd)/models"
export PORT=5010

#: load models once in the master before forking (avoids worker-boot
# timeout during the ~30-60s model load). -t 0: no request timeout (slow infer).
exec gunicorn -w 1 --threads 8 -t 0 -b 0.0.0.0:${PORT} wsgi:app
