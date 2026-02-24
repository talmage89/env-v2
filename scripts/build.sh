#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

IMAGE="${CAGE_IMAGE:-cage}"
USER_DOCKERFILE="$REPO_DIR/user.Dockerfile"

if [[ -f "$USER_DOCKERFILE" ]]; then
    echo "Injecting user.Dockerfile into build..."
    awk -v udf="$USER_DOCKERFILE" '
        /^# === USER EXTENSIONS ===/ { print; while ((getline line < udf) > 0) print line; next }
        { print }
    ' "$REPO_DIR/Dockerfile" | docker build -t "$IMAGE" -f - "$REPO_DIR"
else
    docker build -t "$IMAGE" "$REPO_DIR"
fi
