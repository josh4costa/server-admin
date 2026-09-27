#!/bin/bash

# REVISIÓN SEMANAL DE VERSIONES - Weekly Version Check
# Ejecuta: Cada lunes a las 08:00 UTC
# Responsabilidad: Verificar versiones nuevas disponibles en Docker Hub
# Log: /opt/server_admin/aplicaciones/logs/versions_weekly.log

LOGDIR="/opt/server_admin/aplicaciones/logs"
LOGFILE="$LOGDIR/versions_weekly.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
WEEK=$(date '+%Y-W%V')

# Crear archivo de log si no existe
[ ! -f "$LOGFILE" ] && touch "$LOGFILE"

# Función para obtener digest de imagen
get_image_digest() {
  local image=$1
  docker pull "$image" 2>/dev/null | grep -oP 'Digest: \K[^$]*' || echo "UNKNOWN"
}

# Encabezado
{
  echo "════════════════════════════════════════════════════════"
  echo "WEEKLY VERSION CHECK - $TIMESTAMP (Week $WEEK)"
  echo "════════════════════════════════════════════════════════"
  echo ""

  echo "Verificando versiones disponibles en Docker Hub..."
  echo ""

  # Apps a verificar
  declare -A apps=(
    ["Traefik"]="traefik:latest"
    ["Metabase"]="metabase/metabase:latest"
    ["NocoDB"]="nocodb/nocodb:latest"
    ["Evolution API"]="evoapicloud/evolution-api:latest"
    ["PostgreSQL 15"]="postgres:15"
    ["Redis 7"]="redis:7-alpine"
  )

  updates_available=0

  for app in "${!apps[@]}"; do
    image="${apps[$app]}"

    echo "📦 $app ($image)"

    # Obtener digest actual
    current_digest=$(docker image inspect "$image" --format='{{.ID}}' 2>/dev/null || echo "NOT_FOUND")

    if [ "$current_digest" = "NOT_FOUND" ]; then
      echo "   Status: ❓ Imagen no existe localmente (nunca se ha descargado)"
      echo "   Actual Digest: UNKNOWN"
    else
      # Obtener digest de la versión disponible
      new_digest=$(docker pull "$image" 2>&1 | grep -i "digest:" | tail -1 | sed 's/.*Digest: //')

      if [ -z "$new_digest" ]; then
        new_digest=$(docker image inspect "$image" --format='{{.ID}}' 2>/dev/null)
      fi

      if [ "$current_digest" = "$new_digest" ] || [ "${current_digest#*:}" = "${new_digest#*:}" ]; then
        echo "   Status: ✅ Actualizado"
        echo "   Digest: ${current_digest:0:20}..."
      else
        echo "   Status: ⚠️  ACTUALIZACIÓN DISPONIBLE"
        echo "   Current: ${current_digest:0:20}..."
        echo "   Latest:  ${new_digest:0:20}..."
        updates_available=$((updates_available + 1))
      fi
    fi
    echo ""
  done

  echo "════════════════════════════════════════════════════════"

  if [ $updates_available -eq 0 ]; then
    echo "✅ RESULTADO: Todas las imágenes están actualizadas"
  else
    echo "⚠️  RESULTADO: $updates_available actualización(es) disponible(s)"
    echo ""
    echo "Para revisar cambios y actualizar, ejecuta:"
    echo "  cd /opt/server_admin/aplicaciones"
    echo "  # Revisar CLAUDE.md para secuencia de actualización"
  fi

  echo "════════════════════════════════════════════════════════"

} >> "$LOGFILE" 2>&1

# Mantener solo los últimos 12 semanas de logs
find "$LOGDIR" -name "versions_weekly.log*" -mtime +84 -delete 2>/dev/null

echo "✅ Weekly version check completado" >> "$LOGFILE"
