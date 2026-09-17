#!/usr/bin/env bash
# Run the app locally without Docker.
set -euo pipefail

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r app/requirements-dev.txt

echo "Running tests..."
pytest tests -q

echo "Starting Flask on http://localhost:5000"
ENVIRONMENT=local APP_VERSION=dev python app/app.py
