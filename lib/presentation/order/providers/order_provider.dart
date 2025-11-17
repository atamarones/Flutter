import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../domain/entities/order.dart';
import '../../../core/services/supabase_service.dart';
import '../../home/providers/rider_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository());

class ActiveOrderNotifier extends AsyncNotifier<Order?> {
  late OrderRepository _orderRepository;
  late String _riderId;
  RealtimeChannel? _channel;

  @override
  Future<Order?> build() async {
    final riderAsync = ref.watch(riderStateProvider);

    await riderAsync.when(
      data: (rider) async {
        if (rider != null) {
          _riderId = rider.id;
          _orderRepository = ref.read(orderRepositoryProvider);

          ref.onDispose(() {
            _channel?.unsubscribe();
            _channel = null;
          });

          _subscribeToOrders();
        }
      },
      loading: () async {},
      error: (_, __) async {},
    );

    if (riderAsync.value?.id == null) return null;
    _riderId = riderAsync.value!.id;
    _orderRepository = ref.read(orderRepositoryProvider);

    // Escuchar cambios en el estado de autenticación
    // Importar auth_provider para acceder a authStateProvider
    ref.listen(
      riderStateProvider,
      (previous, next) {
        // Si el rider cambió o se eliminó, invalidar este provider
        final previousRiderId = previous?.value?.id;
        final currentRiderId = next.value?.id;

        if (previousRiderId != null && previousRiderId != currentRiderId) {
          // El rider cambió - limpiar suscripción y invalidar
          _channel?.unsubscribe();
          _channel = null;
          ref.invalidateSelf();
        }
      },
    );

    _subscribeToOrders();

    return await _loadActiveOrder();
  }

  Future<Order?> _loadActiveOrder() async {
    try {
      return await _orderRepository.getActiveOrder(_riderId);
    } catch (e) {
      return null;
    }
  }

  void _subscribeToOrders() {
    _channel = SupabaseService.client
        .channel('orders:$_riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'rider_id', value: _riderId),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final order = Order.fromJson(payload.newRecord);
              state = AsyncValue.data(order);
            }
          },
        )
        .subscribe();
  }

  Future<void> acceptOrder(String orderId) async {
    await _orderRepository.handleOrderAction(orderId: orderId, action: 'accept');
    final updated = await _loadActiveOrder();
    state = AsyncValue.data(updated);
  }

  Future<void> pickupOrder(String orderId) async {
    await _orderRepository.handleOrderAction(orderId: orderId, action: 'pickup');
    final updated = await _loadActiveOrder();
    state = AsyncValue.data(updated);
  }

  Future<void> deliverOrder(String orderId, double lat, double lng) async {
    await _orderRepository.handleOrderAction(
      orderId: orderId,
      action: 'deliver',
      deliveryLat: lat,
      deliveryLng: lng,
    );
    state = const AsyncValue.data(null);
  }

  Future<void> releaseOrder(String orderId, String reason) async {
    await _orderRepository.handleOrderAction(orderId: orderId, action: 'release', reason: reason);
    state = const AsyncValue.data(null);
  }
}

final activeOrderProvider = AsyncNotifierProvider<ActiveOrderNotifier, Order?>(() {
  return ActiveOrderNotifier();
});