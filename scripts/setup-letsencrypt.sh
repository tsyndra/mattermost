#!/usr/bin/env bash
# Получение Let's Encrypt для mm.tsyndra.ru и подключение к nginx Mattermost (Docker).
# Требуется: DNS A для mm.tsyndra.ru → этот сервер; порт 80 снаружи доступен для HTTP-01.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NGINX_SITE="$DOCKER_DIR/nginx-host/mm.tsyndra.ru.conf"
LE_ROOT="$DOCKER_DIR/letsencrypt"
LE_LIB="$DOCKER_DIR/letsencrypt-lib"
LIVE_DIR="$LE_ROOT/live/mm.tsyndra.ru"

EMAIL="${CERTBOT_EMAIL:-ssl@tsyndra.ru}"

if [[ ! -f "$NGINX_SITE" ]]; then
  echo "Не найден $NGINX_SITE" >&2
  exit 1
fi

echo "==> Установка vhost для ACME на порту 80 (нужен sudo)"
sudo cp "$NGINX_SITE" /etc/nginx/sites-available/mm.tsyndra.ru
sudo ln -sf /etc/nginx/sites-available/mm.tsyndra.ru /etc/nginx/sites-enabled/mm.tsyndra.ru
sudo nginx -t
sudo systemctl reload nginx

mkdir -p "$LE_ROOT" "$LE_LIB"

echo "==> Запрос сертификата (certbot в Docker, webroot /var/www/certbot)"
docker run --rm \
  -v "$LE_ROOT:/etc/letsencrypt" \
  -v "$LE_LIB:/var/lib/letsencrypt" \
  -v "/var/www/certbot:/var/www/certbot" \
  certbot/certbot certonly \
  --webroot -w /var/www/certbot \
  -d mm.tsyndra.ru \
  --non-interactive --agree-tos \
  -m "$EMAIL" \
  --preferred-challenges http

echo "==> Права на чтение ключа контейнером nginx (uid 101)"
sudo chmod 644 "$LIVE_DIR/privkey.pem"

echo "==> Обновление .env (CERT_PATH / KEY_PATH)"
ENV_FILE="$DOCKER_DIR/.env"
if grep -q '^CERT_PATH=' "$ENV_FILE"; then
  sed -i 's|^CERT_PATH=.*|CERT_PATH=./letsencrypt/live/mm.tsyndra.ru/fullchain.pem|' "$ENV_FILE"
else
  echo 'CERT_PATH=./letsencrypt/live/mm.tsyndra.ru/fullchain.pem' >> "$ENV_FILE"
fi
if grep -q '^KEY_PATH=' "$ENV_FILE"; then
  sed -i 's|^KEY_PATH=.*|KEY_PATH=./letsencrypt/live/mm.tsyndra.ru/privkey.pem|' "$ENV_FILE"
else
  echo 'KEY_PATH=./letsencrypt/live/mm.tsyndra.ru/privkey.pem' >> "$ENV_FILE"
fi

echo "==> Перезапуск nginx Mattermost"
cd "$DOCKER_DIR"
docker compose -f docker-compose.yml -f docker-compose.nginx.yml -f docker-compose.override.yml up -d --force-recreate nginx

echo "Готово. Проверка: curl -sI https://mm.tsyndra.ru:30445/ | head -3"
echo "Продление: добавьте в cron: docker run ... certbot renew && $DOCKER_DIR/scripts/renew-letsencrypt.sh"
