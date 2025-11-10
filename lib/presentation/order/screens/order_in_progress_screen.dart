import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/order.dart';
import '../../home/providers/rider_provider.dart';
import '../providers/order_provider.dart';

class OrderInProgressScreen extends ConsumerWidget {
  const OrderInProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(activeOrderProvider);

    return orderState.when(
      data: (order) {
        if (order == null) return const SizedBox();
        return _OrderContent(order: order);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _OrderContent extends ConsumerStatefulWidget {
  final Order order;
  const _OrderContent({required this.order});

  @override
  ConsumerState<_OrderContent> createState() => _OrderContentState();
}

class _OrderContentState extends ConsumerState<_OrderContent> {
  bool _isNearDestination = false;

  @override
  void initState() {
    super.initState();
    _checkDistance();
  }

  Future<void> _checkDistance() async {
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (position == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.order.deliveryLat,
      widget.order.deliveryLng,
    );

    if (mounted) {
      setState(() => _isNearDestination = distance <= 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order.orderNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: _openMaps,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _getStatusColor().withValues(alpha: 0.1),
            child: Text(
              _getStatusText(),
              style: TextStyle(color: _getStatusColor(), fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Cliente'),
                  _InfoCard(icon: Icons.person, label: 'Nombre', value: widget.order.customerName),
                  _InfoCard(icon: Icons.phone, label: 'Teléfono', value: widget.order.customerPhone, onTap: _callCustomer),
                  _InfoCard(icon: Icons.location_on, label: 'Dirección', value: widget.order.deliveryAddress),
                  if (widget.order.deliveryInstructions != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text(widget.order.deliveryInstructions!)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _SectionTitle('Pedido'),
                  ...widget.order.items.map((item) => _ItemRow(item: item)),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('\$${widget.order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (widget.order.status == OrderStatus.assigned || widget.order.status == OrderStatus.accepted) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.order.status == OrderStatus.accepted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(activeOrderProvider.notifier).pickupOrder(widget.order.id);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('CONFIRMAR RECOGIDA'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReleaseDialog(context),
                icon: const Icon(Icons.cancel, color: AppColors.error),
                label: const Text('LIBERAR PEDIDO', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!_isNearDestination)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Acércate a 100m del destino para entregar')),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isNearDestination ? () => _deliverOrder(context) : null,
              icon: const Icon(Icons.check_circle),
              label: const Text('ENTREGAR'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showReleaseDialog(context),
              icon: const Icon(Icons.cancel, color: AppColors.error),
              label: const Text('LIBERAR PEDIDO', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.order.status) {
      case OrderStatus.accepted:
        return AppColors.assigned;
      case OrderStatus.inProgress:
        return AppColors.inProgress;
      default:
        return AppColors.pending;
    }
  }

  String _getStatusText() {
    switch (widget.order.status) {
      case OrderStatus.assigned:
        return 'Pedido Asignado';
      case OrderStatus.accepted:
        return 'Dirigiéndote al Punto de Recogida';
      case OrderStatus.inProgress:
        return 'En Camino a Entrega';
      default:
        return 'Pedido';
    }
  }

  Future<void> _openMaps() async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.order.deliveryLat},${widget.order.deliveryLng}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    final url = Uri.parse('tel:${widget.order.customerPhone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _deliverOrder(BuildContext context) async {
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (position == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener ubicación')),
        );
      }
      return;
    }

    await ref.read(activeOrderProvider.notifier).deliverOrder(
          widget.order.id,
          position.latitude,
          position.longitude,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido entregado exitosamente')),
      );
    }
  }

  Future<void> _showReleaseDialog(BuildContext context) async {
    final reasons = ['Cliente no responde', 'Dirección incorrecta', 'Problemas con el pedido', 'Otro'];
    String? selectedReason = reasons[0];
    
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Liberar Pedido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) => ListTile(
              title: Text(reason),
              leading: Radio<String>(
                value: reason,
                groupValue: selectedReason,
                onChanged: (value) {
                  setState(() => selectedReason = value);
                },
              ),
              onTap: () {
                setState(() => selectedReason = reason);
              },
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, selectedReason),
              child: const Text('CONFIRMAR'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (!mounted) return;
      
      await ref.read(activeOrderProvider.notifier).releaseOrder(widget.order.id, result);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido liberado')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoCard({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.name)),
          Text('\$${(item.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}