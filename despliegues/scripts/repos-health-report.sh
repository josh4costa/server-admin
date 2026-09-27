#!/bin/bash
# Reporte de salud de todos los repos
# Ejecutar: diario (8am)
# Log: /opt/server_admin/despliegues/logs/repos-health-report.log

set -e

LOG_FILE="/opt/server_admin/despliegues/logs/repos-health-report.log"
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

log_msg "INFO" "=== Reporte de salud de repos ==="

# Tabla de resultados
declare -a results

# Revisar cada repo
repos=(
  "/opt/stacks/asistencias:asistencias"
  "/opt/stacks/nocodb:nocodb"
  "/opt/stacks/nginx:nginx"
  "/opt/stacks/evolution:evolution"
  "/opt/stacks/metabase:metabase"
  "/opt/stacks/traefik:traefik"
  "/opt/stacks/aquacontrol:aquacontrol"
  "/opt/stacks/nginx/html:nginx/html"
  "/opt/mi_jornada:mi_jornada"
)

critical_issues=0

for repo_def in "${repos[@]}"; do
  IFS=':' read -r repo_path repo_name <<< "$repo_def"

  if [ ! -d "$repo_path" ]; then
    results+=("❌ $repo_name | repo_path_not_found")
    continue
  fi

  if [ ! -d "$repo_path/.git" ]; then
    results+=("⚠️  $repo_name | not_a_git_repo")
    continue
  fi

  cd "$repo_path"

  # Obtener información
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  status_changes=$(git status --porcelain 2>/dev/null | wc -l || echo "0")
  ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")

  # Determinar estado
  if [ "$status_changes" != "0" ]; then
    status_str="❌ has_changes"
    critical_issues=$((critical_issues + 1))
  elif [ "$ahead" != "0" ]; then
    status_str="⚠️  $ahead_commits"
    critical_issues=$((critical_issues + 1))
  else
    status_str="✅ clean"
  fi

  results+=("$status_str | $repo_name | $branch | changes:$status_changes | ahead:$ahead")
done

# Logging
log_msg "INFO" "=== Resultados ==="
for result in "${results[@]}"; do
  log_msg "INFO" "$result"
done

log_msg "INFO" "Problemas detectados: $critical_issues"

# Tabla formateada en log
{
  echo ""
  echo "┌─────────────────────────┬────────┬───────────┬──────────────┐"
  echo "│ Repo                    │ Rama   │ Cambios   │ Sin pushear  │"
  echo "├─────────────────────────┼────────┼───────────┼──────────────┤"

  for repo_def in "${repos[@]}"; do
    IFS=':' read -r repo_path repo_name <<< "$repo_def"

    if [ ! -d "$repo_path/.git" ]; then
      printf "│ %-23s │ N/A    │ N/A       │ N/A          │\n" "$repo_name" >> "$LOG_FILE"
      continue
    fi

    cd "$repo_path"
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    changes=$(git status --porcelain 2>/dev/null | wc -l || echo "0")
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")

    printf "│ %-23s │ %-6s │ %-9s │ %-12s │\n" "$repo_name" "$branch" "$changes" "$ahead" >> "$LOG_FILE"
  done

  echo "└─────────────────────────┴────────┴───────────┴──────────────┘" >> "$LOG_FILE"
} >> "$LOG_FILE"

log_msg "INFO" "=== Reporte completado ==="

# Si hay problemas críticos, enviar alerta
if [ $critical_issues -gt 0 ]; then
  source "$SEND_ALERT" 2>/dev/null || true
  send_telegram_alert "CRÍTICA" "Reporte de repos: $critical_issues problema(s) detectado(s). Ver log para detalles."
fi
