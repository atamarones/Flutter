import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/services/supabase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/rider.dart';

class RiderRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  Future<Rider?> getRiderByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('riders')
          .select()
          .eq('user_id', userId)
          .single();
      
      return Rider.fromJson(response);
    } catch (e) {
      debugPrint('getRiderByUserId error: $e');
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
    // Verificar y refrescar sesión
    await _ensureValidSession();

    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    debugPrint('[LOCATION UPDATE] Sending to edge function - Lat: $lat, Lng: $lng');

    final response = await http.post(
      Uri.parse('${AppConstants.supabaseUrl}/functions/v1/update-rider-location'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConstants.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );

    debugPrint('[LOCATION UPDATE] Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to update location: ${response.body}');
    }
  }

  Future<void> sendHeartbeat() async {
    // Verificar y refrescar sesión
    await _ensureValidSession();

    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    debugPrint('[HEARTBEAT] Sending to edge function');
    debugPrint('[HEARTBEAT] User: ${session.user.id}');

    final response = await http.post(
      Uri.parse('${AppConstants.supabaseUrl}/functions/v1/rider-heartbeat'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConstants.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
    );

    debugPrint('[HEARTBEAT] Status: ${response.statusCode}');
    debugPrint('[HEARTBEAT] Response: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Heartbeat failed: ${response.statusCode} - ${response.body}');
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