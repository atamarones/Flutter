import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../domain/entities/order.dart';
import '../../home/providers/rider_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository());

final orderHistoryProvider = FutureProvider<List<Order>>((ref) async {
  final riderAsync = ref.watch(riderStateProvider);
  final rider = riderAsync.value;
  if (rider == null) return [];
  return ref.read(orderRepositoryProvider).getOrdersByRider(rider.id);
});

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Pedidos')),
      body: ordersState.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No hay pedidos'));
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.refresh(orderHistoryProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) => _OrderCard(order: orders[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  _StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.shopping_bag, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('${order.items.length} items'),
                  const SizedBox(width: 16),
                  const Icon(Icons.attach_money, size: 16, color: AppColors.textSecondary),
                  Text('\$${order.totalAmount}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          color: _getColor(),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case OrderStatus.delivered: return AppColors.delivered;
      case OrderStatus.inProgress: return AppColors.inProgress;
      case OrderStatus.released: return AppColors.released;
      default: return AppColors.pending;
    }
  }

  String _getLabel() {
    switch (status) {
      case OrderStatus.delivered: return 'Entregado';
      case OrderStatus.inProgress: return 'En Curso';
      case OrderStatus.released: return 'Liberado';
      case OrderStatus.accepted: return 'Aceptado';
      default: return 'Pendiente';
    }
  }
}