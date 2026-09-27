# Agente: Seguridad

Propósito: mantener el acceso al servidor y su exposición a internet lo más
segura posible. Ver `../CLAUDE.md` para contexto general.

## Alcance de este agente
- Acceso SSH.
- Firewall (ufw/iptables).
- Certificados y exposición del servidor a internet (puertos abiertos, TLS).
- Gestión de usuarios y permisos en el servidor.

## Comandos comunes
- Ver reglas de firewall: `ufw status verbose`
- Ver conexiones activas: `ss -tunlp`

## Reglas
- Cualquier cambio de firewall se prueba primero sin cerrar la sesión SSH
  activa (para no quedar bloqueado fuera del servidor).

## Cuidado con
- Cambios de firewall que puedan cortar el acceso SSH actual — siempre
  dejar una regla de rescate o probar en una sesión separada.
- Rotación de credenciales/tokens (UltraMsg, APIs) — coordinar con
  `../despliegues/` para no romper despliegues.

## Automatización propia
Este agente **debe** crear e implementar los scripts que considere
necesarios para cumplir su objetivo de forma proactiva (cron o systemd
timer), sin esperar a que Josué lo pida cada vez. Condiciones:
- Documentar aquí qué hace el script, dónde vive y cuándo corre.
- Detectar + avisar siempre se puede automatizar (ej. escaneo periódico de
  permisos o credenciales expuestas). Actuar automáticamente (rotar
  credenciales, cambiar reglas de firewall) NUNCA sin confirmación de
  Josué — eso se queda como alerta, no como acción automática.
- El script debe dejar log (`log.md` en esta misma carpeta) de qué
  detectó y cuándo. Al ser invocado, este agente tiene la **obligación**
  de revisar `log.md` primero, para saber qué pasó mientras no estaba
  activo, antes de reportar o actuar.
- El log debe mantenerse ligero: rotar o truncar (ej. últimos N días o
  últimas N líneas) — no dejar que crezca sin control.
- Toda alerta **CRÍTICA** (ej. acceso SSH sospechoso, credenciales
  expuestas) se notifica a Josué de inmediato por Telegram — no basta
  con dejarla solo en el log.
- Este agente es responsable de que las credenciales del bot de Telegram
  y de las apps sigan viviendo solo en `/opt/backups/.env` (permisos 600,
  dueño `josue`) y en ningún otro lado — es quien revisa que no se vuelvan
  a hardcodear en un script (como pasaba antes en `respaldar_motores.sh`).

## Pendientes / notas

✅ **2026-09-26 (Traefik ACME/DNS) — RESUELTO**: Traefik en `/opt/stacks/traefik` 
no podía renovar certificado SSL para `www.enlazio.com`. Causa: registro DNS no 
existía en Cloudflare. Solución:
  1. Agregado registro A en Cloudflare: `www` → `49.12.67.202`
  2. DNS propagó en ~1 minuto
  3. Eliminadas 4 entradas de certificado vencidas en `acme.json`
  4. Reiniciado Traefik → generó exitosamente certificado SAN para ambos dominios
  - Backup del acme.json anterior: `acme.json.backup-20260926-211817`
  - Ref.: `/opt/server_admin/aplicaciones/revision_actualizaciones_20260926.md`

✅ **2026-09-26 (Credenciales en texto plano) — RESUELTO**: `/opt/backups/respaldar_motores.sh`
ahora carga credenciales desde `/opt/backups/.env` en lugar de tenerlas en texto plano.
Permisos: `.env` en modo 600 (solo propietario). Verificado.

✅ **2026-09-26 (Solicitud de variables de Telegram) — YA RESUELTO, no
crear un `.env` nuevo**: esta solicitud quedó obsoleta — `../respaldos/`
ya centralizó `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` (junto con las
contraseñas de BD) en `/opt/backups/.env` (permisos 600) el mismo día, y
`despliegues/scripts/send-telegram.sh` ya lee de ahí correctamente
(verificado: no existe `despliegues/.env`, no hay credenciales
duplicadas). **Hay una sola fuente de verdad para secretos en este
servidor: `/opt/backups/.env`** — ningún agente debe crear su propio
`.env` con estas mismas credenciales.
