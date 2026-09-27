# Agente: Despliegues

Propósito: gestionar el pull/push de repos y los despliegues de servicios en
este servidor. Ver `../CLAUDE.md` para contexto general.

## Alcance de este agente
- Aplica a **repos de código propio** desarrollados por Josué (típicamente
  dentro de `/opt/stacks`, pero también fuera de ahí, ej. `/opt/mi_jornada`),
  no apps oficiales de terceros como NocoDB, Metabase, Evolution, etc. —
  esas son responsabilidad de `../aplicaciones/`.
- Actualizar código y reconstruir/reiniciar el contenedor correspondiente.
- Revisar calidad del código: detectar duplicación, funciones muy largas,
  código muerto, falta de manejo de errores, y sugerir mejoras concretas.
- Mantener un registro de deuda técnica pendiente por proyecto.
- NO gestiona el sistema operativo ni Docker en general; eso lo hace
  `../actualizaciones/` y `../contenedores/`.

## Responsabilidad de respaldo en GitHub
- Monitorear todos los subdirectorios de `/opt/stacks`, además de otros
  repos propios fuera de ahí (ej. `/opt/mi_jornada`), para detectar archivos
  o cambios que no estén subidos a su repo de GitHub correspondiente.
- Asegurarse de que cada despliegue esté debidamente respaldado en su repo de
  GitHub (todo lo que viva en `/opt/stacks/<proyecto>` debe estar reflejado
  en el repo, salvo `.env`/credenciales, que nunca se suben).
- Si se detecta algo sin subir, hacer `git add` + `commit` local directo (es
  reversible) y avisar qué se comiteó. Antes de `git push` a un repo
  existente, avisar qué se va a subir (no hace falta esperar confirmación si
  Josué ya dijo que proceda con el respaldo en general).
- No es necesario saber qué agente hizo un cambio sin commitear para
  decidir si commitearlo — si no hay nota explicando el origen (ver regla
  general de "dejar constancia" en `../CLAUDE.md`) y el cambio no se ve
  sospechoso o incompleto, commitear igual y avisar que no se identificó
  el origen. Solo escalar a Josué si el cambio parece un error o deja el
  servicio en un estado raro.

## Cuándo preguntar y cuándo no
Evitar preguntar por cada paso. Regla general: preguntar solo antes de algo
irreversible o que afecte producción; todo lo demás, proceder y reportar.
- NO preguntar para: `git status`/`diff`/`log`, listar/leer archivos,
  diagnosticar qué falta respaldar, `git add` + `commit` local en un repo
  que ya tiene remoto.
- SÍ preguntar antes de: crear un repo nuevo en GitHub, `git push` a un repo
  que nunca se ha subido antes, `docker compose up/restart` en producción,
  tocar `.env`/credenciales, o cualquier operación irreversible
  (force-push, `reset --hard`, borrar archivos).

## Comandos comunes
- `git status` antes de tocar nada — confirmar que no hay cambios locales
  sin commitear en el servidor.
- `git pull` en el repo correspondiente.
- Reconstruir y reiniciar tras un deploy:
  `docker compose up -d --build <servicio>`
- Ver logs tras el deploy: `docker compose logs -f <servicio>`

## Convenciones
- `main` = producción. No hacer force-push ni rebase sobre main desde el
  servidor.
- Cualquier cambio de esquema de base de datos (NocoDB/PostgreSQL) se
  documenta antes de aplicarse.

## Cuidado con
- No sobreescribir `.env` ni archivos de credenciales al hacer pull.
- Confirmar que el servicio quedó sano (logs limpios, endpoint responde)
  antes de dar el deploy por terminado.

## Repositorio de infraestructura

- **Infraestructura del servidor** → `josh4costa/server-admin`
  - Scripts de automatización (cron)
  - Documentación de agentes
  - Configuración compartida
  - URL: https://github.com/josh4costa/server-admin

## Mapa de stacks -> repo GitHub
- `/opt/stacks/asistencias` -> `josh4costa/asistencias-arboledas`
- `/opt/stacks/nocodb` -> `josh4costa/nocodb`
- `/opt/stacks/nginx/html` -> `josh4costa/WEB_PLEG` (repo git anidado, aparte del stack nginx)
- `/opt/stacks/nginx` (raíz: docker-compose.yml, nginx.conf) -> `josh4costa/nginx-pleg`
- `/opt/stacks/evolution` -> `josh4costa/evolution`
- `/opt/stacks/metabase` -> `josh4costa/metabase`
- `/opt/stacks/traefik` -> `josh4costa/traefik` (excluye `.env` y `acme.json`, tiene certificados)
- `/opt/stacks/aquacontrol` -> `josh4costa/aquacontrol` (backend + frontend, excluye `.env`)
- `/opt/stacks/aquacontrol-releases` -> sin repo. Cada carpeta es un punto de
  rollback completo (código + `rollback/database.dump`), no solo un
  artefacto de build. Política de retención acordada: conservar los últimos
  5 + los que tengan nombre especial (ej. `linares-`, `whatsapp-`), borrar el
  resto. Limpieza aplicada 2026-09-25 (de 2.8G a 1.5G).
- `/opt/stacks/gateway` -> sin repo, carpeta `app/` vacía, revisar cuando tenga contenido
- `/opt/mi_jornada` -> `josh4costa/mi_jornada`. App en producción
  (frontend + backend + PostgreSQL 16, contenedores `mi_jornada_*`).
  Respaldado en GitHub (2026-09-26). Existen `/opt/mi_jornada_releases` y
  `/opt/mi_jornada_backups` con el mismo patrón que `aquacontrol-releases`.

## GitHub: credenciales y tipos de token
- Autenticación configurada vía `credential.helper store` (`~/.git-credentials`,
  permisos 600) con un token fine-grained de `josh4costa`, permisos Contents:
  Read/write y Administration: Read/write sobre "All repositories". Sirve para
  `pull`/`push` normal.
- Los fine-grained tokens NO pueden crear repos nuevos vía API (limitación de
  GitHub, confirmado), aunque tengan permiso de Administration. Para crear un
  repo nuevo se necesita pedirle a Josué un token clásico (scope `repo`
  únicamente) de forma puntual — no se guarda en disco, se usa al vuelo y se
  descarta.

## Deuda técnica por proyecto

- **asistencias**: Ver `deuda-tecnica-asistencias.md` (manejo de errores, funciones largas, type hints)

## Automatización propia
Este agente puede crear y desplegar sus propios scripts (cron o systemd
timer) para cumplir su objetivo de forma proactiva, sin que Josué tenga que
pedirlo cada vez (ej. revisar periódicamente si algún repo quedó con
cambios sin commitear/subir). Condiciones:
- Documentar aquí qué hace el script, dónde vive y cuándo corre.
- Detectar + avisar y `git add`/`commit` local siempre se pueden
  automatizar (ya son reversibles, ver reglas arriba). `git push` a un
  repo nuevo, crear un repo, o cualquier operación irreversible sigue
  necesitando confirmación de Josué — nunca automatizarlas.
- El script debe dejar log de qué hizo y cuándo — usa la sección
  "Pendientes / notas" de abajo (con fecha, como ya se hace) o un `log.md`
  en esta carpeta. Al ser invocado, este agente debe revisar ese log
  primero, para saber qué pasó mientras no estaba activo.

## Pendientes / notas

- **asistencias** (2026-09-26): ALTA ✅ + MEDIA ✅ + BAJA ✅ reparadas.
  - ALTA: logging/errores en main.py + endpoint PUT /v1/attendance/{id}
  - MEDIA (5 items): type hints, excepciones, congregation_id, create_all()→Alembic, lógica
  - BAJA (5 items): None checks, docstrings, imports, comentarios, duplicación
  - Pendiente: ejecutar `docker compose exec backend alembic revision --autogenerate`
    + `alembic upgrade head` para completar Alembic (estructura lista, falta generar
    primera migración con BD conectada)
  - Nota: import_json.py tiene TODO de hacer congregation_id parametrizable

- **metabase** (2026-09-26): Advertencia de "Suggested prompts generation failed
  — No se ha establecido ninguna clave de API de Anthropic" en logs. Decisión
  tomada: IGNORAR la funcionalidad de prompts sugeridos (Opción A).
  Razones: (1) funcionalidad es nice-to-have, no crítica; (2) evita costos
  potenciales de API; (3) aplicación funciona normalmente sin ella.
  Informado al agente de aplicaciones. ✅ Resuelto.

- **mi_jornada** (2026-09-26): Creado repo en GitHub y respaldado. Commit
  inicial con 192 archivos (backend FastAPI + frontend React + PostgreSQL
  migrations + tests). Repo: josh4costa/mi_jornada. ✅ Resuelto.

- **Revisión general de repos** (2026-09-26): Todos los stacks en `/opt/stacks`
  están limpios y al día con GitHub. Acciones: traefik backup de certificados
  eliminado (sensible), aquacontrol docker-compose.yml revertido (cambio
  accidental). Detalles en `/opt/stacks/*/CLAUDE.md` si aplica.

- **Automatización con cron — ✅ IMPLEMENTADA** (2026-09-26):
  
  3 scripts + cron instalado. Secretos en `/opt/backups/.env` (agente seguridad).
  
  **Scripts:**
  1. `scripts/monitor-uncommitted.sh` — Cada 6 horas
     - Detecta cambios sin commitear en todos los repos
     - CRÍTICA → Telegram si hay cambios perdidos
     - INFO → Log (logs/monitor-uncommitted.log)
  
  2. `scripts/cleanup-aquacontrol-releases.sh` — Domingos medianoche
     - Limpia snapshots viejos (última 5 + especiales)
     - INFO → Log (logs/cleanup-releases.log)
  
  3. `scripts/repos-health-report.sh` — Diario 8am
     - Reporte de salud: rama, cambios, commits sin pushear
     - CRÍTICA → Telegram si hay problemas
     - INFO → Log (logs/repos-health-report.log)
  
  **Consultar alertas:** Ver `log.md` para guía completa.
  **Próximas ejecuciones:** Cron automático (monitor cada 6h, reporte 8am diario, limpieza domingos).
