#!/bin/bash
# Limpieza de snapshots viejos en aquacontrol-releases
# Política: conservar últimos 5 + los que tengan nombre especial
# Ejecutar: semanal (domingos a medianoche)
# Log: /opt/server_admin/despliegues/logs/cleanup-releases.log

set -e

RELEASES_DIR="/opt/stacks/aquacontrol-releases"
LOG_FILE="/opt/server_admin/despliegues/logs/cleanup-releases.log"
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

# Verificar que el directorio existe
if [ ! -d "$RELEASES_DIR" ]; then
  log_msg "ERROR" "Directorio $RELEASES_DIR no existe"
  source "$SEND_ALERT" 2>/dev/null || true
  send_telegram_alert "CRÍTICA" "cleanup-aquacontrol: Directorio $RELEASES_DIR no existe"
  exit 1
fi

log_msg "INFO" "=== Iniciando limpieza de snapshots ==="

cd "$RELEASES_DIR"

# Obtener lista de snapshots, ordenados por fecha (más recientes primero)
mapfile -t all_releases < <(ls -d */ 2>/dev/null | sed 's/\///' | sort -rV)

log_msg "INFO" "Snapshots encontrados: ${#all_releases[@]}"

# Separar en dos grupos: especiales y normales
special_releases=()
normal_releases=()

for release in "${all_releases[@]}"; do
  if [[ "$release" =~ ^[a-z]+-[0-9]{14}z$ ]]; then
    # Es especial (tiene nombre: linares-, whatsapp-, etc.)
    special_releases+=("$release")
  else
    # Es normal (solo timestamp)
    normal_releases+=("$release")
  fi
done

log_msg "INFO" "Especiales: ${#special_releases[@]} | Normales: ${#normal_releases[@]}"

# Marcar para borrar: mantener solo los 5 últimos normales
releases_to_delete=()
keep_count=5

for i in "${!normal_releases[@]}"; do
  if [ $i -ge $keep_count ]; then
    releases_to_delete+=("${normal_releases[$i]}")
  fi
done

# Logging de lo que se va a borrar
log_msg "INFO" "Snapshots a conservar (últimos $keep_count + especiales):"
for release in "${normal_releases[@]:0:$keep_count}"; do
  log_msg "INFO" "  ✅ CONSERVAR: $release (normal)"
done
for release in "${special_releases[@]}"; do
  log_msg "INFO" "  ✅ CONSERVAR: $release (especial)"
done

# Borrar
if [ ${#releases_to_delete[@]} -gt 0 ]; then
  log_msg "INFO" "Borrando ${#releases_to_delete[@]} snapshot(s) viejos:"

  total_size_before=$(du -sh "$RELEASES_DIR" | cut -f1)

  for release in "${releases_to_delete[@]}"; do
    log_msg "INFO" "  🗑️  Borrando: $release"
    size=$(du -sh "$release" 2>/dev/null | cut -f1)
    rm -rf "$release"
    log_msg "INFO" "     Liberado: $size"
  done

  total_size_after=$(du -sh "$RELEASES_DIR" | cut -f1)

  log_msg "INFO" "Limpieza completada. Espacio: $total_size_before → $total_size_after"
else
  log_msg "INFO" "No hay snapshots para borrar (todos son recientes o especiales)"
fi

log_msg "INFO" "=== Limpieza finalizada ==="
