# Automatización - Scripts de Monitoreo

**Fecha de implementación:** 2026-09-27  
**Estado:** ✅ Activa (3 scripts en cron)

## 📋 Resumen

He implementado 3 scripts automatizados que me permiten cumplir mi objetivo de forma proactiva:

- ✅ **Detectar** cambios (nuevas versiones, errores)
- ✅ **Avisar** (registrar en logs, crear alertas)
- ❌ **Actualizar** automáticamente (NUNCA - requiere confirmación de Josué)

## 🔧 Scripts Instalados

### 1. health_check_daily.sh
```
Ejecuta:    Cada día a las 06:00 UTC
Responsabilidad: Chequeo de salud diario
Log: /opt/server_admin/aplicaciones/logs/health_check_daily.log
```

**Verifica:**
- Estado de contenedores (Traefik, Metabase, NocoDB, Evolution)
- Errores en logs (excepto warnings esperados)
- Conectividad de BDs (3x PostgreSQL 15)
- Conectividad de caché (Redis 7)

**Resultado:**
- ✅ Sin errores → Registra OK
- ⚠️ Con errores → Alerta en log (revisar cuando se invoque)

### 2. versions_weekly.sh
```
Ejecuta:    Cada lunes a las 08:00 UTC
Responsabilidad: Revisión de versiones disponibles
Log: /opt/server_admin/aplicaciones/logs/versions_weekly.log
```

**Verifica:**
- Traefik (traefik:latest)
- Metabase (metabase/metabase:latest)
- NocoDB (nocodb/nocodb:latest)
- Evolution API (evoapicloud/evolution-api:latest)
- PostgreSQL 15 (postgres:15)
- Redis 7 (redis:7-alpine)

**Resultado:**
- ✅ Actualizado → Registra OK
- ⚠️ Actualización disponible → Avisar a Josué + registrar en log

### 3. errors_monitor.sh
```
Ejecuta:    Cada hora (00:00)
Responsabilidad: Monitoreo de errores críticos en tiempo real
Log: /opt/server_admin/aplicaciones/logs/errors_alert.log
Alert files: /opt/server_admin/aplicaciones/logs/ALERT_*.txt
```

**Verifica:**
- Metabase: > 5 errores en 60 min → CRÍTICO
- NocoDB: > 5 errores en 60 min → CRÍTICO
- Evolution: > 5 errores en 60 min → CRÍTICO
- Traefik: > 5 errores en 60 min → CRÍTICO

(Ignora warnings esperados de Anthropic API en Metabase)

**Resultado:**
- ✅ Sin errores críticos → Registra OK
- 🚨 Errores críticos → Crea archivo ALERT_*.txt + registra en log

## 📅 Cronograma

```bash
# Instalado en crontab de usuario josue:

0 6 * * * /opt/server_admin/aplicaciones/health_check_daily.sh
0 8 * * 1 /opt/server_admin/aplicaciones/versions_weekly.sh
0 * * * * /opt/server_admin/aplicaciones/errors_monitor.sh
```

## 📂 Estructura de Logs

```
/opt/server_admin/aplicaciones/logs/
├── health_check_daily.log      (30 días de histórico)
├── versions_weekly.log         (12 semanas de histórico)
├── errors_alert.log            (7 días de histórico)
└── ALERT_20260926_205737.txt   (alertas críticas generadas)
```

## 🔄 Protocolo de Revisión

Cuando sea invocado como agente, debo:

1. **Revisar logs** antes de actuar
   ```bash
   tail -50 /opt/server_admin/aplicaciones/logs/*.log
   ls /opt/server_admin/aplicaciones/logs/ALERT_*.txt 2>/dev/null
   ```

2. **Identificar cambios** desde mi última invocación
   - ¿Nuevas versiones disponibles? → Avisar
   - ¿Errores críticos? → Investigar
   - ¿BD desconectada? → Escalar

3. **Actuar según** lo encontrado
   - Detectar + avisar: Automático (los scripts ya lo hacen)
   - Actualizar: Manual (requiere confirmación de Josué)
   - Errores críticos: Escalar a agentes responsables

## ⚙️ Mantenimiento

### Ver logs más recientes
```bash
# Últimas 30 líneas de health check
tail -30 /opt/server_admin/aplicaciones/logs/health_check_daily.log

# Últimas 20 líneas de versiones
tail -20 /opt/server_admin/aplicaciones/logs/versions_weekly.log

# Verificar si hay alertas críticas
ls /opt/server_admin/aplicaciones/logs/ALERT_*.txt 2>/dev/null | head -5
```

### Modificar cronograma
```bash
# Editar crontab
crontab -e

# Buscar sección de Aplicaciones Monitoring y ajustar tiempos si es necesario
```

### Rotar logs manualmente
```bash
# Los scripts rotan automáticamente:
# - health_check_daily.log: últimos 30 días
# - versions_weekly.log: últimas 12 semanas
# - errors_alert.log: últimos 7 días
```

## 📊 Estado Actual

✅ **Todos los scripts funcionando correctamente**

- health_check_daily.sh: Último run 2026-09-26 20:55
- versions_weekly.sh: Último run 2026-09-26 20:56
- errors_monitor.sh: Último run 2026-09-26 20:57

---

**Documentado en:** CLAUDE.md - Sección "Automatización propia"  
**Scripts en:** `/opt/server_admin/aplicaciones/*.sh`  
**Logs en:** `/opt/server_admin/aplicaciones/logs/`
