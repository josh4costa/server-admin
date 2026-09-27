#!/bin/bash
# Monitorea el uso de disco de la raiz y, si supera el umbral, limpia
# imagenes de Docker sin usar (>72h) y build cache. No toca contenedores,
# volumenes ni datos de produccion. Avisa por Telegram reusando el bot
# de /opt/backups/.env (dueno: ../respaldos/).

set -uo pipefail

THRESHOLD=80
LOG_FILE="/opt/server_admin/contenedores/log.md"
ENV_FILE="/opt/backups/.env"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
USE_PCT=$(df --output=pcent / | tail -1 | tr -dc '0-9')

log() {
    echo "$1" >> "$LOG_FILE"
}

send_telegram() {
    local msg="$1"
    if [ -f "$ENV_FILE" ]; then
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d chat_id="${TELEGRAM_CHAT_ID}" \
                -d text="$msg" \
                -d parse_mode="Markdown" > /dev/null
        fi
    fi
}

if [ "$USE_PCT" -lt "$THRESHOLD" ]; then
    exit 0
fi

log ""
log "### ${TIMESTAMP} — Disco al ${USE_PCT}% (umbral ${THRESHOLD}%)"

docker image prune -af --filter "until=72h" >> "$LOG_FILE" 2>&1
docker builder prune -f >> "$LOG_FILE" 2>&1

AFTER_PCT=$(df --output=pcent / | tail -1 | tr -dc '0-9')

log "- Limpieza automatica ejecutada (imagenes >72h sin usar + build cache)."
log "- Disco antes: ${USE_PCT}% -> despues: ${AFTER_PCT}%."

send_telegram "🐳 *Limpieza automática de Docker*
Disco alcanzó ${USE_PCT}% (umbral ${THRESHOLD}%).
Se liberaron imágenes sin usar (>72h) y build cache.
Disco ahora: ${AFTER_PCT}%."

if [ "$AFTER_PCT" -ge "$THRESHOLD" ]; then
    log "- ADVERTENCIA: el disco sigue sobre el umbral tras la limpieza automatica. Requiere revision manual (posible \`docker system prune --volumes\` con confirmacion de Josue, o liberar espacio fuera de Docker)."
    send_telegram "⚠️ *Alerta*: el disco sigue al ${AFTER_PCT}% después de la limpieza automática de Docker. Requiere revisión manual — puede necesitar acción fuera del alcance seguro (volúmenes, etc.)."
fi
