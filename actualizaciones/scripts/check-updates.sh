#!/bin/bash
# Script: Revisor diario de actualizaciones de seguridad
# Corre vía cron diariamente. Detecta solo updates urgentes (security).
# Avisa por Telegram si hay hallazgos. Deja log rotado.

set -e

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$(dirname "$SCRIPT_DIR")/log.md"
BACKUPS_ENV="/opt/backups/.env"
VPS_IP="49.12.67.202"
MAX_LOG_LINES=300  # ~30 días a 10 entradas/día

# Cargar credenciales Telegram
if [ -f "$BACKUPS_ENV" ]; then
    source "$BACKUPS_ENV"
else
    echo "ERROR: No se encuentra $BACKUPS_ENV" >&2
    exit 1
fi

# Función: Enviar aviso por Telegram
send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

# Obtener actualizaciones disponibles
apt-get update > /dev/null 2>&1 || true

# Detectar updates de seguridad (vienen de *-security repos)
SECURITY_UPDATES=$(apt-get upgrade -s 2>/dev/null | grep -i "^Inst" | grep -E "ubuntu-.*-security" || true)

# Timestamp
NOW=$(date '+%Y-%m-%d %H:%M:%S')

# Procesar resultados
if [ -n "$SECURITY_UPDATES" ]; then
    # Hay updates de seguridad
    COUNT=$(echo "$SECURITY_UPDATES" | wc -l)
    MESSAGE="🔴 <b>SEGURIDAD: $COUNT actualizaciones urgentes disponibles</b>%0AVPS: $VPS_IP%0A%0A"
    MESSAGE+="$(echo "$SECURITY_UPDATES" | head -5 | sed 's/Inst /- /' | sed 's/ .*//')"
    if [ $COUNT -gt 5 ]; then
        MESSAGE+="%0A... y $(($COUNT - 5)) más"
    fi

    # Log
    echo "## $NOW — ⚠️ SEGURIDAD DETECTADA" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "**VPS IP**: $VPS_IP" >> "$LOG_FILE"
    echo "**Paquetes urgentes**: $COUNT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "\`\`\`" >> "$LOG_FILE"
    echo "$SECURITY_UPDATES" >> "$LOG_FILE"
    echo "\`\`\`" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # Aviso Telegram
    send_telegram "$MESSAGE"
else
    # Sin updates de seguridad
    echo "## $NOW — ✅ Sin hallazgos" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

# Rotación de log: mantener solo últimas N líneas
if [ -f "$LOG_FILE" ]; then
    LINE_COUNT=$(wc -l < "$LOG_FILE")
    if [ "$LINE_COUNT" -gt "$MAX_LOG_LINES" ]; then
        # Guardar últimas N líneas y descartar el resto
        tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
fi
