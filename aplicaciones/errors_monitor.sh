#!/bin/bash

# MONITOREO DE ERRORES CRÍTICOS - Real-time Error Monitor
# Ejecuta: Cada hora
# Responsabilidad: Detectar excepciones/errores críticos en logs
# Log: /opt/server_admin/aplicaciones/logs/errors_alert.log

LOGDIR="/opt/server_admin/aplicaciones/logs"
LOGFILE="$LOGDIR/errors_alert.log"
ALERT_THRESHOLD=5  # Número de errores para considerar crítico
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Crear archivo de log si no existe
[ ! -f "$LOGFILE" ] && touch "$LOGFILE"

# Función para registrar alertas
log_alert() {
  echo "[$TIMESTAMP] $1" >> "$LOGFILE"
}

# Función para revisar logs de una app
check_app_errors() {
  local app=$1
  local service=$2
  local stack=$3
  local ignore_pattern=$4

  cd "$stack" 2>/dev/null || return 1

  # Obtener errores de los últimos 60 minutos
  if [ -z "$ignore_pattern" ]; then
    errors=$(docker compose logs --tail 500 "$service" 2>&1 | \
      grep -i "error\|exception\|fatal\|panic" | wc -l)
  else
    errors=$(docker compose logs --tail 500 "$service" 2>&1 | \
      grep -i "error\|exception\|fatal\|panic" | \
      grep -v "$ignore_pattern" | wc -l)
  fi

  echo $errors
}

# Inicio de chequeo
log_alert "════════════════════════════════════════════"
log_alert "HOURLY ERROR MONITOR CHECK"
log_alert "════════════════════════════════════════════"

total_errors=0
critical_apps=()

# Verificar TRAEFIK
traefik_errors=$(check_app_errors "Traefik" "traefik" "/opt/stacks/traefik" "")
if [ "$traefik_errors" -gt "$ALERT_THRESHOLD" ]; then
  log_alert "⚠️  TRAEFIK: $traefik_errors errores detectados"
  critical_apps+=("Traefik")
  total_errors=$((total_errors + traefik_errors))
else
  [ "$traefik_errors" -gt 0 ] && log_alert "ℹ️  Traefik: $traefik_errors errores (bajo umbral)"
fi

# Verificar METABASE (ignorar warnings de Anthropic)
metabase_errors=$(check_app_errors "Metabase" "metabase" "/opt/stacks/metabase" "Anthropic")
if [ "$metabase_errors" -gt "$ALERT_THRESHOLD" ]; then
  log_alert "⚠️  METABASE: $metabase_errors errores detectados"
  critical_apps+=("Metabase")
  total_errors=$((total_errors + metabase_errors))
else
  [ "$metabase_errors" -gt 0 ] && log_alert "ℹ️  Metabase: $metabase_errors errores (bajo umbral)"
fi

# Verificar NOCODB
nocodb_errors=$(check_app_errors "NocoDB" "nocodb" "/opt/stacks/nocodb" "")
if [ "$nocodb_errors" -gt "$ALERT_THRESHOLD" ]; then
  log_alert "⚠️  NOCODB: $nocodb_errors errores detectados"
  critical_apps+=("NocoDB")
  total_errors=$((total_errors + nocodb_errors))
else
  [ "$nocodb_errors" -gt 0 ] && log_alert "ℹ️  NocoDB: $nocodb_errors errores (bajo umbral)"
fi

# Verificar EVOLUTION
evolution_errors=$(check_app_errors "Evolution" "evolution" "/opt/stacks/evolution" "")
if [ "$evolution_errors" -gt "$ALERT_THRESHOLD" ]; then
  log_alert "⚠️  EVOLUTION: $evolution_errors errores detectados"
  critical_apps+=("Evolution")
  total_errors=$((total_errors + evolution_errors))
else
  [ "$evolution_errors" -gt 0 ] && log_alert "ℹ️  Evolution: $evolution_errors errores (bajo umbral)"
fi

# Resumen
log_alert ""
if [ ${#critical_apps[@]} -eq 0 ]; then
  log_alert "✅ RESULTADO: Sin errores críticos detectados"
else
  log_alert "🚨 ALERTAS: ${#critical_apps[@]} app(s) con errores críticos:"
  for app in "${critical_apps[@]}"; do
    log_alert "   - $app"
  done
  log_alert ""
  log_alert "ACCIÓN REQUERIDA: Revisar logs de las apps alertadas"
  log_alert "Comando: docker compose -f /opt/stacks/<app>/docker-compose.yml logs --tail 50"
fi

log_alert "════════════════════════════════════════════"
log_alert ""

# Mantener solo los últimos 7 días de logs
find "$LOGDIR" -name "errors_alert.log*" -mtime +7 -delete 2>/dev/null

# Si hay errores críticos, crear archivo de alerta para revisar luego
if [ ${#critical_apps[@]} -gt 0 ]; then
  alert_file="$LOGDIR/ALERT_$(date '+%Y%m%d_%H%M%S').txt"
  {
    echo "⚠️  ALERTA DE ERRORES CRÍTICOS"
    echo "Timestamp: $TIMESTAMP"
    echo "Apps afectadas: ${critical_apps[*]}"
    echo ""
    echo "Revisar log completo en: $LOGFILE"
  } > "$alert_file"
fi
