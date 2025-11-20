import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/order.dart';
import '../providers/order_provider.dart';
import '../../home/providers/rider_provider.dart';
import 'order_map_widget.dart';

class OrderAssignedDialog extends ConsumerStatefulWidget {
  final Order order;

  const OrderAssignedDialog({super.key, required this.order});

  @override
  ConsumerState<OrderAssignedDialog> createState() => _OrderAssignedDialogState();
}

class _OrderAssignedDialogState extends ConsumerState<OrderAssignedDialog> {
  bool _isAccepting = false;
  final _audioPlayer = AudioPlayer();
  int _countdown = AppConstants.orderTimeoutSeconds;
  Timer? _timer;
  double _previousVolume = 0.0;

  @override
  void initState() {
    super.initState();
    _setMaxVolume();
    _playNotificationSoundLoop();
    _startCountdown();
    _startVolumeMonitoring();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _audioPlayer.stop();
        _callNotTakenWebhook();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  Future<void> _callNotTakenWebhook() async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.notTakenReleaseOrderWebhook),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': widget.order.id,
          'order_number': widget.order.orderNumber,
          'rider_id': widget.order.riderId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Not taken webhook called successfully');
      } else {
        debugPrint('Not taken webhook failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling not taken webhook: $e');
    }
  }

  Future<void> _playNotificationSoundLoop() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));

      // Detener el sonido cuando se acabe el tiempo
      Future.delayed(Duration(seconds: AppConstants.orderTimeoutSeconds), () {
        if (mounted) {
          _audioPlayer.stop();
        }
      });
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  Future<void> _setMaxVolume() async {
    try {
      _previousVolume = await VolumeController().getVolume();
      VolumeController().setVolume(1.0);
    } catch (e) {
      debugPrint('Error setting max volume: $e');
    }
  }

  void _startVolumeMonitoring() {
    VolumeController().listener((volume) {
      if (volume < 1.0 && mounted) {
        VolumeController().setVolume(1.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    VolumeController().removeListener();
    VolumeController().setVolume(_previousVolume);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riderAsync = ref.watch(riderStateProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Deshabilitar el botón de back durante orden asignada
        if (didPop) return;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.white,
        child: Stack(
          children: [
            // Mapa con los tres marcadores
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: riderAsync.when(
                data: (rider) => OrderMapWidget(
                  order: widget.order,
                  riderLat: rider?.currentLat,
                  riderLng: rider?.currentLng,
                ),
                loading: () => OrderMapWidget(
                  order: widget.order,
                  riderLat: null,
                  riderLng: null,
                ),
                error: (_, __) => OrderMapWidget(
                  order: widget.order,
                  riderLat: null,
                  riderLng: null,
                ),
              ),
            ),

            // Contenido inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nuevo pedido',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                    
                      const SizedBox(height: 24),

                      // Total
                     /* Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '\$${widget.order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),*/

                      // Direcciones
                      _AddressRow(
                        icon: Icons.store,
                        title: widget.order.providerName ?? 'Pickup',
                        subtitle: widget.order.pickupAddress,
                      ),
                      if (widget.order.distanceToPickupKm != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_bike, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                _formatDistance(widget.order.distanceToPickupKm!),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.order.durationToPickupMin != null) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '~${widget.order.durationToPickupMin} min',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _AddressRow(
                        icon: Icons.person,
                        title: 'Entrega a ${widget.order.customerName}',
                        subtitle: widget.order.deliveryAddress,
                      ),
                      const SizedBox(height: 32),

                      // Botón aceptar
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: _isAccepting ? null : _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D7A6E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isAccepting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Aceptar pedido',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_countdown',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D7A6E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  Future<void> _handleAccept() async {
    setState(() => _isAccepting = true);
    _timer?.cancel();

    try {
      await ref.read(activeOrderProvider.notifier).acceptOrder(widget.order.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AddressRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

