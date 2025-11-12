import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../domain/entities/order.dart';

class OrderMapWidget extends ConsumerStatefulWidget {
  final Order order;
  final double? riderLat;
  final double? riderLng;

  const OrderMapWidget({
    super.key,
    required this.order,
    this.riderLat,
    this.riderLng,
  });

  @override
  ConsumerState<OrderMapWidget> createState() => _OrderMapWidgetState();
}

class _OrderMapWidgetState extends ConsumerState<OrderMapWidget> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  PointAnnotation? _riderMarker;
  PointAnnotation? _pickupMarker;
  PointAnnotation? _deliveryMarker;

  @override
  void didUpdateWidget(OrderMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Actualizar marcadores si cambian los datos
    if (widget.riderLat != oldWidget.riderLat ||
        widget.riderLng != oldWidget.riderLng ||
        widget.order.id != oldWidget.order.id) {
      _updateMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el centro entre pickup y delivery
    final centerLat = (widget.order.pickupLat + widget.order.deliveryLat) / 2;
    final centerLng = (widget.order.pickupLng + widget.order.deliveryLng) / 2;

    return MapWidget(
      key: ValueKey('order_map_${widget.order.id}'),
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(centerLng, centerLat),
        ),
        zoom: 13.0,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      textureView: true,
      onMapCreated: _onMapCreated,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    await _addMarkers();
    await _fitBounds();
  }

  Future<void> _updateMarkers() async {
    if (_mapboxMap == null || _annotationManager == null) return;

    // Limpiar marcadores existentes
    if (_riderMarker != null) {
      await _annotationManager!.delete(_riderMarker!);
      _riderMarker = null;
    }
    if (_pickupMarker != null) {
      await _annotationManager!.delete(_pickupMarker!);
      _pickupMarker = null;
    }
    if (_deliveryMarker != null) {
      await _annotationManager!.delete(_deliveryMarker!);
      _deliveryMarker = null;
    }

    // Recrear marcadores
    await _addMarkers();
    await _fitBounds();
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null || _annotationManager == null) return;

    // Marcador del rider (si está disponible)
    if (widget.riderLat != null && widget.riderLng != null) {
      _riderMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              widget.riderLng!,
              widget.riderLat!,
            ),
          ),
          iconImage: 'marker',
          iconSize: 1.5,
          iconColor: const Color(0xFF0066FF).toARGB32(), // Azul para el rider
        ),
      );
    }

    // Marcador del pickup (store) - Rojo
    _pickupMarker = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            widget.order.pickupLng,
            widget.order.pickupLat,
          ),
        ),
        iconImage: 'marker',
        iconSize: 1.5,
        iconColor: const Color(0xFFFF5722).toARGB32(), // Rojo/Naranja para pickup
      ),
    );

    // Marcador del delivery (user) - Verde
    _deliveryMarker = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            widget.order.deliveryLng,
            widget.order.deliveryLat,
          ),
        ),
        iconImage: 'marker',
        iconSize: 1.5,
        iconColor: const Color(0xFF4CAF50).toARGB32(), // Verde para delivery
      ),
    );
  }

  Future<void> _fitBounds() async {
    if (_mapboxMap == null) return;

    // Crear lista de coordenadas a incluir en los bounds
    final List<Position> positions = [
      Position(widget.order.pickupLng, widget.order.pickupLat),
      Position(widget.order.deliveryLng, widget.order.deliveryLat),
    ];

    // Añadir posición del rider si está disponible
    if (widget.riderLat != null && widget.riderLng != null) {
      positions.add(Position(widget.riderLng!, widget.riderLat!));
    }

    // Calcular bounds mínimos y máximos
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
      MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
      null,
      null,
      null,
      null,
    );

    await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1000));
  }
}
