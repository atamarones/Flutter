import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) return Future.value(true);

      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/functions/v1/rider-heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
      );
      
      // Log para debugging
      print('Heartbeat response: ${response.statusCode}');
      
      return Future.value(response.statusCode == 200);
    } catch (e) {
      print('Heartbeat error: $e');
      return Future.value(false);
    }
  });
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

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }
}