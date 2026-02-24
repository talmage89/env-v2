#!/usr/bin/env bash

# Apply network firewall if a restricted profile is configured.
# "full" and unset mean no restrictions; "none" is handled at the
# Docker level (--network none) and never reaches here.

if [[ -n "${CAGE_NETWORK_PROFILE:-}" && "$CAGE_NETWORK_PROFILE" != "full" ]]; then
    sudo /etc/cage-network/apply-firewall.sh "$CAGE_NETWORK_PROFILE"
fi

exec "$@"
