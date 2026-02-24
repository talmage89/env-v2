#!/usr/bin/env bash
set -euo pipefail

IMAGE="${CAGE_IMAGE:-${USER}-cage}"

# --- Locate config relative to this script ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_DIR/defaults.conf"

# --- Defaults (overridden by config file if present) ---

CAGE_PORTS=""
CAGE_NETWORK="claude"
CAGE_GIT_PUSH_REMOTES=""
CAGE_CACHED_DIRS=()
CAGE_VOLUMES=(
    "$HOME/.config/helix:/home/cage/.config/helix:ro"
    "$HOME/.config/tmux:/home/cage/.config/tmux:ro"
    "${USER}-cage-config:/home/cage/.claude"
    "${USER}-cage-ssh:/home/cage/.ssh"
)

# shellcheck source=/dev/null
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# --- CLI argument parsing ---

usage() {
    cat <<'EOF'
Usage: cage [--net <profile>] [port ...]

Options:
  --net <profile>  Override network profile (none|claude|standard|full)
  --help           Show this help

Examples:
  cage                    # use config defaults
  cage 8080 3000          # forward specific ports
  cage --net none         # no network access
  cage --net full 8080    # full network + port forwarding
EOF
    exit 0
}

CLI_PORTS=()
CLI_NETWORK=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --net)
            CLI_NETWORK="${2:?--net requires a profile name}"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        -*)
            echo "cage: unknown option: $1" >&2
            usage
            ;;
        *)
            CLI_PORTS+=("$1")
            shift
            ;;
    esac
done

# CLI overrides config
[[ -n "$CLI_NETWORK" ]] && CAGE_NETWORK="$CLI_NETWORK"
[[ ${#CLI_PORTS[@]} -gt 0 ]] && CAGE_PORTS="${CLI_PORTS[*]}"

# --- Container lifecycle ---

# Running container for this directory? Exec into it.
running=$(docker ps -q -f ancestor="$IMAGE" -f label=cage.workdir="$PWD" | head -1)
if [[ -n "$running" ]]; then
    exec docker exec -it "$running" bash
fi

# Stopped container for this directory? Restart + exec.
stopped=$(docker ps -aq -f ancestor="$IMAGE" -f status=exited -f label=cage.workdir="$PWD" | head -1)
if [[ -n "$stopped" ]]; then
    docker start "$stopped" > /dev/null
    exec docker exec -it "$stopped" bash
fi

# --- New container ---

RUN_ARGS=(
    -dit
    --label "cage.workdir=$PWD"
    -v "$PWD:/workspace"
)

# Ports
for port in $CAGE_PORTS; do
    RUN_ARGS+=(-p "$port:$port")
done

# Volumes
for vol in "${CAGE_VOLUMES[@]}"; do
    RUN_ARGS+=(-v "$vol")
done

# Cached dirs: overlay named volumes on workspace paths for filesystem performance
if [[ ${#CAGE_CACHED_DIRS[@]} -gt 0 ]]; then
    PROJECT_HASH=$(echo -n "$PWD" | shasum | cut -c1-8)
    for dir in "${CAGE_CACHED_DIRS[@]}"; do
        vol_name="${USER}-cage-${PROJECT_HASH}-$(echo "$dir" | tr '/' '-')"
        RUN_ARGS+=(-v "$vol_name:/workspace/$dir")
    done
fi

# Git push remote restriction
if [[ -n "$CAGE_GIT_PUSH_REMOTES" ]]; then
    RUN_ARGS+=(-e "CAGE_GIT_PUSH_REMOTES=$CAGE_GIT_PUSH_REMOTES")
fi

# Network profile
case "$CAGE_NETWORK" in
    none)
        RUN_ARGS+=(--network none)
        ;;
    full)
        ;;
    *)
        RUN_ARGS+=(
            --cap-add=NET_ADMIN
            -e "CAGE_NETWORK_PROFILE=$CAGE_NETWORK"
        )
        ;;
esac

id=$(docker run "${RUN_ARGS[@]}" "$IMAGE")
exec docker exec -it "$id" bash
