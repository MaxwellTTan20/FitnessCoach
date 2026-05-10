#!/usr/bin/env bash
set -euo pipefail

# Convenience script to reproduce the local backend setup used on main branch.
# Usage: ./run_local_backend.sh
# It will create a venv in the repo root (./venv), install backend requirements,
# download the MediaPipe model, and print commands to run the server or demo.

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
PYTHON=${PYTHON:-python3}
VENV_DIR="$REPO_ROOT/venv"
BACKEND_DIR="$REPO_ROOT/backend"

echo "Using python: $(command -v $PYTHON)"

if [ -d "$VENV_DIR" ]; then
  echo "Reusing existing venv at $VENV_DIR"
else
  echo "Creating venv at $VENV_DIR"
  $PYTHON -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "Installing backend requirements..."
python -m pip install --upgrade pip
pip install -r "$BACKEND_DIR/requirements.txt"

echo "Downloading MediaPipe model (if missing)..."
python "$BACKEND_DIR/download_model.py"

cat <<'EOF'
Setup complete.
To run the Flask backend in one terminal:

  source ./venv/bin/activate
  python backend/main.py --exercise squat --mode beginner --provider claude

To run the standalone webcam demo in another terminal:

  source ./venv/bin/activate
  python backend/demo_webcam.py --exercise squat --mode beginner --provider claude

Note: the demo opens your camera (index 0) and shows a window.
If you want no voice playback, add --no-voice to demo_webcam.py.
EOF
