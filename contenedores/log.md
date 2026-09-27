# Log — agente Contenedores

Este archivo registra qué hicieron los scripts automáticos de este agente y
cuándo. Revisar aquí primero al ser invocado, antes de reportar o actuar.

### 2026-09-26 — Setup de `docker_disk_watch.sh`
- Script creado en `scripts/docker_disk_watch.sh`, agregado al crontab del
  usuario `josue` (corre cada hora, `0 * * * *`).
- Umbral: 80% de uso de disco en `/`. Si se supera, corre
  `docker image prune -af --filter "until=72h"` y `docker builder prune -f`
  (no toca contenedores ni volúmenes) y avisa por Telegram reusando el bot
  configurado en `/opt/backups/.env` (dueño: `../respaldos/`).
- Si tras la limpieza el disco sigue sobre el umbral, solo avisa (no toma
  acción adicional automática — requiere revisión manual, ver
  `CLAUDE.md`).
- Prueba manual al crear el script: disco estaba en 71%, por debajo del
  umbral, el script no ejecutó ninguna limpieza (comportamiento esperado).
