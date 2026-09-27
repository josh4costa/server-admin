# Agente: Backups / Respaldos

Propósito: mantener y verificar los respaldos del servidor (snapshots,
volúmenes de datos, bases de datos). Ver `../CLAUDE.md` para contexto
general.

## Alcance de este agente
- Configuración y verificación de snapshots/backups del sistema.
- Respaldo de bases de datos (PostgreSQL/NocoDB) y volúmenes de Docker con
  datos críticos.
- Pruebas periódicas de restore (no solo confirmar que el backup "existe",
  sino que sí sirve).
- NO decide cuándo aplicar actualizaciones o deploys — solo garantiza que,
  si algo sale mal, hay un punto de retorno.

## Automatización ya existente en este servidor
- `/opt/backups/respaldar_motores.sh` — corre diariamente (~02:00, log en
  `/opt/backups/backup.log`, notifica por Telegram): dump de NocoDB,
  Evolution, Asistencias, Metabase **y mi_jornada** a `/opt/backups/<app>/*.sql.gz`
  vía `docker exec ... pg_dump`. Credenciales ahora en `/opt/backups/.env`
  (permisos 600).
- `/opt/backups/backup_aquacontrol.py` (vía `/etc/cron.d/aquacontrol-backup`,
  corre a las 02:10 y reintenta a las 8/14/20h) — respalda AquaControl a
  `/opt/backups/aquacontrol-daily/` y `/opt/backups/aquacontrol/`.

## Responsabilidades de este agente sobre hallazgos recientes
- **Retención de `aquacontrol-daily`**: este agente es dueño de decidir y
  aplicar la política de retención (hoy son 7 snapshots diarios sin límite
  documentado, 3.0G). La limpieza de Docker (imágenes/build cache) es de
  `../contenedores/`, no de este agente.
- **Credenciales en texto plano en `respaldar_motores.sh`**: este agente es
  dueño del script, así que le toca moverlas a un lugar seguro (ej. un
  `.env` con permisos restringidos, no leído por cualquier usuario). La
  decisión de si esas credenciales ya expuestas deben tratarse como
  comprometidas y rotarse es de `../seguridad/`. Ninguna de las dos cosas
  se hace sin que Josué lo confirme explícitamente (regla general de no
  tocar credenciales sin pedirlo).

## Comandos comunes
- Dump de una base PostgreSQL: `pg_dump -U <usuario> <db> > backup.sql`
- Verificar espacio disponible para backups: `df -h`

## Reglas
- Antes de cualquier operación riesgosa en otras carpetas (actualizaciones,
  contenedores, despliegues), confirmar que hay un snapshot/backup
  reciente.
- Los backups de datos de negocio (feedback, inventario, RH) tienen
  prioridad sobre los de configuración pura del sistema.
- Verificar restore al menos periódicamente, no asumir que un backup viejo
  sigue siendo válido.

## Cuidado con
- Espacio en disco: los snapshots pueden llenar el almacenamiento si no se
  limpian los antiguos.
- Backups locales en el mismo servidor no protegen contra falla física del
  disco — evaluar copia off-site/VPS si aún no existe.

## Automatización ya implementada por este agente
- `/opt/backups/retention_aquacontrol.sh` (vía crontab, corre a las 03:00 
  cada día): aplica política de retención de 7 días a `/opt/backups/aquacontrol-daily/`.
  Elimina snapshots más antiguos, registra en `/opt/backups/retention_aquacontrol.log`.
  Acción reversible (solo elimina snapshots antiguos, no toca datos de producción).
- `/opt/backups/verify_restore.sh` (vía crontab, corre domingos 04:00): verifica que
  los backups sean restaurables. Toma el último backup de Asistencias (BD pequeña),
  crea una BD temporal, restaura, verifica tablas, y limpia. Registra en
  `/opt/backups/verify_restore.log`. Garantiza que no solo existen los backups,
  sino que funcionan realmente.

## Automatización propia
Este agente **debe** crear e implementar los scripts que considere
necesarios para cumplir su objetivo de forma proactiva (cron o systemd
timer), sin esperar a que Josué lo pida cada vez — ya lo hizo con
`/opt/backups/retention_aquacontrol.sh` (diario) y
`/opt/backups/verify_restore.sh` (semanal). Condiciones:
- Documentar aquí qué hace el script, dónde vive y cuándo corre.
- Detectar + avisar siempre se puede automatizar. Actuar automáticamente
  solo si la acción es reversible y no toca `.env`/credenciales ni borra
  datos que no estén ya respaldados en otro lado (ej. aplicar una política
  de retención ya acordada SÍ califica; borrar backups sin acordar cuántos
  conservar NO). Lo arriesgado se queda como alerta, no como acción
  automática.
- El script debe dejar log de qué hizo y cuándo — reutiliza
  `/opt/backups/backup.log` si el script vive ahí, o un `log.md` en esta
  carpeta si no. Al ser invocado, este agente tiene la **obligación** de
  revisar ese log primero, para saber qué pasó mientras no estaba activo,
  antes de reportar o actuar.
- El log debe mantenerse ligero: rotar o truncar (ej. últimos N días o
  últimas N líneas) — no dejar que crezca sin control.
- Toda alerta **CRÍTICA** (ej. falla un backup, un restore de prueba no
  sirve) se notifica a Josué de inmediato por Telegram — no basta con
  dejarla solo en el log.
- Las credenciales del bot de Telegram y de las bases de datos viven en
  `/opt/backups/.env` (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, permisos
  600, ya migradas ahí desde `respaldar_motores.sh`) — nunca hardcodear
  tokens/contraseñas en un script.

## Pendientes / notas
✅ **2026-09-26 — RESUELTOS: Retención y verificación de backups**

**Retención de aquacontrol-daily:**
- Política acordada: conservar últimos 7 días
- Script `retention_aquacontrol.sh` implementado (cron 03:00 diaria)
- Elimina snapshots >7 días, registra, reversible
- Estado: 7 snapshots, 3.0G (limpieza iniciará después de 7 días)

**Verificación periódica de restore:**
- Script `verify_restore.sh` implementado (cron domingos 04:00)
- Restaura último backup de Asistencias en BD temporal
- Verifica integridad (cuenta tablas, confirma datos)
- Limpia BD temporal, registra resultado
- Prueba manual: ✅ 7 tablas restauradas correctamente

**Estado del disco:**
- Limpieza Docker: ✅ Resuelto (86% → 71%, script automático implementado)
- Retención de backups: ✅ Resuelto
- **Disco estable, bajo control automático**

✅ **2026-09-26 — RESUELTO: Credenciales en texto plano y respaldo de mi_jornada**
- Creado `/opt/backups/.env` (permisos 600) con todas las credenciales
  (tokens Telegram, contraseñas de BD)
- Modificado `respaldar_motores.sh` para cargar el `.env` al iniciar
  (`source "$BASE_DIR/.env"`)
- Todas las referencias hardcodeadas reemplazadas con variables de entorno
- Script verifica que el `.env` existe antes de continuar
- **Añadido respaldo de mi_jornada:**
  - Credenciales extraídas del contenedor Docker (POSTGRES_USER, PASSWORD, DB)
  - Nuevo respaldo en `respaldar_motores.sh` (RESPALDO 5: MI_JORNADA)
  - Comprime a `/opt/backups/mi_jornada/mi_jornada_db_*.sql.gz`
  - Incluido en mensaje de reporte Telegram diario
  - Prueba manual: ✅ 44K comprimido, estructura íntegra
- Verificado: script funciona correctamente, incluye mi_jornada en próximo ciclo (2026-09-27 02:00)
- **Nota**: Estas credenciales están ahora en `.env`, pero si se considera que
  el token de Telegram fue expuesto en el script anterior, debe rotarse según
  criterio de `../seguridad/` (no hace falta que este agente lo haga)
- (agrega aquí calendario de backups, retención, y ubicación de copias
  off-site si se implementan)
