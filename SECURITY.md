# Informe de Seguridad - Flutter Urbango Logistics

**Fecha:** 14 de Noviembre de 2025
**Tipo de Vulnerabilidad:** Cross-User Data Leakage (A01:2021 - Broken Access Control / A07:2021 - Authentication Failures)
**Severidad Original:** CRÍTICA
**Estado Actual:** PARCIALMENTE MITIGADO

---

## Resumen Ejecutivo

Se identificó una vulnerabilidad crítica de **Cross-User Data Leakage** donde los datos de un usuario podían ser visibles a otro usuario después de logout/login. Esta vulnerabilidad ha sido **PARCIALMENTE MITIGADA** mediante la implementación de invalidación automática de providers y limpieza de estado.

---

## Vulnerabilidades Identificadas y Corregidas

### ✅ CORREGIDO: Provider State Persistence

**Problema Original:**
- `RiderStateNotifier` mantenía `_userId` del usuario anterior después de logout
- `ActiveOrderNotifier` mantenía suscripciones de RealtimeChannel del usuario anterior
- Providers no se invalidaban automáticamente al cambiar de usuario

**Impacto:**
- Usuario B podía ver datos (ubicación, órdenes, perfil) del Usuario A
- Horizontal Privilege Escalation entre usuarios del mismo nivel

**Solución Implementada:**

1. **RiderStateNotifier** (lib/presentation/home/providers/rider_provider.dart:45-54)
   - Listener de `authStateProvider` detecta cambios de usuario
   - Invalida automáticamente el provider cuando cambia el usuario
   ```dart
   ref.listen(authStateProvider, (previous, next) {
     next.whenData((authState) {
       final currentUser = authState.session?.user;
       if (currentUser == null || currentUser.id != _userId) {
         ref.invalidateSelf();
       }
     });
   });
   ```

2. **ActiveOrderNotifier** (lib/presentation/order/providers/order_provider.dart:41-57)
   - Listener de `riderStateProvider` detecta cambios de rider
   - Limpia suscripciones de RealtimeChannel antes de invalidar
   ```dart
   ref.listen(riderStateProvider, (previous, next) {
     final previousRiderId = previous?.value?.id;
     final currentRiderId = next.value?.id;
     if (previousRiderId != null && previousRiderId != currentRiderId) {
       _channel?.unsubscribe();
       _channel = null;
       ref.invalidateSelf();
     }
   });
   ```

3. **Logout Seguro** (lib/presentation/auth/providers/auth_provider.dart:64-83)
   - Función `secureLogout()` centraliza la limpieza de estado
   - Invalida todos los providers de autenticación
   - Documentado para uso obligatorio en lugar de `logout()` directo

**Archivos Modificados:**
- ✅ lib/presentation/home/providers/rider_provider.dart
- ✅ lib/presentation/order/providers/order_provider.dart
- ✅ lib/presentation/auth/providers/auth_provider.dart
- ✅ lib/presentation/home/screens/home_screen.dart
- ✅ lib/presentation/profile/screens/profile_screen.dart

---

## ⚠️ Vulnerabilidades Residuales (Pendientes de Mitigación)

### 🔴 CRÍTICO: Token Almacenado Sin Encriptación

**Ubicación:** lib/core/services/foreground_tracking_service.dart:219-221

**Problema:**
```dart
static Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('access_token', token); // ❌ Sin encriptación
}
```

**Impacto:**
- En dispositivos rooteados/jailbroken, el token puede ser leído por:
  - Otras aplicaciones con permisos elevados
  - Malware con acceso root
  - Usuarios con acceso físico al dispositivo
- Ubicación del archivo en Android: `/data/data/io.supabase.urbangologistics/shared_prefs/FlutterSharedPreferences.xml`
- Riesgo de suplantación de identidad si el token es comprometido

**Recomendación:**
Migrar a `flutter_secure_storage` que usa:
- Android: KeyStore (encriptación hardware)
- iOS: Keychain (encriptación nativa)

**Implementación Sugerida:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

static const _storage = FlutterSecureStorage();

static Future<void> saveToken(String token) async {
  await _storage.write(key: 'access_token', value: token);
}

static Future<String?> getToken() async {
  return await _storage.read(key: 'access_token');
}
```

**Pasos de Migración:**
1. Agregar dependencia en `pubspec.yaml`: `flutter_secure_storage: ^9.0.0`
2. Modificar `ForegroundTrackingService.saveToken()` y `clearData()`
3. Actualizar `RiderTrackingHandler.onRepeatEvent()` para leer del secure storage
4. Verificar compatibilidad con isolates en foreground service
5. Testing en dispositivos físicos (Android 6+, iOS 9+)

**Prioridad:** P0 - CRÍTICO (antes de producción)

---

### 🟡 MEDIO: Falta de Validación de Sesión en Background Service

**Ubicación:** lib/core/services/foreground_tracking_service.dart:26-38

**Problema:**
El servicio en background verifica si hay token, pero no valida:
- Si el token sigue siendo válido (no expiró)
- Si el token pertenece al usuario actual de la sesión
- Si hubo un cambio de usuario desde que se inició el servicio

**Impacto:**
- Requests con tokens expirados generan errores innecesarios
- Posible race condition si el logout ocurre mientras el servicio envía datos

**Recomendación:**
```dart
@override
void onRepeatEvent(DateTime timestamp) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final riderStatus = prefs.getString('rider_status') ?? 'offline';

    // ✅ Agregar validación
    if (token == null || riderStatus == 'offline') {
      return;
    }

    // ✅ Verificar que el token no haya expirado
    if (_isTokenExpired(token)) {
      await clearData();
      await FlutterForegroundTask.stopService();
      return;
    }

    // ... resto del código
  }
}
```

**Prioridad:** P1 - ALTO (próximas 2 semanas)

---

## Arquitectura de Seguridad Actual

### Flujo de Logout Seguro

```
Usuario hace tap en "Logout"
  ↓
secureLogout(ref)
  ├─ 1. authRepository.logout()
  │   ├─ ForegroundTrackingService.stop()
  │   ├─ ForegroundTrackingService.clearData() ✅ Limpia tokens
  │   └─ supabase.auth.signOut()
  │
  ├─ 2. Invalidar providers de autenticación
  │   ├─ authStateProvider ✅
  │   ├─ currentUserProvider ✅
  │   └─ loginProvider ✅
  │
  └─ 3. Invalidación automática (via listeners)
      ├─ riderStateProvider ✅ (escucha authStateProvider)
      └─ activeOrderProvider ✅ (escucha riderStateProvider)
  ↓
context.go('/login') → Navega a pantalla de login
```

### Flujo de Login

```
Usuario hace login
  ↓
AuthRepository.login(email, password)
  ├─ supabase.auth.signInWithPassword()
  ├─ ForegroundTrackingService.saveToken() ⚠️ SharedPreferences
  └─ authStateProvider emite cambio
  ↓
Providers se reconstruyen automáticamente
  ├─ riderStateProvider.build() → Carga datos del nuevo usuario
  └─ activeOrderProvider.build() → Suscribe a órdenes del nuevo usuario
```

---

## Checklist de Seguridad

### ✅ Implementado

- [x] Invalidación automática de `riderStateProvider` al cambiar usuario
- [x] Invalidación automática de `activeOrderProvider` al cambiar rider
- [x] Limpieza de RealtimeChannel subscriptions en invalidación
- [x] Función `secureLogout()` centralizada
- [x] Actualización de puntos de logout en UI
- [x] Documentación de advertencias de seguridad en código

### ⚠️ Pendiente (Crítico)

- [ ] Migrar tokens a `flutter_secure_storage`
- [ ] Validación de expiración de token en background service
- [ ] Tests de regresión para Cross-User Data Leakage
- [ ] Audit logging de acceso a datos sensibles

### 📋 Pendiente (Recomendado)

- [ ] Implementar device fingerprinting
- [ ] Rate limiting en intentos de login
- [ ] Monitoreo de accesos sospechosos
- [ ] Encriptar rider_status en almacenamiento local

---

## Pruebas de Seguridad Recomendadas

### Test 1: Logout/Login Rápido
```dart
test('Cross-User Data Leakage - Logout/Login rápido', () async {
  // 1. Login como Usuario A
  await login('userA@example.com', 'password');
  final riderA = await getRider();

  // 2. Logout
  await secureLogout(ref);

  // 3. Login inmediato como Usuario B
  await login('userB@example.com', 'password');
  final riderB = await getRider();

  // 4. Verificar que NO hay datos de Usuario A
  expect(riderB.id, isNot(equals(riderA.id)));
  expect(activeOrder, isNull); // No debe haber orden de Usuario A
});
```

### Test 2: Token Persistence
```dart
test('Token se limpia en logout', () async {
  await login('user@example.com', 'password');

  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('access_token'), isNotNull);

  await secureLogout(ref);

  expect(prefs.getString('access_token'), isNull);
});
```

### Test 3: Realtime Subscription Cleanup
```dart
test('RealtimeChannel se limpia en logout', () async {
  await login('user@example.com', 'password');

  // Verificar que hay suscripción activa
  final channel = getActiveOrderChannel();
  expect(channel, isNotNull);

  await secureLogout(ref);

  // Verificar que la suscripción se limpió
  expect(getActiveOrderChannel(), isNull);
});
```

---

## Clasificación OWASP

Esta vulnerabilidad mapea a:

- **A01:2021 - Broken Access Control**
  - Horizontal Privilege Escalation
  - Acceso a recursos de otros usuarios del mismo nivel

- **A07:2021 - Identification and Authentication Failures**
  - Session State Persistence Vulnerability
  - Falta de invalidación de sesión en cambio de usuario

**CVSS Score (Original):** 7.5 HIGH
**CVSS Score (Actual):** 5.3 MEDIUM (mitigado parcialmente)

---

## Recomendaciones Finales

### Inmediatas (P0)
1. ✅ **COMPLETADO:** Invalidación de providers en logout
2. ⚠️ **PENDIENTE:** Migrar a `flutter_secure_storage` para tokens

### Corto Plazo (P1)
3. Validación de tokens en background service
4. Tests automatizados de seguridad
5. Code review de todos los puntos de acceso a datos de usuario

### Mediano Plazo (P2)
6. Audit logging de accesos a datos sensibles
7. Monitoreo de anomalías en patrones de acceso
8. Implementar session boundaries más robustas

### Largo Plazo (P3)
9. Considerar arquitectura zero-trust
10. Implementar mutual TLS para comunicación con backend
11. Rotación automática de tokens

---

## Contacto

Para reportar vulnerabilidades de seguridad adicionales, contactar al equipo de desarrollo.

**Última Actualización:** 14 de Noviembre de 2025
**Próxima Revisión:** Después de implementar mitigaciones P0
