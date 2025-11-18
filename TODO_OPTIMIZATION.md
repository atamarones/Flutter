# 🚀 PLAN DE OPTIMIZACIÓN - URBANGO LOGISTICS
## Nivel: Uber/DoorDash/Rappi

---

## 🎯 OBJETIVO
Transformar la app a estándares profesionales de apps top del mercado con configuración optimizada para Supabase Pro Plan.

---

## 📋 FASE 1: FIXES CRÍTICOS (PRIORIDAD MÁXIMA)

### ✅ 1.1 Base de Datos - Índices
**Archivo:** Supabase SQL Editor
**Tiempo:** 2 minutos
**Impacto:** Crítico - Reduce queries de 2-5s a <100ms

```sql
-- Crear índice único en user_id para queries ultra-rápidas
CREATE UNIQUE INDEX IF NOT EXISTS idx_riders_user_id ON riders(user_id);

-- Verificar índices existentes
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename = 'riders'
ORDER BY indexname;

-- Analizar tabla para optimizar query planner
ANALYZE riders;
```

**Validación:**
```sql
-- Debe retornar en <100ms
EXPLAIN ANALYZE
SELECT * FROM riders WHERE user_id = 'test-uuid';
```

---

### ✅ 1.2 Eliminar Polling - Migrar a Realtime
**Archivo:** `lib/presentation/home/providers/rider_provider.dart`
**Tiempo:** 30 minutos
**Impacto:** Crítico - Elimina 600+ queries/min innecesarias

**Cambios:**

1. Añadir import Supabase Realtime
2. Agregar `RealtimeChannel? _riderChannel;` al notifier
3. Eliminar `Timer? _refreshTimer;`
4. Crear método `_subscribeToRiderChanges()`
5. Modificar `_startServices()` para usar Realtime
6. Actualizar `_stopServices()` para limpiar canal

---

### ✅ 1.3 Fix Race Condition Auth → Rider
**Archivos:**
- `lib/presentation/auth/screens/splash_screen.dart`
- `lib/routing/app_router.dart`

**Tiempo:** 20 minutos
**Impacto:** Crítico - Elimina el error "No se encontró rider"

**Problema actual:**
```
Login → authState cambia → Router redirige a /home → riderProvider.build()
→ getCurrentUser() retorna null (auth aún propagándose) → ERROR
```

**Solución:**
- Usar Stream de authStateChanges en lugar de check síncrono
- Esperar confirmación de session antes de navegar
- Añadir retry logic con exponential backoff

---

### ✅ 1.4 Configuración de Intervalos Profesional
**Archivo:** `lib/core/constants/app_constants.dart`
**Tiempo:** 10 minutos
**Impacto:** Alto - Optimiza uso de recursos

```dart
class RealtimeConfig {
  // Supabase Pro Plan: 500 conexiones, 5M mensajes/mes
  static const maxConcurrentRiders = 200;

  // Location & Heartbeat (HTTP/Edge Functions)
  static const locationUpdateInterval = Duration(seconds: 30);
  static const heartbeatInterval = Duration(seconds: 30);

  // Realtime subscriptions (WebSocket push)
  static const enableRiderRealtimeSubscription = true;
  static const enableOrderRealtimeSubscription = true;

  // Retry & resilience
  static const connectionRetryDelay = Duration(seconds: 5);
  static const maxReconnectAttempts = 3;
  static const sessionRefreshBuffer = Duration(minutes: 5);
}
```

---

## 📋 FASE 2: MEJORAS DE ARQUITECTURA

### ⏳ 2.1 Implementar Optimistic UI
**Archivos:** Providers de orders y rider
**Tiempo:** 1 hora
**Impacto:** Medio - Mejora UX percibida

---

### ⏳ 2.2 Connection Pooling & Retry Logic
**Archivos:** Repository layer
**Tiempo:** 1 hora
**Impacto:** Medio - Mejora resiliencia

---

### ⏳ 2.3 Monitoring Dashboard
**Archivo:** Supabase Dashboard + nuevo screen
**Tiempo:** 2 horas
**Impacto:** Alto - Visibilidad de métricas

**Métricas a trackear:**
- Riders online en tiempo real
- Conexiones Realtime activas
- Mensajes Realtime consumidos
- Latencia promedio de queries
- Errores de autenticación

```sql
-- Vista para monitoring
CREATE OR REPLACE VIEW rider_metrics AS
SELECT
  COUNT(*) FILTER (WHERE status = 'online') as riders_online,
  COUNT(*) FILTER (WHERE last_heartbeat > NOW() - INTERVAL '2 minutes') as riders_active,
  AVG(EXTRACT(EPOCH FROM (NOW() - last_heartbeat))) as avg_heartbeat_age_seconds
FROM riders;
```

---

## 📋 FASE 3: OPTIMIZACIONES AVANZADAS

### ⏳ 3.1 Implement Redis para Location Cache
**Impacto:** Alto para 500+ riders
**Costo:** +$10-20/mes
**Cuándo:** Cuando llegues a 150+ riders simultáneos

---

### ⏳ 3.2 CDN para Assets Estáticos
**Impacto:** Medio - Mejora tiempos de carga inicial
**Cuándo:** Cuando bandwidth > 100 GB/mes

---

### ⏳ 3.3 Implementar Geohashing (S2 Library)
**Impacto:** Alto - Matching rider-order más eficiente
**Cuándo:** Cuando tengas 1000+ órdenes/día

---

## 📊 CAPACIDAD DEL SISTEMA

### Supabase Pro Plan Limits
| Recurso | Límite | Consumo Actual | Proyección 200 Riders | Estado |
|---------|--------|----------------|----------------------|--------|
| Conexiones Realtime | 500 | ? | 400 (80%) | ⚠️ Monitor |
| Mensajes/mes | 5M | ? | 540K (10.8%) | ✅ OK |
| Bandwidth | 250 GB | ? | 17 GB (6.8%) | ✅ OK |
| Database | 8 GB | ? | <1 GB | ✅ OK |

### Capacidad de Riders
- **Máximo teórico:** 250 riders simultáneos
- **Recomendado:** 200 riders (con 20% headroom)
- **Alerta 80%:** 160 riders
- **Alerta crítica 90%:** 180 riders

---

## 🔥 PRIORIDAD INMEDIATA (HOY)

**ELIMINAR BUG AUTH-RIDER:**

1. ✅ Crear índice `idx_riders_user_id` en Supabase
2. ✅ Migrar de polling a Realtime en rider_provider
3. ✅ Fix race condition en splash/auth flow
4. ✅ Manejo de refresh token errors
5. ⏳ Testing con múltiples usuarios
6. ⏳ Verificar latencia <300ms

## ✅ AUTO-RECOVERY DE TOKENS (IMPLEMENTADO)

**Feature profesional:** La app detecta y limpia automáticamente tokens corruptos/expirados.

**Cómo funciona:**
1. Al iniciar la app → Verifica si hay sesión expirada
2. Si detecta token corrupto → Limpia automáticamente
3. Si falla refresh durante uso → Logout automático + limpieza
4. Usuario ve pantalla de login limpia (sin errores)

**Comportamiento esperado:**
- ✅ Primera vez: Puede ver logs de limpieza (normal)
- ✅ Después: Pantalla de login limpia
- ✅ Zero intervención manual del usuario
- ✅ Como Uber/DoorDash/Rappi

**Logs normales durante auto-recovery:**
```
⚠️ [SUPABASE] Token corrupto detectado - Auto-limpiando sesión
ℹ️ [SUPABASE] Ejecutando limpieza forzada de sesión...
✅ [SUPABASE] Sesión limpiada completamente - Estado fresco
```

**NO requiere acción del usuario** - Todo automático.

**Resultado esperado:**
- Primera carga: <300ms (actualmente: 2-5s)
- Sincronización: instantánea (actualmente: 10s delay)
- Zero errores de "No se encontró rider"

---

## ✅ VALIDACIÓN

### Tests manuales post-implementación:
- [ ] Login → Home sin errores
- [ ] Rider data carga en <300ms
- [ ] Cambio de status refleja instantáneo
- [ ] Reconexión después de pérdida de red
- [ ] 10 riders simultáneos sin lag
- [ ] Logout → Login con usuario diferente sin cross-contamination

### Queries de validación:
```sql
-- Verificar índice
\d riders

-- Performance de query
EXPLAIN ANALYZE SELECT * FROM riders WHERE user_id = 'uuid';

-- Riders activos
SELECT COUNT(*) FROM riders
WHERE status = 'online'
AND last_heartbeat > NOW() - INTERVAL '2 minutes';
```

---

## 📝 NOTAS

- **Backup antes de cambios:** git commit antes de cada fase
- **Testing:** Probar con 5-10 usuarios reales antes de producción
- **Monitoring:** Configurar alertas en Supabase dashboard
- **Documentación:** Actualizar README con nueva arquitectura

---

**Última actualización:** 2025-11-17
**Versión:** 1.0
**Estado:** En implementación - Fase 1
