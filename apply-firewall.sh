#!/usr/bin/env bash
# Run with sudo when UFW is enabled. Opens Mattermost web + Calls (RTC) ports.
# Cloud panel: allow the same TCP/UDP rules for your VPS security group.
set -euo pipefail
# Порты должны совпадать с HTTPS_PORT и CALLS_HOST_PORT в .env
ufw allow 30445/tcp comment 'Mattermost HTTPS'
ufw allow 18444/tcp comment 'Mattermost Calls RTC fallback'
ufw allow 18444/udp comment 'Mattermost Calls RTC'
ufw status verbose
