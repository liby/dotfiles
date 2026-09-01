#!/bin/zsh
set -euo pipefail

# Suppress telemetry before the persisted setting exists.
GLAB_SEND_TELEMETRY=false /opt/homebrew/bin/glab config set telemetry false --global
/opt/homebrew/bin/glab config set check_update false --global
