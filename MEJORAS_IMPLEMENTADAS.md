# Mejoras Implementadas en Urbango Logistics Rider App

## Resumen
Se han implementado 4 mejoras principales para optimizar el tracking de riders y mejorar la experiencia visual de la aplicación.

---

## 1. Keep-Alive / WakeLock Activo

### Descripción
Mantiene el dispositivo activo mientras la app está en uso, evitando que entre en suspensión o se bloquee por inactividad del usuario.

### Implementación
- **Paquete usado**: `wakelock_plus: ^1.2.8`
- **Archivo**: `lib/core/services/location_service.dart`

### Funcionamiento
- El WakeLock se **activa automáticamente** cuando el rider cambia su estado a "online"
- Se **desactiva automáticamente** cuando el rider cambia su estado a "offline" o hace logout
- Previene que el sistema operativo suspenda la app mientras el GPS está activo

### Código clave
```dart
// Al iniciar actualizaciones de ubicación
await WakelockPlus.enable();

// Al detener actualizaciones
await WakelockPlus.disable();
```

---

## 2. Servicio de Ubicación en Segundo Plano

### Descripción
Mantiene activo el servicio de ubicación en segundo plano mientras el rider esté en estado "online" o "delivering", y lo detiene cuando esté "offline" o haga logout.

### Implementación
- **Archivos modificados**:
  - `lib/core/services/background_service.dart`
  - `lib/presentation/home/providers/rider_provider.dart`

### Funcionamiento

#### Foreground (Primer plano)
Cuando el rider está "online":
- **Ubicación**: Se actualiza cada 30 segundos
- **Heartbeat**: Se envía cada 30 segundos
- **Refresh**: Se actualiza el estado cada 10 segundos

#### Background (Segundo plano)
Usa `Workmanager` para ejecutar tareas periódicas:
- **Heartbeat Task**: Cada 15 minutos
- **Location Task**: Cada 15 minutos (solo si rider está "online" o "delivering")

### Control por estado
```dart
// Cuando el rider cambia de estado
await BackgroundService.saveRiderStatus(newStatus);

// En background, se verifica el estado antes de ejecutar
if (riderStatus == 'offline') {
  return true; // Skip task
}
```

### Nuevos métodos agregados
```dart
BackgroundService.startLocationTracking()  // Inicia tracking en background
BackgroundService.stopLocationTracking()   // Detiene tracking en background
BackgroundService.saveRiderStatus(status)  // Guarda estado para control
```

---

## 3. Actualización Continua de Posición en el Mapa

### Descripción
El mapa ahora actualiza la posición del rider en tiempo real cuando cambia su ubicación GPS.

### Implementación
- **Archivo**: `lib/presentation/home/widgets/rider_map_widget.dart`

### Funcionamiento
- Detecta cambios en `rider.currentLat` y `rider.currentLng` usando `didUpdateWidget`
- Actualiza automáticamente la cámara del mapa hacia la nueva posición
- Usa animación suave (`flyTo` con duración de 1500ms)
- Si hay una orden activa, ajusta el zoom para mostrar tanto al rider como el punto de pickup

### Código clave
```dart
@override
void didUpdateWidget(RiderMapWidget oldWidget) {
  super.didUpdateWidget(oldWidget);

  // Detectar cambios en la ubicación
  if (widget.rider.currentLat != oldWidget.rider.currentLat ||
      widget.rider.currentLng != oldWidget.rider.currentLng) {
    _updateRiderPosition();
  }
}
```

---

## 4. Efecto Visual Personalizado para el Rider

### Descripción
Se agregó un marcador animado personalizado con efecto de pulso y rastro (trail) para identificar claramente al rider en el mapa.

### Implementación
- **Archivos nuevos**:
  - `lib/presentation/home/widgets/rider_marker_widget.dart`
  - `assets/icons/rider_marker.svg`

### Características del efecto visual

#### 1. Pulso animado
- Dos anillos concéntricos que pulsan hacia afuera
- Animación continua con `Curves.easeInOut`
- Duración: 2 segundos

#### 2. Círculo principal con gradiente
- Gradiente radial de azul a azul claro
- Sombra con efecto de brillo
- Ícono de bicicleta en el centro

#### 3. Efecto de rastro (trail)
- Anillo rotante alrededor del marcador
- 3 arcos con gradiente de opacidad
- Simula movimiento y dirección

### Colores
- **Color principal**: `#0066FF` (azul)
- **Efecto de pulso**: Opacidad del 10% al 40%
- **Sombra**: 50% de opacidad con desenfoque

### Código clave
```dart
const RiderMarkerWidget(
  size: 100,
  color: Color(0xFF0066FF),
)
```

---

## Mejoras adicionales

### 1. Ubicación inicial inmediata
Ahora cuando el rider se conecta, obtiene su ubicación inmediatamente (antes esperaba 30 segundos).

```dart
// Obtener ubicación inicial inmediatamente
final initialPosition = await getCurrentPosition();
if (initialPosition != null) {
  onLocationUpdate(initialPosition);
}
```

### 2. Tracking continuo incluso cuando la app está en segundo plano
Los servicios de ubicación y heartbeat **continúan funcionando** incluso cuando:
- El rider abre Google Maps/Waze para navegar
- La app se minimiza
- La app está en segundo plano

**IMPORTANTE**: Mientras el rider esté "online", la ubicación se actualiza **SIEMPRE**:
- **Foreground**: Cada 30 segundos (ubicación + heartbeat)
- **Background**: Cada 15 minutos (via WorkManager)
- **WakeLock**: Mantiene el dispositivo activo para evitar suspensión

**Casos de uso reales**:
1. Rider acepta pedido → Abre Google Maps para navegar → Nuestra app sigue actualizando ubicación en background
2. Rider está online → Minimiza la app → La ubicación sigue actualizándose
3. Rider está entregando → Pantalla se apaga → WakeLock mantiene GPS activo

### 3. Manejo inteligente de errores de red
Los errores temporales de conexión (comunes en emuladores) son manejados silenciosamente:
- Si falla una actualización por error de red, mantiene el estado actual
- Solo loguea errores críticos, no errores de DNS temporales
- El tracking continúa funcionando cuando la conexión se restaura

### 4. Logs mejorados
Todos los servicios ahora imprimen logs claros para debugging:
- `WakeLock enabled/disabled`
- `Servicios de background iniciados/detenidos`
- `Background Heartbeat: 200`
- `Background Location Update: 200 - Lat: X, Lng: Y`
- Solo errores críticos (no errores temporales de red)

---

## Permisos necesarios (Android)

Asegúrate de tener estos permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Ubicación en primer plano -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Ubicación en segundo plano (Android 10+) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- WakeLock -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET" />
```

---

## Permisos necesarios (iOS)

Asegúrate de tener estas claves en `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación para mostrarte pedidos cercanos</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación en segundo plano para actualizar tu posición mientras entregas</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Necesitamos tu ubicación en segundo plano para tracking continuo</string>

<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>processing</string>
</array>
```

---

## Flujo completo de tracking

### Rider se conecta (online)
1. Verificar permisos de ubicación
2. Actualizar estado en Supabase → `online`
3. Guardar token y estado en SharedPreferences
4. **Activar WakeLock** ✅ (mantiene pantalla/GPS activo)
5. Obtener ubicación inmediata
6. Iniciar timers foreground (ubicación cada 30s, heartbeat cada 30s, refresh cada 10s)
7. **Iniciar servicios background** (heartbeat + location tracking cada 15 min) ✅
8. Mostrar marcador animado en el mapa ✅

### Durante el tracking (Rider ONLINE)

**App en primer plano (foreground)**:
- Ubicación GPS: cada 30 segundos
- Heartbeat a Supabase: cada 30 segundos
- Refresh de datos: cada 10 segundos
- Mapa se actualiza en tiempo real con animación
- WakeLock activo (pantalla no se apaga)

**App minimizada o en segundo plano**:
- ✅ Timers de foreground **CONTINÚAN ACTIVOS** (ubicación cada 30s)
- ✅ WakeLock **SIGUE ACTIVO** (GPS no se suspende)
- ✅ Background services **ACTIVOS** (backup cada 15 min)
- ⚠️ Posibles errores de red temporales (manejados silenciosamente)

**Casos especiales**:
1. **Rider abre Google Maps**: Nuestra app sigue en background → ubicación sigue actualizándose cada 30s
2. **Pantalla se bloquea**: WakeLock mantiene GPS activo → ubicación sigue actualizándose
3. **Sin conexión temporal**: Mantiene último estado, reintenta cuando vuelve la conexión

### Rider se desconecta (offline)
1. Actualizar estado en Supabase → `offline`
2. Guardar estado en SharedPreferences
3. **Desactivar WakeLock** ✅
4. Cancelar todos los timers foreground
5. **Detener servicios background** ✅
6. GPS se puede suspender
7. Limpiar token

---

## Testing

### Para probar WakeLock
1. Conectar el rider
2. Dejar el teléfono sin tocarlo por 1 minuto
3. Verificar que la pantalla no se apague

### Para probar ubicación en segundo plano
1. Conectar el rider
2. Observar logs: ubicación se actualiza cada 30 segundos
3. Minimizar la app (o abrir otra app como Maps)
4. Los logs **continúan mostrando** actualizaciones cada 30 segundos
5. Esperar 15 minutos para verificar background task: `Background Location Update: 200`
6. Volver a la app: el mapa está actualizado con la última posición

### Para probar actualización del mapa
1. Conectar el rider
2. Caminar o simular cambio de ubicación
3. Observar que el mapa se anima hacia la nueva posición
4. Verificar que el marcador animado pulsa continuamente

---

## Notas importantes

### Batería
- El tracking continuo consume batería
- El usuario debe tener el teléfono cargado o con batería suficiente
- Los intervalos de 30 seg (foreground) y 15 min (background) son un balance entre precisión y consumo

### Limitaciones de Android
- WorkManager tiene una frecuencia mínima de 15 minutos
- Para tracking más frecuente en background, considerar usar Foreground Service

### Limitaciones de iOS
- iOS es más restrictivo con ubicación en background
- Puede suspender la app si detecta uso excesivo de batería
- Requiere justificación clara en la App Store

---

## Próximas mejoras sugeridas

1. **Foreground Service (Android)**
   - Para tracking continuo más confiable
   - Muestra notificación persistente

2. **Geofencing**
   - Detectar cuando el rider llega al pickup/delivery
   - Reducir consumo de batería

3. **Optimización de batería**
   - Ajustar frecuencia según velocidad del rider
   - Usar fusedLocationProvider para mejor precisión

4. **Indicador visual de estado**
   - Mostrar si WakeLock está activo
   - Mostrar última actualización de ubicación
   - Indicador de conexión background

---

## Contacto y Soporte

Si encuentras algún problema o necesitas ajustar alguna configuración, contacta al equipo de desarrollo.

**Versión**: 1.0.0
**Fecha**: 2025-01-11
