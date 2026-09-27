# Agente: Actualizaciones del sistema

Propósito: mantener el sistema operativo y los paquetes del servidor al día
sin romper servicios en producción. Ver `../CLAUDE.md` para contexto
general.

## Alcance de este agente
- Actualizaciones de SO (apt), kernel, y paquetes base.
- NO gestiona actualizaciones de las imágenes/contenedores de Docker en sí
  (eso es `../contenedores/`), aunque coordina con ese agente si una
  actualización del SO puede afectar a Docker.

## Comandos comunes
- Revisar antes de aplicar: `apt update && apt list --upgradable`
- Aplicar: `apt upgrade -y` (solo tras confirmar que no hay riesgo)
- Ver si el kernel cambió (para saber si se requiere reinicio):
  `apt list --upgradable | grep linux-image`

## Reglas
- Nunca actualizar en horario pico de las sucursales.
- Confirmar que el respaldo más reciente (ver `../respaldos/`) esté sano
  antes de actualizar.
- Si la actualización incluye paquetes relacionados a Docker, revisar
  changelog antes de aplicar una versión mayor.
- Registrar cada actualización aplicada (fecha, paquetes, resultado) en un
  `log.md` dentro de esta misma carpeta.

## Cuidado con
- Reinicios automáticos de servicios tras `apt upgrade` — verificar que los
  contenedores sigan corriendo después.
- Actualizaciones de seguridad urgentes (CVEs) vs. actualizaciones de
  rutina — las urgentes pueden justificar romper la regla de horario.

## Automatización propia

### Scripts desplegados

**`scripts/check-updates.sh`** — Revisor diario de actualizaciones de seguridad
- **Dónde**: `/opt/server_admin/actualizaciones/scripts/check-updates.sh`
- **Cuándo**: Todos los días a las **6:00 AM** (cron: `0 6 * * *`)
- **Qué hace**:
  1. Corre `apt-get update && apt-get upgrade -s` para detectar actualizaciones disponibles
  2. Filtra solo **updates de seguridad** (que vienen de repos `*-security` en Ubuntu)
  3. Si hay hallazgos: 
     - Envía **aviso por Telegram** con la IP del VPS (49.12.67.202), cantidad y lista de paquetes
     - Escribe en `log.md` con timestamp y detalles
  4. Si no hay hallazgos: solo anota en `log.md` que revisó sin problemas
  5. Rota `log.md` automáticamente: mantiene máximo 300 líneas (~30 días de histórico)
- **Credenciales**: Usa Telegram token + chat ID de `/opt/backups/.env` (dueño: `../respaldos/`)
- **Log**: Todos los hallazgos en `log.md`, con rotación automática para no engordar el archivo

Esta automatización **solo detecta y avisa**. La **aplicación de updates** (`apt upgrade`) 
siempre requiere confirmación manual tras verificar respaldo y horario (ver "Reglas" arriba).

---

Condiciones generales de automatización propia — este agente **debe**
crear e implementar los scripts que considere necesarios para cumplir su
objetivo, sin esperar a que Josué lo pida:
- Documentar aquí qué hace el script, dónde vive y cuándo corre.
- Detectar + avisar siempre se puede automatizar. Aplicar la actualización
  (`apt upgrade`) NUNCA de forma automática — siempre pasa por confirmar
  respaldo y horario, según las reglas de arriba.
- El script debe dejar log de qué detectó y cuándo — usa el `log.md` de
  esta carpeta (ya mencionado en "Reglas" arriba). Al ser invocado, este
  agente tiene la **obligación** de revisar `log.md` primero, para saber
  qué pasó mientras no estaba activo, antes de reportar.
- El log debe mantenerse ligero — `check-updates.sh` ya lo hace bien
  (rota `log.md` a máximo 300 líneas); cualquier script nuevo debe seguir
  el mismo patrón.
- Toda alerta **CRÍTICA** se notifica a Josué de inmediato por Telegram —
  no basta con dejarla solo en el log.
- Las credenciales del bot de Telegram viven en `/opt/backups/.env`
  (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, permisos 600, dueño
  `../respaldos/`) — nunca hardcodear tokens en un script.

## Pendientes / notas
- (agrega aquí historial o notas de actualizaciones específicas)
