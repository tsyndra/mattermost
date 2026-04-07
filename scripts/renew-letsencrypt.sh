#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LE_ROOT="$DOCKER_DIR/letsencrypt"
LE_LIB="$DOCKER_DIR/letsencrypt-lib"

docker run --rm \
  -v "$LE_ROOT:/etc/letsencrypt" \
  -v "$LE_LIB:/var/lib/letsencrypt" \
  -v "/var/www/certbot:/var/www/certbot" \
  certbot/certbot renew --webroot -w /var/www/certbot

LIVE="$LE_ROOT/live/mm.tsyndra.ru/privkey.pem"
if [[ -f "$LIVE" ]]; then
  chmod 644 "$LIVE" 2>/dev/null || sudo chmod 644 "$LIVE"
fi
cd "$DOCKER_DIR"
docker compose -f docker-compose.yml -f docker-compose.nginx.yml -f docker-compose.override.yml exec -T nginx nginx -s reload 2>/dev/null || \
  docker compose -f docker-compose.yml -f docker-compose.nginx.yml -f docker-compose.override.yml up -d --force-recreate nginx
