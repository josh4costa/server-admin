#!/bin/bash
# Monitor de cambios sin commitear en todos los repos
# Ejecutar: cada 6 horas vía cron
# Log: /opt/server_admin/despliegues/logs/monitor-uncommitted.log

set -e

LOG_FILE="/opt/server_admin/despliegues/logs/monitor-uncommitted.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEND_ALERT="$SCRIPT_DIR/send-telegram.sh"

# Crear log si no existe
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Función para logging
log_msg() {
  local level="$1"
  local msg="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
}

# Función para enviar alerta
source "$SEND_ALERT" 2>/dev/null || true

log_msg "INFO" "=== Iniciando monitoreo de repos ==="

critical_found=0
repos_checked=0
issues=()

# Revisar repos en /opt/stacks
for repo_path in /opt/stacks/*; do
  [ ! -d "$repo_path" ] && continue
  [ ! -d "$repo_path/.git" ] && continue

  repo_name=$(basename "$repo_path")
  repos_checked=$((repos_checked + 1))
  cd "$repo_path"

  # Revisar cambios sin stagear
  status=$(git status --porcelain 2>/dev/null || echo "")
  if [ -n "$status" ]; then
    log_msg "CRÍTICA" "$repo_name: Cambios sin stagear/commitear"
    issues+=("❌ $repo_name: cambios sin commitear")
    critical_found=1
    echo "$status" | sed 's/^/  /' >> "$LOG_FILE"
  fi

  # Revisar commits sin pushear
  ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
  if [ "$ahead" != "0" ]; then
    log_msg "ADVERTENCIA" "$repo_name: $ahead commit(s) sin pushear"
    issues+=("⚠️  $repo_name: $ahead commit(s) sin pushear")
  fi
done

# Revisar /opt/mi_jornada
if [ -d /opt/mi_jornada/.git ]; then
  repos_checked=$((repos_checked + 1))
  cd /opt/mi_jornada

  status=$(git status --porcelain 2>/dev/null || echo "")
  if [ -n "$status" ]; then
    log_msg "CRÍTICA" "mi_jornada: Cambios sin stagear/commitear"
    issues+=("❌ mi_jornada: cambios sin commitear")
    critical_found=1
    echo "$status" | sed 's/^/  /' >> "$LOG_FILE"
  fi

  ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
  if [ "$ahead" != "0" ]; then
    log_msg "ADVERTENCIA" "mi_jornada: $ahead commit(s) sin pushear"
    issues+=("⚠️  mi_jornada: $ahead commit(s) sin pushear")
  fi
fi

# Resumen
log_msg "INFO" "Repos revisados: $repos_checked"

if [ $critical_found -eq 1 ]; then
  # Enviar alerta crítica
  alert_msg="Monitoreo de repos: Cambios sin commitear detectados:\n"
  for issue in "${issues[@]}"; do
    alert_msg="${alert_msg}${issue}\n"
  done

  source "$SEND_ALERT" 2>/dev/null
  send_telegram_alert "CRÍTICA" "$(echo -e "$alert_msg" | head -1)"

  log_msg "INFO" "Alerta enviada a Telegram"
else
  log_msg "INFO" "✅ Todos los repos al día"
fi

log_msg "INFO" "=== Monitoreo completado ==="
