#!/usr/bin/env bash
set -euo pipefail

IMAGE="${DEV_IMAGE:-dev-env}"

# --- Locate config relative to this script ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_DIR/defaults.conf"

# --- Defaults (overridden by config file if present) ---

DEV_PORTS=""
DEV_NETWORK="full"
DEV_VOLUMES=(
    "$HOME/.config/helix:/home/dev/.config/helix:ro"
    "$HOME/.config/tmux:/home/dev/.config/tmux:ro"
    "claude-config:/home/dev/.claude"
    "claude-ssh:/home/dev/.ssh"
)

# shellcheck source=/dev/null
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# --- CLI argument parsing ---

usage() {
    cat <<'EOF'
Usage: dev [--net <profile>] [port ...]

Options:
  --net <profile>  Override network profile (none|claude|claude-npm|standard|full)
  --help           Show this help

Examples:
  dev                    # use config defaults
  dev 8080 3000          # forward specific ports
  dev --net none         # no network access
  dev --net full 8080    # full network + port forwarding
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
            echo "dev: unknown option: $1" >&2
            usage
            ;;
        *)
            CLI_PORTS+=("$1")
            shift
            ;;
    esac
done

# CLI overrides config
[[ -n "$CLI_NETWORK" ]] && DEV_NETWORK="$CLI_NETWORK"
[[ ${#CLI_PORTS[@]} -gt 0 ]] && DEV_PORTS="${CLI_PORTS[*]}"

# --- Container lifecycle ---

# Running container for this directory? Exec into it.
running=$(docker ps -q -f ancestor="$IMAGE" -f label=dev.workdir="$PWD" | head -1)
if [[ -n "$running" ]]; then
    exec docker exec -it "$running" bash
fi

# Stopped container for this directory? Restart + exec.
stopped=$(docker ps -aq -f ancestor="$IMAGE" -f status=exited -f label=dev.workdir="$PWD" | head -1)
if [[ -n "$stopped" ]]; then
    docker start "$stopped" > /dev/null
    exec docker exec -it "$stopped" bash
fi

# --- New container ---

RUN_ARGS=(
    -dit
    --label "dev.workdir=$PWD"
    -v "$PWD:/workspace"
)

# Ports
for port in $DEV_PORTS; do
    RUN_ARGS+=(-p "$port:$port")
done

# Volumes
for vol in "${DEV_VOLUMES[@]}"; do
    RUN_ARGS+=(-v "$vol")
done

# Network profile
case "$DEV_NETWORK" in
    none)
        RUN_ARGS+=(--network none)
        ;;
    full)
        ;;
    *)
        RUN_ARGS+=(
            --cap-add=NET_ADMIN
            -e "DEV_NETWORK_PROFILE=$DEV_NETWORK"
        )
        ;;
esac

id=$(docker run "${RUN_ARGS[@]}" "$IMAGE")
exec docker exec -it "$id" bash
