#!/bin/bash
# Función auxiliar para enviar mensajes a Telegram
# Uso: send_telegram_alert "CRÍTICA" "Mensaje de error"

send_telegram_alert() {
  local level="$1"
  local message="$2"

  # Cargar variables de Telegram
  if [ ! -f /opt/backups/.env ]; then
    echo "[ERROR] /opt/backups/.env no encontrado" >&2
    return 1
  fi
  source /opt/backups/.env

  # Solo enviar si es CRÍTICA
  if [ "$level" != "CRÍTICA" ]; then
    return 0
  fi

  # Validar variables
  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "[ERROR] Variables de Telegram no configuradas" >&2
    return 1
  fi

  # Formatear mensaje
  local formatted_message="🚨 [$level] $message"

  # Enviar a Telegram
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${formatted_message}" \
    -d "parse_mode=HTML" > /dev/null 2>&1

  return $?
}

# Si se ejecuta directamente (test)
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  send_telegram_alert "CRÍTICA" "Test: script de alertas funcionando"
fi
