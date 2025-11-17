import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// Handler para el Foreground Service
/// Este código corre en un isolate separado y se ejecuta continuamente
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RiderTrackingHandler());
}

class RiderTrackingHandler extends TaskHandler {
  int _heartbeatCounter = 0;
  int _locationCounter = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    LoggerCategories.foregroundService('Iniciado', level: LogLevel.info);
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    // Este método se ejecuta cada intervalo configurado (ej: cada 10 segundos)
    _heartbeatCounter++;
    _locationCounter++;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final riderStatus = prefs.getString('rider_status') ?? 'offline';

      if (token == null || riderStatus == 'offline') {
        return;
      }

      // Actualizar ubicación cada 30 segundos (3 intervalos de 10s)
      if (_locationCounter >= 3) {
        await _updateLocation(token);
        _locationCounter = 0;
      }

      // Enviar heartbeat cada 30 segundos (3 intervalos de 10s)
      if (_heartbeatCounter >= 3) {
        await _sendHeartbeat(token);
        _heartbeatCounter = 0;
      }

      // Actualizar notificación con timestamp
      FlutterForegroundTask.updateService(
        notificationTitle: 'Urbango - En línea',
        notificationText: 'Última actualización: ${DateTime.now().toString().substring(11, 19)}',
      );
    } catch (e) {
      LoggerCategories.foregroundService('Error en evento repetido: $e', level: LogLevel.error);
    }
  }

  Future<void> _updateLocation(String token) async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        LoggerCategories.foregroundService('Permisos de ubicación denegados', level: LogLevel.warning);
        return;
      }

      // Obtener ubicación con configuración actualizada
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      // Enviar al backend
      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/functions/v1/update-rider-location'),
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
      } else {
        LoggerCategories.location('Error actualizando ubicación: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('[FOREGROUND SERVICE] Error en update location', error: e);
    }
  }

  Future<void> _sendHeartbeat(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/functions/v1/rider-heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
      } else {
        LoggerCategories.heartbeat('Error en heartbeat: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      LoggerCategories.heartbeat('Error en heartbeat: $e', isError: true);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    LoggerCategories.foregroundService('Detenido', level: LogLevel.info);
  }
}

/// Clase de utilidades para manejar el Foreground Service
class ForegroundTrackingService {
  /// Inicializar el servicio (llamar en main.dart)
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rider_tracking_channel',
        channelName: 'Rider Tracking',
        channelDescription: 'Servicio de tracking para riders en línea',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // 10 segundos
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Iniciar el servicio de tracking
  static Future<bool> start() async {
    // Verificar si ya está corriendo
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      return true;
    }

    // Guardar token actualizado
    await _saveCurrentToken();

    // Iniciar servicio
    try {
      await FlutterForegroundTask.startService(
        serviceId: 999,
        notificationTitle: 'Urbango - En línea',
        notificationText: 'Tracking activo',
        callback: startCallback,
      );

      LoggerCategories.foregroundService('Iniciado exitosamente', level: LogLevel.info);
      return true;
    } catch (e) {
      AppLogger.error('[FOREGROUND SERVICE] Error al iniciar', error: e);
      return false;
    }
  }

  /// Detener el servicio de tracking
  static Future<bool> stop() async {
    try {
      await FlutterForegroundTask.stopService();
      LoggerCategories.foregroundService('Detenido exitosamente', level: LogLevel.info);
      return true;
    } catch (e) {
      AppLogger.error('[FOREGROUND SERVICE] Error al detener', error: e);
      return false;
    }
  }

  /// Verificar si está corriendo
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Guardar token actual en SharedPreferences
  static Future<void> _saveCurrentToken() async {
    // Este método será llamado desde el RiderProvider con el token actual
    // Por ahora solo verificamos que exista
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      AppLogger.warning('[FOREGROUND SERVICE] No se encontró token');
    }
  }

  /// Guardar token para el servicio
  ///
  /// ADVERTENCIA DE SEGURIDAD:
  /// Este método guarda el token en SharedPreferences SIN ENCRIPTACIÓN.
  /// En dispositivos rooteados, el token puede ser leído por otras aplicaciones.
  ///
  /// TODO: Migrar a flutter_secure_storage para encriptar el token
  /// Severidad: ALTA - Riesgo de exposición de credenciales
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  /// Guardar estado del rider
  static Future<void> saveRiderStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_status', status);
  }

  /// Limpiar datos del servicio
  ///
  /// SEGURIDAD: Este método es CRÍTICO para prevenir Cross-User Data Leakage.
  /// Se llama automáticamente en logout para eliminar tokens del usuario anterior.
  static Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('rider_status');
  }
}
