import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/order.dart';
import '../providers/order_provider.dart';

class OrderAssignedScreen extends ConsumerWidget {
  final Order order;

  const OrderAssignedScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Deshabilitar el botón de back durante orden asignada
        if (didPop) return;
      },
      child: Scaffold(
        body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.notifications_active, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Nuevo Pedido',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.orderNumber,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.store,
                      label: 'Recogida',
                      value: order.pickupAddress,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Entrega',
                      value: order.deliveryAddress,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.attach_money,
                      label: 'Total',
                      value: '\$${order.totalAmount}',
                    ),
                    if (order.estimatedDistanceKm != null) ...[
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.route,
                        label: 'Distancia',
                        value: '${order.estimatedDistanceKm!.toStringAsFixed(1)} km',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(activeOrderProvider.notifier).acceptOrder(order.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('ACEPTAR PEDIDO', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}