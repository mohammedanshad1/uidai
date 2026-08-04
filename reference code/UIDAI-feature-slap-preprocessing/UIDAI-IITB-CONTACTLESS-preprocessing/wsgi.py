"""
Gunicorn / Cloud Run entrypoint.

gunicorn does NOT run slap_app's `if __name__ == "__main__"` block, so models
would never load. This module loads them once at import time — run gunicorn with
`--preload` so the load happens in the master process (before workers fork and
before the port is opened), which avoids per-worker reloads and worker-boot
timeouts.
"""
import slap_core
from slap_app import app, init_slap_db  # noqa: F401  (app is the WSGI callable)

init_slap_db()
slap_core.load_models()
