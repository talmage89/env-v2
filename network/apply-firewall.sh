#!/usr/bin/env bash
set -euo pipefail

# apply-firewall.sh - Resolve a network profile and apply iptables rules.
# Called by entrypoint.sh when a restricted network profile is active.

PROFILE_DIR="/etc/dev-network/profiles"
PROFILE_NAME="${1:?Usage: apply-firewall.sh <profile-name>}"

log() { echo "[firewall] $*"; }

# --- Recursively resolve includes and collect allow rules ---

declare -A SEEN_PROFILES
ALLOW_RULES=()

resolve_profile() {
    local name="$1"
    local file="$PROFILE_DIR/$name.profile"

    [[ -n "${SEEN_PROFILES[$name]:-}" ]] && return
    SEEN_PROFILES[$name]=1

    if [[ ! -f "$file" ]]; then
        log "ERROR: profile not found: $file"
        return 1
    fi

    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^include[[:space:]]+(.+)$ ]]; then
            resolve_profile "${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^allow[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+)$ ]]; then
            ALLOW_RULES+=("${BASH_REMATCH[1]} ${BASH_REMATCH[2]}")
        else
            log "WARNING: unrecognized line: $line"
        fi
    done < "$file"
}

# --- Resolve domain to IPv4 addresses ---

resolve_ips() {
    getent ahostsv4 "$1" 2>/dev/null | awk '{print $1}' | sort -u
}

# --- Main ---

log "applying profile: $PROFILE_NAME"

resolve_profile "$PROFILE_NAME"

if [[ ${#ALLOW_RULES[@]} -eq 0 ]]; then
    log "ERROR: no allow rules found for profile '$PROFILE_NAME'"
    exit 1
fi

# Flush existing OUTPUT rules
iptables -F OUTPUT

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow Docker embedded DNS
iptables -A OUTPUT -d 127.0.0.11 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d 127.0.0.11 -p tcp --dport 53 -j ACCEPT

# Process allow rules
for rule in "${ALLOW_RULES[@]}"; do
    read -r domain port <<< "$rule"
    ips=$(resolve_ips "$domain")
    if [[ -z "$ips" ]]; then
        log "WARNING: could not resolve $domain, skipping"
        continue
    fi
    for ip in $ips; do
        iptables -A OUTPUT -d "$ip" -p tcp --dport "$port" -j ACCEPT
        log "allow $domain ($ip) :$port"
    done
done

# Default deny
iptables -A OUTPUT -j DROP

# Block all IPv6 outbound to prevent leaks
ip6tables -P OUTPUT DROP 2>/dev/null || true

log "firewall applied: ${#ALLOW_RULES[@]} rules"
