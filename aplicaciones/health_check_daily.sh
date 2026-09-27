#!/bin/bash

# CHEQUEO DIARIO DE SALUD - Daily Health Check
# Ejecuta: Cada día a las 06:00 UTC
# Responsabilidad: Revisar logs de apps en busca de errores
# Log: /opt/server_admin/aplicaciones/logs/health_check_daily.log

LOGDIR="/opt/server_admin/aplicaciones/logs"
LOGFILE="$LOGDIR/health_check_daily.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Crear archivo de log si no existe
[ ! -f "$LOGFILE" ] && touch "$LOGFILE"

# Función para registrar
log_entry() {
  echo "[${TIMESTAMP}] $1" >> "$LOGFILE"
}

# Encabezado
{
  echo "════════════════════════════════════════════════════════"
  echo "DAILY HEALTH CHECK - $TIMESTAMP"
  echo "════════════════════════════════════════════════════════"
  echo ""

  # Verificar estado de contenedores
  echo "1. ESTADO DE CONTENEDORES"
  docker ps --filter "name=traefik|name=metabase|name=nocodb|name=evolution" \
    --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "ERROR: No se pudo obtener estado"
  echo ""

  # Revisar errores en logs
  echo "2. VERIFICACIÓN DE ERRORES EN LOGS"

  apps=("traefik" "metabase" "nocodb" "evolution")
  errors_found=0

  for app in "${apps[@]}"; do
    case $app in
      traefik)
        stack="/opt/stacks/traefik"
        service="traefik"
        ;;
      metabase)
        stack="/opt/stacks/metabase"
        service="metabase"
        ;;
      nocodb)
        stack="/opt/stacks/nocodb"
        service="nocodb"
        ;;
      evolution)
        stack="/opt/stacks/evolution"
        service="evolution"
        ;;
    esac

    echo ""
    echo "  🔍 $app:"
    cd "$stack" 2>/dev/null || { echo "    ❌ Directorio no existe"; continue; }

    if docker compose logs --tail 20 "$service" 2>&1 | grep -i "error" | grep -v "Anthropic" > /tmp/errors_$app.txt 2>&1; then
      error_count=$(wc -l < /tmp/errors_$app.txt)
      echo "    ⚠️  $error_count línea(s) de error detectada(s):"
      head -3 /tmp/errors_$app.txt | sed 's/^/      /'
      errors_found=$((errors_found + 1))
    else
      echo "    ✅ Sin errores"
    fi
  done

  echo ""
  echo "3. CONECTIVIDAD DE BASES DE DATOS"

  # Metabase DB
  if docker ps --filter "name=metabase-db" --quiet 2>/dev/null | grep -q .; then
    if docker compose -f /opt/stacks/metabase/docker-compose.yml exec -T metabase-db pg_isready -U postgres > /dev/null 2>&1; then
      echo "  ✅ Metabase → PostgreSQL 15"
    else
      echo "  ❌ Metabase → PostgreSQL 15 (NO RESPONDE)"
      errors_found=$((errors_found + 1))
    fi
  fi

  # NocoDB DB
  if docker ps --filter "name=nocodb-db" --quiet 2>/dev/null | grep -q .; then
    if docker compose -f /opt/stacks/nocodb/docker-compose.yml exec -T nocodb-db pg_isready -U postgres > /dev/null 2>&1; then
      echo "  ✅ NocoDB → PostgreSQL 15"
    else
      echo "  ❌ NocoDB → PostgreSQL 15 (NO RESPONDE)"
      errors_found=$((errors_found + 1))
    fi
  fi

  # Evolution DB
  if docker ps --filter "name=evolution-db" --quiet 2>/dev/null | grep -q .; then
    if docker compose -f /opt/stacks/evolution/docker-compose.yml exec -T evolution-db pg_isready -U postgres > /dev/null 2>&1; then
      echo "  ✅ Evolution → PostgreSQL 15"
    else
      echo "  ❌ Evolution → PostgreSQL 15 (NO RESPONDE)"
      errors_found=$((errors_found + 1))
    fi
  fi

  # Evolution Redis
  if docker ps --filter "name=evolution-redis" --quiet 2>/dev/null | grep -q .; then
    if docker compose -f /opt/stacks/evolution/docker-compose.yml exec -T evolution-redis redis-cli ping > /dev/null 2>&1; then
      echo "  ✅ Evolution → Redis 7"
    else
      echo "  ❌ Evolution → Redis 7 (NO RESPONDE)"
      errors_found=$((errors_found + 1))
    fi
  fi

  echo ""
  echo "════════════════════════════════════════════════════════"

  if [ $errors_found -eq 0 ]; then
    echo "✅ RESULTADO: Todas las aplicaciones funcionan normalmente"
  else
    echo "⚠️  RESULTADO: Se detectaron $errors_found problema(s) - REVISAR"
  fi

  echo "════════════════════════════════════════════════════════"

} >> "$LOGFILE" 2>&1

# Mantener solo los últimos 30 días de logs (rotación)
find "$LOGDIR" -name "health_check_daily.log*" -mtime +30 -delete 2>/dev/null

echo "✅ Daily health check completado" >> "$LOGFILE"
