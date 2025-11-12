import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../constants/app_constants.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final riderStatus = prefs.getString('rider_status') ?? 'offline';

      if (token == null) return Future.value(true);

      // Si el rider está offline, no ejecutar tasks
      if (riderStatus == 'offline') {
        print('Rider offline - skipping background task');
        return Future.value(true);
      }

      // Ejecutar task según el tipo
      if (task == 'riderHeartbeatTask') {
        return await _executeHeartbeat(token);
      } else if (task == 'riderLocationTask') {
        return await _executeLocationUpdate(token, riderStatus);
      }

      return Future.value(true);
    } catch (e) {
      print('Background task error: $e');
      return Future.value(false);
    }
  });
}

Future<bool> _executeHeartbeat(String token) async {
  try {
    final response = await http.post(
      Uri.parse('${AppConstants.supabaseUrl}/functions/v1/rider-heartbeat'),
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': AppConstants.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
    );

    print('Background Heartbeat: ${response.statusCode}');
    return response.statusCode == 200;
  } catch (e) {
    print('Heartbeat error: $e');
    return false;
  }
}

Future<bool> _executeLocationUpdate(String token, String status) async {
  try {
    // Solo actualizar ubicación si está online o delivering
    if (status != 'online' && status != 'delivering') {
      return true;
    }

    // Verificar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Location permission denied in background');
      return true;
    }

    // Obtener ubicación actual
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Enviar actualización al backend
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
    );

    print('Background Location Update: ${response.statusCode} - Lat: ${position.latitude}, Lng: ${position.longitude}');
    return response.statusCode == 200;
  } catch (e) {
    print('Location update error: $e');
    return false;
  }
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  static Future<void> startHeartbeat() async {
    await Workmanager().registerPeriodicTask(
      'rider-heartbeat',
      'riderHeartbeatTask',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> stopHeartbeat() async {
    await Workmanager().cancelByUniqueName('rider-heartbeat');
  }

  // Nuevo: Servicio de actualización de ubicación en segundo plano
  static Future<void> startLocationTracking() async {
    await Workmanager().registerPeriodicTask(
      'rider-location',
      'riderLocationTask',
      frequency: const Duration(minutes: 15), // Mínimo permitido por Android
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> stopLocationTracking() async {
    await Workmanager().cancelByUniqueName('rider-location');
  }

  // Guardar estado del rider para controlar tareas en background
  static Future<void> saveRiderStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_status', status);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('rider_status');
  }
}