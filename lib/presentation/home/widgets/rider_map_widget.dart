import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../domain/entities/rider.dart';
import '../../../domain/entities/order.dart';
import '../../../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderMapWidget extends ConsumerStatefulWidget {
  final Rider rider;
  final Order? activeOrder;

  const RiderMapWidget({
    super.key,
    required this.rider,
    this.activeOrder,
  });

  @override
  ConsumerState<RiderMapWidget> createState() => _RiderMapWidgetState();
}

class _RiderMapWidgetState extends ConsumerState<RiderMapWidget> {
  MapboxMap? _mapboxMap;

  @override
  Widget build(BuildContext context) {
    if (widget.rider.currentLat == null || widget.rider.currentLng == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Ubicación no disponible'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MapWidget(
          key: ValueKey('map_${widget.rider.id}'),
          cameraOptions: CameraOptions(
            center: Point(
              coordinates: Position(
                widget.rider.currentLng!,
                widget.rider.currentLat!,
              ),
            ),
            zoom: 15.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          textureView: true,
          onMapCreated: _onMapCreated,
        ),
        
        // Overlay inferior con información
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.activeOrder == null) ...[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Buscando pedidos...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conectado',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.online,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pedido asignado',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              widget.activeOrder!.orderNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.activeOrder != null)
                        IconButton(
                          onPressed: _openNavigation,
                          icon: const Icon(Icons.navigation, color: AppColors.primary),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _addMarkers();
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null) return;

    final pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();

    // Marker del rider
    final riderMarker = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(
          widget.rider.currentLng!,
          widget.rider.currentLat!,
        ),
      ),
      iconImage: 'marker',
      iconSize: 1.5,
    );
    await pointAnnotationManager.create(riderMarker);

    // Marker del pickup si hay orden activa
    if (widget.activeOrder != null) {
      final pickupMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            widget.activeOrder!.pickupLng,
            widget.activeOrder!.pickupLat,
          ),
        ),
        iconImage: 'marker',
        iconSize: 1.2,
      );
      await pointAnnotationManager.create(pickupMarker);

      await _fitBounds();
    }
  }

  Future<void> _fitBounds() async {
    if (_mapboxMap == null || widget.activeOrder == null) return;

    final bounds = CoordinateBounds(
      southwest: Point(
        coordinates: Position(
          widget.rider.currentLng! < widget.activeOrder!.pickupLng
              ? widget.rider.currentLng!
              : widget.activeOrder!.pickupLng,
          widget.rider.currentLat! < widget.activeOrder!.pickupLat
              ? widget.rider.currentLat!
              : widget.activeOrder!.pickupLat,
        ),
      ),
      northeast: Point(
        coordinates: Position(
          widget.rider.currentLng! > widget.activeOrder!.pickupLng
              ? widget.rider.currentLng!
              : widget.activeOrder!.pickupLng,
          widget.rider.currentLat! > widget.activeOrder!.pickupLat
              ? widget.rider.currentLat!
              : widget.activeOrder!.pickupLat,
        ),
      ),
      infiniteBounds: false,
    );

    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 100, left: 50, bottom: 250, right: 50),
      null,
      null,
      null,
      null,
    );

    await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1000));
  }

  Future<void> _openNavigation() async {
    if (widget.activeOrder == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.activeOrder!.pickupLat},${widget.activeOrder!.pickupLng}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}