import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../domain/entities/order.dart';

class OrderRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  Future<List<Order>> getOrdersByRider(String riderId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('rider_id', riderId)
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => Order.fromJson(json)).toList();
  }

  Future<Order?> getActiveOrder(String riderId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('rider_id', riderId)
        .inFilter('status', ['assigned', 'accepted', 'in_progress'])
        .limit(1)
        .maybeSingle();
    
    return response != null ? Order.fromJson(response) : null;
  }

  Future<void> handleOrderAction({
    required String orderId,
    required String action,
    String? reason,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    // Verificar sesión válida
    await _ensureValidSession();
    
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final body = {
      'order_id': orderId,
      'action': action,
      if (reason != null) 'reason': reason,
      if (deliveryLat != null) 'delivery_lat': deliveryLat,
      if (deliveryLng != null) 'delivery_lng': deliveryLng,
    };

    final response = await _supabase.functions.invoke(
      'handle-order-action',
      body: body,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );
    
    if (response.status != 200) {
      throw Exception('Action failed: ${response.status} - ${response.data}');
    }
  }

  Future<void> _ensureValidSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('No session available');
    }

    // Refrescar si expira en menos de 5 minutos
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.inMinutes < 5) {
      await _supabase.auth.refreshSession();
    }
  }
}