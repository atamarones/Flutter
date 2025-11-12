import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../constants/app_constants.dart';

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
    debugPrint('🚀 [FOREGROUND SERVICE] Iniciado');
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
        debugPrint('⚠️ [FOREGROUND SERVICE] Rider offline o sin token');
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
      debugPrint('❌ [FOREGROUND SERVICE] Error: $e');
    }
  }

  Future<void> _updateLocation(String token) async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [FOREGROUND SERVICE] Permisos de ubicación denegados');
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
        debugPrint('✅ [FOREGROUND SERVICE] Ubicación actualizada: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('❌ [FOREGROUND SERVICE] Error actualizando ubicación: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [FOREGROUND SERVICE] Error en update location: $e');
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
        debugPrint('💓 [FOREGROUND SERVICE] Heartbeat enviado');
      } else {
        debugPrint('❌ [FOREGROUND SERVICE] Error en heartbeat: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [FOREGROUND SERVICE] Error en heartbeat: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('🛑 [FOREGROUND SERVICE] Detenido');
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
      debugPrint('⚠️ [FOREGROUND SERVICE] Ya está corriendo');
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

      debugPrint('✅ [FOREGROUND SERVICE] Iniciado exitosamente');
      return true;
    } catch (e) {
      debugPrint('❌ [FOREGROUND SERVICE] Error al iniciar: $e');
      return false;
    }
  }

  /// Detener el servicio de tracking
  static Future<bool> stop() async {
    try {
      await FlutterForegroundTask.stopService();
      debugPrint('✅ [FOREGROUND SERVICE] Detenido exitosamente');
      return true;
    } catch (e) {
      debugPrint('❌ [FOREGROUND SERVICE] Error al detener: $e');
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
    if (token != null) {
      debugPrint('✅ [FOREGROUND SERVICE] Token encontrado para el servicio');
    } else {
      debugPrint('⚠️ [FOREGROUND SERVICE] No se encontró token');
    }
  }

  /// Guardar token para el servicio
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    debugPrint('✅ [FOREGROUND SERVICE] Token guardado');
  }

  /// Guardar estado del rider
  static Future<void> saveRiderStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_status', status);
    debugPrint('✅ [FOREGROUND SERVICE] Estado guardado: $status');
  }

  /// Limpiar datos del servicio
  static Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('rider_status');
    debugPrint('✅ [FOREGROUND SERVICE] Datos limpiados');
  }
}
