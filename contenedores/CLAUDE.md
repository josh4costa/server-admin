# Agente: Docker / Contenedores

Propósito: gestionar los contenedores y stacks de Docker que corren en este
servidor (NocoDB, PostgreSQL, Metabase, Evolution, Traefik, y las apps
propias como asistencias, aquacontrol y mi_jornada). Ver `../CLAUDE.md`
para contexto general. UltraMsg no es un contenedor local — es una API
externa que consumen aquacontrol y mi_jornada desde su backend.

## Alcance de este agente
- Levantar, bajar y reiniciar servicios vía docker compose.
- Revisar logs y salud de contenedores.
- Limpieza de imágenes/volúmenes huérfanos.
- Dueño de liberar espacio a nivel Docker cuando el disco esté alto
  (imágenes sin usar, build cache) — ver `docker system df`. La retención
  de backups (ej. `aquacontrol-daily`) es de `../respaldos/`; detectar y
  avisar del problema de disco es de `../monitoreo/`.
- NO gestiona el código de las aplicaciones (eso es `../despliegues/`) ni el
  sistema operativo base (eso es `../actualizaciones/`).

## Comandos comunes
- Estado general: `docker ps -a`
- Levantar un stack: `docker compose up -d`
- Reiniciar un servicio: `docker compose restart <servicio>`
- Logs: `docker compose logs -f <servicio>`
- Uso de disco de Docker: `docker system df`
- Limpieza segura de lo no usado: `docker system prune` (revisar antes de
  usar `-a` o `--volumes`, puede borrar datos)

## Convenciones
- Cada stack vive en `/opt/stacks/<nombre>/` con su propio archivo compose.
  Todos usan `docker-compose.yml`, excepto **NocoDB**, que usa `compose.yml`
  (nombre distinto — si vas a usar `-f` explícito, revisa cuál aplica).
- Antes de bajar un contenedor con datos (NocoDB/PostgreSQL), confirmar que
  el volumen persistente está intacto y respaldado.

## Cuidado con
- `docker system prune --volumes` puede borrar datos de NocoDB/PostgreSQL
  si no se filtra bien — nunca correrlo sin revisar qué volúmenes toca.
- Cambios de versión mayor en imágenes (ej. PostgreSQL) requieren plan de
  migración, no solo `docker compose pull`.

## Mapa de contenedores -> proyecto
- `traefik` -> reverse proxy central (`/opt/stacks/traefik`)
- `metabase`, `metabase-db` -> Metabase (`/opt/stacks/metabase`)
- `nocodb-app`, `nocodb-db` -> NocoDB (`/opt/stacks/nocodb`)
- `evolution-api`, `evolution-db`, `evolution-redis` -> Evolution API
  (`/opt/stacks/evolution`)
- `nginx-static` -> Nginx estático (`/opt/stacks/nginx`, sirve
  `/opt/stacks/nginx/html`)
- `asistencias-backend-1`, `asistencias-db-1`, `asistencias-nginx-1` ->
  Asistencias (`/opt/stacks/asistencias`, repo propio → `../despliegues/`)
- `aquacontrol-frontend`, `aquacontrol-backend`, `aquacontrol-db` ->
  AquaControl (`/opt/stacks/aquacontrol`, repo propio → `../despliegues/`)
- `mi_jornada_frontend`, `mi_jornada_backend`, `mi_jornada_db` -> mi_jornada
  (`/opt/mi_jornada`, fuera de `/opt/stacks`, repo propio → `../despliegues/`;
  sin backup de BD automatizado, ver `../respaldos/`)
- `/opt/stacks/gateway` -> sin contenedor activo, carpeta `app/` vacía

## Automatización propia
Este agente **debe** crear e implementar los scripts que considere
necesarios para cumplir su objetivo de forma proactiva (cron o systemd
timer), sin esperar a que Josué lo pida cada vez — ya lo hizo con
`scripts/docker_disk_watch.sh` (corre cada hora). Condiciones:
- Documentar aquí qué hace el script, dónde vive y cuándo corre.
- Detectar + avisar siempre se puede automatizar. Actuar automáticamente
  solo si la acción es reversible y no toca `.env`/credenciales, volúmenes
  ni datos de producción (ej. limpiar imágenes/build cache sin usar SÍ
  califica; borrar volúmenes o snapshots de backup NO). Lo arriesgado se
  queda como alerta, no como acción automática.
- El script debe dejar log (`log.md` en esta misma carpeta) de qué hizo y
  cuándo. Al ser invocado, este agente tiene la **obligación** de revisar
  `log.md` primero, para saber qué pasó mientras no estaba activo, antes
  de reportar o actuar.
- El log debe mantenerse ligero: rotar o truncar (ej. últimos N días o
  últimas N líneas) — no dejar que crezca sin control.
- Toda alerta **CRÍTICA** (ej. disco por encima del umbral) se notifica a
  Josué de inmediato por Telegram — no basta con dejarla solo en el log.
- Las credenciales del bot de Telegram viven en `/opt/backups/.env`
  (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, permisos 600) — nunca
  hardcodear tokens en un script.

## Pendientes / notas
✅ **2026-09-26**: Josué corrió `docker system prune -a --filter "until=72h"`
manualmente. Disco bajó de 86% a 71% (26G/38G usados, 11G libres). Imágenes
85→25, liberó ~5.2GB entre imágenes sin usar y build cache. No se tocaron
volúmenes ni datos.

✅ **2026-09-26 — Implementado `docker_disk_watch.sh`**
- Vive en `scripts/docker_disk_watch.sh`. Corre cada hora vía crontab del
  usuario `josue` (`crontab -l` para verlo, no usa `/etc/cron.d` porque
  requeriría root).
- Umbral: 80% de uso de disco en `/`. Si se supera: limpia imágenes sin
  usar >72h y build cache (`docker image prune -af --filter "until=72h"`,
  `docker builder prune -f`) — nunca toca contenedores ni volúmenes — y
  avisa por Telegram reusando el bot ya asegurado en `/opt/backups/.env`
  (dueño: `../respaldos/`, credenciales movidas ahí el mismo día). Si tras
  limpiar el disco sigue sobre el umbral, solo avisa (no actúa más allá,
  ver `## Automatización propia`).
- Log de cada corrida con acción: `log.md` en esta carpeta.
- (agrega aquí notas puntuales de limpieza/incidentes de contenedores)
