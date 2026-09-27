# Servidor — Contexto compartido
HÁBLAME SIEMPRE EN ESPAÑOL
Este archivo es la referencia corta y compartida para TODOS los agentes que
trabajan en subcarpetas de /opt/server_admin. Cada subcarpeta tiene su propio
CLAUDE.md acotado a una tarea; si necesitan contexto general del servidor,
lo referencian aquí en vez de repetirlo.

## Qué es este servidor
- Servidor VPS Linux usado como infraestructura para los proyectos
  de Josué.
- Corre servicios en Docker.
- Acceso remoto por SSH.

## Reglas generales para cualquier agente en este servidor
- Comunicarse siempre con Josué en español, en todas las respuestas.
- No reiniciar servicios ni actualizar paquetes en horario de operación de
  las sucursales sin confirmar antes.
- No tocar `.env` ni credenciales sin que Josué lo pida explícitamente.
- Antes de cualquier cambio riesgoso (actualización, cambio de red, cambio
  de contenedor), confirmar que el respaldo más reciente esté sano.
- Preferir cambios reversibles y documentados sobre atajos rápidos.
- Si algo se sale de tu propia instrucción (un cambio sin explicar, una duda
  sobre quién es responsable de algo), revisa primero los `CLAUDE.md` de las
  demás carpetas (ver mapa abajo) antes de preguntarle a Josué — puede que
  ya esté documentado ahí, o que sea tarea de otro agente y no haga falta
  que lo resuelvas tú.
- Si modificas un archivo que pertenece al dominio de otro agente (ej. tocar
  un docker-compose.yml de un repo propio para diagnosticar algo), deja
  constancia junto al cambio (comentario en el archivo si lo admite, o nota
  en la sección "Pendientes / notas" del `CLAUDE.md` dueño): qué, por qué y
  cuándo. Así el agente dueño no se encuentra un cambio sin explicación.
- Cada agente **debe** crear e implementar los scripts que considere
  necesarios para cumplir su propio objetivo de forma proactiva (cron,
  systemd timer) — no es solo un permiso, se espera que lo haga en vez de
  esperar a que Josué lo pida cada vez. Ver la sección "Automatización
  propia" del `CLAUDE.md` de cada carpeta para las condiciones de qué se
  puede automatizar sin pedir permiso y qué no.
- Cualquier script que un agente despliegue debe dejar log de qué hizo y
  cuándo. Al ser invocado, ese agente tiene la **obligación** de revisar su
  log primero, para saber qué pasó mientras no estaba activo, antes de
  reportar o actuar.
- Los logs deben mantenerse ligeros: rotar o truncar (ej. conservar solo
  los últimos N días o las últimas N líneas) — ningún log debe crecer sin
  control.
- Toda alerta **CRÍTICA** se notifica a Josué de inmediato por Telegram —
  no basta con dejarla solo en el log.
- Las credenciales del bot de Telegram (`TELEGRAM_BOT_TOKEN`,
  `TELEGRAM_CHAT_ID`) y las contraseñas de las bases de datos viven en
  `/opt/backups/.env` (permisos 600, dueño `josue`). Ningún script debe
  hardcodear tokens/contraseñas — siempre leerlos de ahí.

## Checklist para un proyecto/app nuevo
Si cualquier agente se topa con una app o proyecto que no está documentado
en ningún `CLAUDE.md` (ej. una carpeta nueva en `/opt`, un contenedor sin
mapear), no basta con resolver solo tu propia parte — revisa esta lista
completa y anota en el `CLAUDE.md` dueño de cada punto lo que falte, para
que no se repita lo que pasó con `mi_jornada` (semanas en producción sin
repo ni backup, sin que ningún agente lo notara por revisar solo su
dominio):
- ¿Es código propio de Josué o una app oficial de terceros? Clasifícalo
  (ver `despliegues/` vs `aplicaciones/`) y documéntalo ahí.
- ¿Tiene repo en GitHub? Si es código propio y no lo tiene, avisar/anotar
  en `despliegues/CLAUDE.md`.
- Si tiene base de datos, ¿está en la rotación de backups? Si no, avisar/
  anotar en `respaldos/CLAUDE.md`.
- ¿Está en el "Mapa de contenedores" de `contenedores/CLAUDE.md` y en el
  alcance de `monitoreo/CLAUDE.md`? Si no, agregarlo.
- ¿Expone algo a internet? Si sí, avisar/anotar en `seguridad/CLAUDE.md`
  para confirmar que la exposición es intencional.

## Mapa de carpetas / agentes de este servidor
- `despliegues/` — pull/push de repos, build y restart de servicios
- `actualizaciones/` — actualizaciones del sistema operativo y paquetes
- `contenedores/` — gestión de Docker: compose, logs, limpieza de imágenes
- `respaldos/` — respaldos y verificación de restores
- `monitoreo/` — salud del servidor: disco, RAM, uptime, alertas
- `aplicaciones/` — versiones y salud de cada app oficial de terceros
  (NocoDB, Metabase, Evolution, etc.)
- `seguridad/` — SSH, firewall, certificados

Usa solo las carpetas que necesites; no todas tienen que estar activas.
