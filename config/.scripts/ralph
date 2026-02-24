#!/usr/bin/env bash
set -euo pipefail

# ralph - Run an AI agent Loop Producing Heuristics
# Continuously runs claude code against a prompt file in a loop
# until a configured time limit is reached.

usage() {
    cat <<'EOF'
usage: ralph <prompt_file> <duration> [model]

  prompt_file  path to a markdown prompt file
  duration     how long to run, e.g. 30m, 2h, 1h30m
  model        claude model to use (default: sonnet)

examples:
  ralph ./PROMPT.md 2h
  ralph /workspace/tasks/refactor.md 45m opus
  ralph ./PROMPT.md 1h30m haiku
EOF
    exit 1
}

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# --- argument parsing ---

PROMPT_FILE="${1:-}"
DURATION="${2:-}"
MODEL="${3:-sonnet}"

[[ -z "$PROMPT_FILE" || -z "$DURATION" ]] && usage

if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "ralph: prompt file not found: $PROMPT_FILE"
    exit 1
fi

# --- parse duration into seconds ---

TOTAL_SECONDS=0
if [[ "$DURATION" =~ ^([0-9]+)h([0-9]+)m$ ]]; then
    TOTAL_SECONDS=$(( ${BASH_REMATCH[1]} * 3600 + ${BASH_REMATCH[2]} * 60 ))
elif [[ "$DURATION" =~ ^([0-9]+)h$ ]]; then
    TOTAL_SECONDS=$(( ${BASH_REMATCH[1]} * 3600 ))
elif [[ "$DURATION" =~ ^([0-9]+)m$ ]]; then
    TOTAL_SECONDS=$(( ${BASH_REMATCH[1]} * 60 ))
else
    echo "ralph: invalid duration '$DURATION' (use e.g. 30m, 2h, 1h30m)"
    exit 1
fi

# --- resolve paths ---

PROMPT_FILE="$(realpath "$PROMPT_FILE")"

# --- set up run directory ---

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$HOME/ralph/$RUN_ID"
mkdir -p "$RUN_DIR"

# symlink ~/ralph/latest to the current run
ln -sfn "$RUN_DIR" "$HOME/ralph/latest"

OUTPUT_FILE="$RUN_DIR/output.txt"
LOG_FILE="$RUN_DIR/ralph.log"

# save the prompt for reproducibility
cp "$PROMPT_FILE" "$RUN_DIR/prompt.md"

COOLDOWN=10

DEADLINE=$(( $(date +%s) + TOTAL_SECONDS ))
START_TIME=$(date +%s)
ITERATION=0

log "ralph started"
log "prompt:   $PROMPT_FILE"
log "model:    $MODEL"
log "duration: $DURATION (${TOTAL_SECONDS}s)"
log "output:   $OUTPUT_FILE"
log "---"

# --- clean exit on ctrl-c ---

cleanup() {
    log "interrupted by user"
    _print_summary
    exit 130
}
trap cleanup INT TERM

_print_summary() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    local elapsed_min=$(( elapsed / 60 ))
    log "---"
    log "ralph finished: $ITERATION iterations in ${elapsed_min}m"
    log "output: $OUTPUT_FILE"
    echo ""
    echo "run directory: $RUN_DIR"
}

# --- main loop ---

while [[ $(date +%s) -lt $DEADLINE ]]; do
    ITERATION=$((ITERATION + 1))
    REMAINING=$(( DEADLINE - $(date +%s) ))
    REMAINING_MIN=$(( REMAINING / 60 ))

    log "iteration $ITERATION starting (${REMAINING_MIN}m remaining)"

    # delimiter in output file
    {
        echo ""
        echo "================================================================"
        echo "= ITERATION $ITERATION | $(date '+%Y-%m-%d %H:%M:%S') | model: $MODEL"
        echo "================================================================"
        echo ""
    } >> "$OUTPUT_FILE"

    # run claude
    cat "$PROMPT_FILE" \
        | claude -p \
            --dangerously-skip-permissions \
            --model "$MODEL" \
        >> "$OUTPUT_FILE" 2>> "$LOG_FILE" || true

    log "iteration $ITERATION finished"

    # autocommit any changes the agent made
    if git -C /workspace rev-parse --is-inside-work-tree &>/dev/null; then
        if [[ -n "$(git -C /workspace status --porcelain)" ]]; then
            git -C /workspace add -A
            git -C /workspace commit -m "ralph: iteration $ITERATION" --no-verify 2>> "$LOG_FILE" || true
            log "committed changes from iteration $ITERATION"
        fi
    fi

    # check deadline before cooldown
    if [[ $(date +%s) -ge $DEADLINE ]]; then
        log "time limit reached"
        break
    fi

    # cooldown between iterations
    log "cooling down ${COOLDOWN}s"
    sleep "$COOLDOWN"
done

_print_summary
