# Configuración Remota - Urbango Logistics Rider App

## Descripción

La aplicación utiliza un sistema de configuración remota que permite actualizar valores de configuración sin necesidad de generar una nueva versión de la aplicación. Esto es útil para ajustar parámetros como tiempos de espera, radios de entrega, números de soporte, etc.

## Cómo funciona

1. **Inicialización**: Al iniciar la app, se carga la configuración desde el servidor
2. **Cache**: La configuración se guarda localmente y se actualiza cada hora
3. **Fallback**: Si el servidor no está disponible, se usan valores por defecto

## Endpoint de Configuración

```
GET https://aima-n8n.yau1cn.easypanel.host/webhook/app-config-rider
```

## Formato del JSON de Respuesta

El endpoint debe devolver un JSON con los siguientes campos (todos opcionales):

```json
{
  "locationUpdateIntervalSeconds": 15,
  "heartbeatIntervalSeconds": 15,
  "deliveryRadiusMeters": 50.0,
  "orderTimeoutSeconds": 59,
  "supportWhatsAppNumber": "+573167107509",
  "notTakenReleaseOrderWebhook": "https://aima-n8n.yau1cn.easypanel.host/webhook/notaken-release-order-rider"
}
```

## Parámetros Configurables

| Campo | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `locationUpdateIntervalSeconds` | int | 15 | Intervalo de actualización de ubicación del rider (en segundos) |
| `heartbeatIntervalSeconds` | int | 15 | Intervalo de heartbeat del rider (en segundos) |
| `deliveryRadiusMeters` | double | 50.0 | Radio en metros para validar cercanía al punto de entrega/recogida |
| `orderTimeoutSeconds` | int | 59 | Tiempo en segundos antes de que expire una asignación de pedido |
| `supportWhatsAppNumber` | string | "+573167107509" | Número de WhatsApp de soporte |
| `notTakenReleaseOrderWebhook` | string | URL | Webhook a llamar cuando un pedido no es tomado por el rider |

## Valores por Defecto

Si el servidor no está disponible o no devuelve algún valor, se usan los valores por defecto especificados en la tabla anterior.

## Cache

- La configuración se guarda en `SharedPreferences`
- Se actualiza cada **1 hora** automáticamente
- Si la app no puede conectarse al servidor, usa la última configuración en cache

## Cómo actualizar la configuración

### Desde el portal web (n8n)

1. Accede al webhook de configuración en n8n
2. Modifica los valores según necesites
3. La app descargará los nuevos valores en el próximo fetch (máximo 1 hora)

### Forzar actualización manual

Los riders pueden forzar una actualización cerrando y abriendo la app completamente.

## Implementación Técnica

### Servicio Principal
- `lib/core/services/remote_config_service.dart` - Servicio singleton que gestiona la configuración

### Provider
- `lib/core/providers/remote_config_provider.dart` - Providers de Riverpod para acceder a valores

### Constantes
- `lib/core/constants/app_constants.dart` - Los valores ahora son getters que consultan RemoteConfigService

## Ejemplo de uso en código

```dart
// Forma antigua (ya no funciona)
// const timeout = AppConstants.orderTimeoutSeconds; // ❌

// Forma nueva (correcta)
final timeout = AppConstants.orderTimeoutSeconds; // ✅
```

## Consideraciones

1. **No usar `const`**: Los valores ya no son constantes de compilación, por lo que no pueden usarse con `const`
2. **Valores iniciales**: En el primer inicio, se usan los defaults hasta que se descargue la configuración
3. **Actualización en tiempo real**: Los cambios no se aplican en tiempo real, requieren reinicio de la app
4. **Conexión requerida**: La primera vez que se inicia la app, necesita conexión a internet para descargar la configuración

## Monitoreo

Para verificar que la configuración remota está funcionando correctamente, revisa los logs:

```
Remote config loaded from cache
Remote config fetched successfully: [locationUpdateIntervalSeconds, heartbeatIntervalSeconds, ...]
```

## Troubleshooting

### La configuración no se actualiza
- Verifica que el endpoint esté respondiendo correctamente
- Revisa los logs de la aplicación
- Asegúrate de que haya pasado más de 1 hora desde la última actualización

### Valores por defecto siendo usados
- Verifica conectividad a internet
- Confirma que el endpoint devuelve JSON válido
- Revisa que los nombres de los campos coincidan exactamente
