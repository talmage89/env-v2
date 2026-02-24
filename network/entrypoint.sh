#!/usr/bin/env bash

# Apply network firewall if a restricted profile is configured.
# "full" and unset mean no restrictions; "none" is handled at the
# Docker level (--network none) and never reaches here.

if [[ -n "${DEV_NETWORK_PROFILE:-}" && "$DEV_NETWORK_PROFILE" != "full" ]]; then
    sudo /etc/dev-network/apply-firewall.sh "$DEV_NETWORK_PROFILE"
fi

exec "$@"
