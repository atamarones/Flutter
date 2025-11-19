import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/order.dart';
import '../../home/providers/rider_provider.dart';
import '../providers/order_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../widgets/pickup_route_map_widget.dart';

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
  bool _isNearPickup = false;

  @override
  void initState() {
    super.initState();
    _checkDistance();
  }

  Future<void> _checkDistance() async {
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (position == null) return;

    // Solo validar cercanía al PICKUP cuando está accepted
    if (widget.order.status == OrderStatus.accepted) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.order.pickupLat,
        widget.order.pickupLng,
      );
      if (mounted) {
        setState(() => _isNearPickup = distance <= 50);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final riderAsync = ref.watch(riderStateProvider);
    final isGoingToPickup = widget.order.status == OrderStatus.accepted;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Deshabilitar el botón de back durante orden en progreso
        if (didPop) return;
      },
      child: Scaffold(
      body: Stack(
        children: [
          // MAPA (40% superior)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: riderAsync.when(
              data: (rider) => PickupRouteMapWidget(
                order: widget.order,
                riderLat: rider?.currentLat,
                riderLng: rider?.currentLng,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Icon(Icons.error)),
            ),
          ),

          // CONTENIDO (60% inferior)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header con estado
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Drag indicator
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Estado y tiempo
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isGoingToPickup ? AppColors.assigned : AppColors.inProgress,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isGoingToPickup ? 'Recoger pedido' : 'Entregar pedido',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (isGoingToPickup && widget.order.durationToPickupMin != null)
                                    Text(
                                      '~${widget.order.durationToPickupMin} min',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else if (!isGoingToPickup && widget.order.estimatedDurationMin != null)
                                    Text(
                                      '~${widget.order.estimatedDurationMin} min',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Botones de acción principales
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Botón NAVEGAR (destacado)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _openNavigation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0066FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.navigation, size: 24),
                            label: const Text(
                              'Navegar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón SOPORTE
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openWhatsAppSupport,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.support_agent, size: 22),
                            label: const Text(
                              'Soporte',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Información del destino (Pickup o Cliente)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card de destino
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: isGoingToPickup ? _buildPickupInfo() : _buildCustomerInfo(),
                          ),

                          const SizedBox(height: 16),

                          // Información del pedido
                          _buildOrderInfo(),

                          const SizedBox(height: 100), // Espacio para botón fijo
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón de acción fijo (parte inferior)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _buildMainActionButton(),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPickupInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, color: Color(0xFFFF5722), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.providerName ?? 'Punto de recogida',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.pickupAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.order.distanceToPickupKm != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bike, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${widget.order.distanceToPickupKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Color(0xFF4CAF50), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.deliveryAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _callCustomer,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  widget.order.customerPhone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.order.deliveryInstructions != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.deliveryInstructions!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalle del pedido',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '\$${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '\$${widget.order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainActionButton() {
    if (widget.order.status == OrderStatus.accepted) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isNearPickup ? _confirmPickup : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7A6E),
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _isNearPickup ? 'CONFIRMAR RECOGIDA' : 'Acércate al punto de recogida',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isNearPickup ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // En camino a entrega
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _deliverOrder(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D7A6E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'ENTREGAR PEDIDO',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _openNavigation() async {
    final settings = ref.read(settingsProvider);
    final isGoingToPickup = widget.order.status == OrderStatus.accepted;

    final lat = isGoingToPickup ? widget.order.pickupLat : widget.order.deliveryLat;
    final lng = isGoingToPickup ? widget.order.pickupLng : widget.order.deliveryLng;

    final url = switch (settings.navigationMethod) {
      NavigationMethod.googleMaps => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      NavigationMethod.waze => Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
      NavigationMethod.appleMaps => Uri.parse('https://maps.apple.com/?daddr=$lat,$lng'),
    };

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final url = Uri.parse('https://wa.me/${AppConstants.supportWhatsAppNumber.replaceAll('+', '')}?text=Hola, necesito ayuda con mi pedido ${widget.order.orderNumber}');

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

  Future<void> _confirmPickup() async {
    await ref.read(activeOrderProvider.notifier).pickupOrder(widget.order.id);
    _checkDistance(); // Re-check para la siguiente fase
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
}
