import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../domain/entities/rider.dart';
import '../../../domain/entities/order.dart';
import '../../../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rider_marker_widget.dart';

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
  PointAnnotationManager? _annotationManager;
  PointAnnotation? _riderMarker;
  PointAnnotation? _pickupMarker;
  double? _lastLat;
  double? _lastLng;

  @override
  void didUpdateWidget(RiderMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detectar cambios en la ubicación del rider
    if (widget.rider.currentLat != oldWidget.rider.currentLat ||
        widget.rider.currentLng != oldWidget.rider.currentLng) {
      _updateRiderPosition();
    }

    // Detectar cambios en la orden activa
    if (widget.activeOrder != oldWidget.activeOrder) {
      _updateMarkers();
    }
  }

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
            zoom: 17.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          textureView: true,
          onMapCreated: _onMapCreated,
        ),

        // Marcador animado personalizado para el rider
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 40), // Ajustar para centrar en el punto
            child: const RiderMarkerWidget(
              size: 100,
              color: Color(0xFF0066FF),
            ),
          ),
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
    _annotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    await _addMarkers();
  }

  Future<void> _updateRiderPosition() async {
    if (_mapboxMap == null ||
        _annotationManager == null ||
        widget.rider.currentLat == null ||
        widget.rider.currentLng == null) {
      return;
    }

    // Evitar actualizaciones redundantes
    if (_lastLat == widget.rider.currentLat &&
        _lastLng == widget.rider.currentLng) {
      return;
    }

    _lastLat = widget.rider.currentLat;
    _lastLng = widget.rider.currentLng;

    // No crear marcador del rider aquí - usamos el overlay animado personalizado
    // Solo mantener el marcador del pickup si existe

    // Animar la cámara hacia la nueva posición (solo si no hay orden activa)
    if (widget.activeOrder == null) {
      final newCamera = CameraOptions(
        center: Point(
          coordinates: Position(
            widget.rider.currentLng!,
            widget.rider.currentLat!,
          ),
        ),
        zoom: 17.0,
      );

      await _mapboxMap!.flyTo(newCamera, MapAnimationOptions(duration: 1500));
    } else {
      // Si hay orden activa, ajustar bounds para mostrar ambos puntos
      await _fitBounds();
    }
  }

  Future<void> _updateMarkers() async {
    if (_mapboxMap == null || _annotationManager == null) return;

    // Limpiar marcadores existentes de forma segura
    try {
      if (_riderMarker != null) {
        await _annotationManager!.delete(_riderMarker!);
        _riderMarker = null;
      }
    } catch (e) {
      debugPrint('Error deleting rider marker: $e');
      _riderMarker = null;
    }

    try {
      if (_pickupMarker != null) {
        await _annotationManager!.delete(_pickupMarker!);
        _pickupMarker = null;
      }
    } catch (e) {
      debugPrint('Error deleting pickup marker: $e');
      _pickupMarker = null;
    }

    // Recrear marcadores
    await _addMarkers();
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null || _annotationManager == null) return;

    // No crear marcador del rider - usamos el overlay animado personalizado en el centro
    _lastLat = widget.rider.currentLat;
    _lastLng = widget.rider.currentLng;

    // Marker del pickup si hay orden activa
    if (widget.activeOrder != null) {
      _pickupMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              widget.activeOrder!.pickupLng,
              widget.activeOrder!.pickupLat,
            ),
          ),
          iconImage: 'marker',
          iconSize: 1.5,
          iconColor: Colors.red.toARGB32(),
        ),
      );

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