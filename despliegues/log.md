# Log de Automatización — Despliegues

## Sistema de alertas por Telegram + cron

**Fecha de instalación:** 2026-09-26  
**Secretos:** `/opt/backups/.env` (gestionado por agente seguridad)

## Scripts instalados

### 1. monitor-uncommitted.sh
```
Cron: cada 6 horas (*/6)
Qué hace: Detecta cambios sin commitear en todos los repos
Alertas:
  - CRÍTICA → Telegram (cambios sin stagear)
  - WARNING → Log (commits sin pushear)
  - INFO → Log (todo al día)
Log: logs/monitor-uncommitted.log
```

### 2. cleanup-aquacontrol-releases.sh
```
Cron: semanal (domingos a medianoche)
Qué hace: Limpia snapshots viejos según política de retención
Política: últimos 5 + especiales (linares-, whatsapp-, etc.)
Alertas:
  - CRÍTICA → Telegram (si el directorio no existe)
  - INFO → Log (qué se borró, espacio liberado)
Log: logs/cleanup-releases.log
```

### 3. repos-health-report.sh
```
Cron: diario (8am)
Qué hace: Reporte general de salud de todos los repos
Incluye: rama actual, cambios sin stagear, commits sin pushear
Alertas:
  - CRÍTICA → Telegram (si hay problemas detectados)
  - INFO → Log (tabla formateada)
Log: logs/repos-health-report.log
```

## Cómo revisar alertas

```bash
# Ver último reporte de salud
tail -50 /opt/server_admin/despliegues/logs/repos-health-report.log

# Ver alertas de monitoreo
tail -20 /opt/server_admin/despliegues/logs/monitor-uncommitted.log

# Ver limpieza de snapshots
tail -20 /opt/server_admin/despliegues/logs/cleanup-releases.log

# Ver alertas críticas en tiempo real
tail -f /opt/server_admin/despliegues/logs/*.log | grep CRÍTICA
```

## Secuencia de ejecución

```
Cada 6 horas:  monitor-uncommitted.sh
Cada día 8am:  repos-health-report.sh
Cada domingo:  cleanup-aquacontrol-releases.sh
```

## Historial de ejecuciones

| Fecha | Script | Resultado | Notas |
|-------|--------|-----------|-------|
| 2026-09-26 21:32 | monitor-uncommitted | ✅ Todos al día | Test inicial |
| 2026-09-26 21:32 | repos-health-report | ✅ 8 repos limpios | Test inicial |

## Resolución de problemas

Si un script falla:
1. Revisar permisos: `ls -l /opt/server_admin/despliegues/scripts/`
2. Revisar log correspondiente: `tail -50 logs/<script>.log`
3. Verificar que `/opt/backups/.env` existe con permisos 600
4. Ejecutar manualmente para ver errores:
   ```bash
   /opt/server_admin/despliegues/scripts/monitor-uncommitted.sh
   ```

