import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../domain/entities/order.dart';

/// Mapa que muestra SOLO rider y punto de pickup
/// Usado cuando rider va camino a recoger el pedido
class PickupRouteMapWidget extends ConsumerStatefulWidget {
  final Order order;
  final double? riderLat;
  final double? riderLng;

  const PickupRouteMapWidget({
    super.key,
    required this.order,
    this.riderLat,
    this.riderLng,
  });

  @override
  ConsumerState<PickupRouteMapWidget> createState() => _PickupRouteMapWidgetState();
}

class _PickupRouteMapWidgetState extends ConsumerState<PickupRouteMapWidget> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  PointAnnotation? _riderMarker;
  PointAnnotation? _pickupMarker;
  bool _iconsRegistered = false;

  // IDs de los iconos
  static const String _riderIconId = 'rider-icon';
  static const String _pickupIconId = 'pickup-icon';

  @override
  void didUpdateWidget(PickupRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.riderLat != oldWidget.riderLat || widget.riderLng != oldWidget.riderLng) {
      _updateMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerLat = widget.riderLat ?? widget.order.pickupLat;
    final centerLng = widget.riderLng ?? widget.order.pickupLng;

    return MapWidget(
      key: ValueKey('pickup_route_map_${widget.order.id}'),
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 14.0,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      textureView: true,
      onMapCreated: _onMapCreated,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    if (!mounted) return;
    _mapboxMap = mapboxMap;

    try {
      _annotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      await _registerIcons();
      await _addMarkers();
      await _fitBounds();
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  Future<void> _registerIcons() async {
    if (_mapboxMap == null || _iconsRegistered) return;

    try {
      // Cargar iconos desde assets
      final riderBytes = await rootBundle.load('assets/icons/rider_marker.png');
      final pickupBytes = await rootBundle.load('assets/icons/pickup_marker.png');

      final riderImage = MbxImage(
        width: 96,
        height: 96,
        data: riderBytes.buffer.asUint8List(),
      );
      final pickupImage = MbxImage(
        width: 96,
        height: 96,
        data: pickupBytes.buffer.asUint8List(),
      );

      // Registrar iconos en el mapa
      await _mapboxMap!.style.addStyleImage(
        _riderIconId,
        1.0,
        riderImage,
        false,
        [],
        [],
        null,
      );
      await _mapboxMap!.style.addStyleImage(
        _pickupIconId,
        1.0,
        pickupImage,
        false,
        [],
        [],
        null,
      );

      _iconsRegistered = true;
    } catch (e) {
      debugPrint('Error registering map icons: $e');
    }
  }

  Future<void> _updateMarkers() async {
    if (_mapboxMap == null || _annotationManager == null) return;

    _riderMarker?.let((marker) => _annotationManager!.delete(marker));
    _pickupMarker?.let((marker) => _annotationManager!.delete(marker));
    _riderMarker = null;
    _pickupMarker = null;

    await _addMarkers();
    await _fitBounds();
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null || _annotationManager == null || !_iconsRegistered) return;

    // Marcador del rider (tu ubicación)
    if (widget.riderLat != null && widget.riderLng != null) {
      _riderMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(widget.riderLng!, widget.riderLat!)),
          iconImage: _riderIconId,
          iconSize: 0.5,
        ),
      );
    }

    // Marcador del pickup (restaurante/tienda)
    _pickupMarker = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(widget.order.pickupLng, widget.order.pickupLat)),
        iconImage: _pickupIconId,
        iconSize: 0.5,
      ),
    );
  }

  Future<void> _fitBounds() async {
    if (_mapboxMap == null) return;

    final List<Position> positions = [
      Position(widget.order.pickupLng, widget.order.pickupLat),
    ];

    if (widget.riderLat != null && widget.riderLng != null) {
      positions.add(Position(widget.riderLng!, widget.riderLat!));
    }

    if (positions.length < 2) return;

    num minLng = positions.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    num maxLng = positions.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
    num minLat = positions.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    num maxLat = positions.map((p) => p.lat).reduce((a, b) => a > b ? a : b);

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 80, left: 60, bottom: 80, right: 60),
      null, null, null, null,
    );

    await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1000));
  }
}

extension _OptionExtension<T> on T? {
  void let(void Function(T) block) {
    final self = this;
    if (self != null) block(self);
  }
}
