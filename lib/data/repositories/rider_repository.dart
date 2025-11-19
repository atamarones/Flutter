import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/services/supabase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/rider.dart';
import '../../core/utils/app_logger.dart';

class RiderRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  Future<Rider?> getRiderByUserId(String userId) async {
    try {
      AppLogger.info('[RIDER_REPO] Consultando rider con user_id: $userId');

      final response = await _supabase
          .from('riders')
          .select()
          .eq('user_id', userId)
          .single();

      AppLogger.info('[RIDER_REPO] Rider encontrado: ${response['full_name']} (ID: ${response['id']})');
      return Rider.fromJson(response);
    } catch (e) {
      AppLogger.error('[RIDER_REPO] Error al obtener rider', error: e);

      // Si el error es porque no se encontró el rider (PostgrestException)
      if (e.toString().contains('PGRST116') || e.toString().contains('JSON object requested')) {
        AppLogger.warning('[RIDER_REPO] No existe un rider con user_id: $userId en la tabla riders');
      }

      return null;
    }
  }

  Future<void> updateStatus(String riderId, RiderStatus status) async {
    await _supabase
        .from('riders')
        .update({'status': status.name})
        .eq('id', riderId);
  }

  Future<void> updateLocation(double lat, double lng) async {
    try {
      // Verificar y refrescar sesión
      await _ensureValidSession();

      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/functions/v1/update-rider-location'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'lat': lat, 'lng': lng}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        AppLogger.error('[LOCATION UPDATE] Failed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update location: ${response.body}');
      }
    } on http.ClientException catch (e) {
      // Error de red (DNS, socket, etc.) - no es crítico, se reintentará en el siguiente ciclo
      AppLogger.warning('[LOCATION UPDATE] Error de red (se reintentará): $e');
      // NO lanzar excepción - permitir que continúe
    } catch (e) {
      // Otros errores sí son críticos
      AppLogger.error('[LOCATION UPDATE] Error: $e');
      rethrow;
    }
  }

  Future<void> sendHeartbeat() async {
    try {
      // Verificar y refrescar sesión
      await _ensureValidSession();

      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/functions/v1/rider-heartbeat'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        LoggerCategories.heartbeat('Failed: ${response.statusCode} - ${response.body}', isError: true);
        throw Exception('Heartbeat failed: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      // Error de red (DNS, socket, etc.) - no es crítico, se reintentará en el siguiente ciclo
      LoggerCategories.heartbeat('Error de red (se reintentará): $e', isError: false);
      // NO lanzar excepción - permitir que continúe
    } catch (e) {
      // Otros errores sí son críticos
      LoggerCategories.heartbeat('Error: $e', isError: true);
      rethrow;
    }
  }

  Future<void> _ensureValidSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('No session available');
    }

    // Verificar si el token está cerca de expirar (dentro de 5 minutos)
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.inMinutes < 5) {
      // Refrescar sesión
      await _supabase.auth.refreshSession();
    }
  }
}