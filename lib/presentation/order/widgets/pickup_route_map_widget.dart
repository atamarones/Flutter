import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../domain/entities/order.dart';

/// Mapa que muestra rider y el destino según el estado de la orden:
/// - Si está ACCEPTED: muestra rider + pickup (va a recoger)
/// - Si está IN_PROGRESS: muestra rider + delivery (va a entregar)
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
  PointAnnotation? _destinationMarker;
  bool _iconsRegistered = false;
  OrderStatus? _lastOrderStatus;

  // IDs de los iconos
  static const String _riderIconId = 'rider-icon';
  static const String _pickupIconId = 'pickup-icon';
  static const String _deliveryIconId = 'delivery-icon';

  @override
  void didUpdateWidget(PickupRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SOLO actualizar si cambió el estado de la orden (de accepted a in_progress)
    // O si cambió la posición del rider (cuando se captura nueva foto en cambio de estado)
    final hasStatusChanged = widget.order.status != oldWidget.order.status;
    final hasRiderPositionChanged =
      widget.riderLat != oldWidget.riderLat ||
      widget.riderLng != oldWidget.riderLng;

    if (hasStatusChanged) {
      _updateAllMarkers();
    } else if (hasRiderPositionChanged) {
      _updateRiderMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoingToPickup = widget.order.status == OrderStatus.accepted;
    final destLat = isGoingToPickup ? widget.order.pickupLat : widget.order.deliveryLat;
    final destLng = isGoingToPickup ? widget.order.pickupLng : widget.order.deliveryLng;
    final centerLat = widget.riderLat ?? destLat;
    final centerLng = widget.riderLng ?? destLng;

    return MapWidget(
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
      // Cargar iconos desde assets como ByteData
      final riderBytes = await rootBundle.load('assets/icons/rider_marker.png');
      final pickupBytes = await rootBundle.load('assets/icons/pickup_marker.png');
      final deliveryBytes = await rootBundle.load('assets/icons/delivery_marker.png');

      // Decodificar imágenes para obtener dimensiones reales
      final riderCodec = await instantiateImageCodec(riderBytes.buffer.asUint8List());
      final riderFrame = await riderCodec.getNextFrame();
      final riderImage = riderFrame.image;

      final pickupCodec = await instantiateImageCodec(pickupBytes.buffer.asUint8List());
      final pickupFrame = await pickupCodec.getNextFrame();
      final pickupImage = pickupFrame.image;

      final deliveryCodec = await instantiateImageCodec(deliveryBytes.buffer.asUint8List());
      final deliveryFrame = await deliveryCodec.getNextFrame();
      final deliveryImage = deliveryFrame.image;

      // Convertir a bytes en formato correcto
      final riderData = await riderImage.toByteData(format: ImageByteFormat.png);
      final pickupData = await pickupImage.toByteData(format: ImageByteFormat.png);
      final deliveryData = await deliveryImage.toByteData(format: ImageByteFormat.png);

      // Crear MbxImage con dimensiones reales
      final riderMbx = MbxImage(
        width: riderImage.width,
        height: riderImage.height,
        data: riderData!.buffer.asUint8List(),
      );
      final pickupMbx = MbxImage(
        width: pickupImage.width,
        height: pickupImage.height,
        data: pickupData!.buffer.asUint8List(),
      );
      final deliveryMbx = MbxImage(
        width: deliveryImage.width,
        height: deliveryImage.height,
        data: deliveryData!.buffer.asUint8List(),
      );

      // Registrar iconos en el mapa
      await _mapboxMap!.style.addStyleImage(
        _riderIconId,
        1.0,
        riderMbx,
        false,
        [],
        [],
        null,
      );
      await _mapboxMap!.style.addStyleImage(
        _pickupIconId,
        1.0,
        pickupMbx,
        false,
        [],
        [],
        null,
      );
      await _mapboxMap!.style.addStyleImage(
        _deliveryIconId,
        1.0,
        deliveryMbx,
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

  /// Actualiza la posición del rider sin cambiar el destino
  Future<void> _updateRiderMarker() async {
    if (_mapboxMap == null || _annotationManager == null || !_iconsRegistered) return;
    if (widget.riderLat == null || widget.riderLng == null) return;

    try {
      // Eliminar marcador anterior del rider si existe
      if (_riderMarker != null) {
        await _annotationManager!.delete(_riderMarker!);
      }

      // Crear nuevo marcador del rider con la posición actualizada
      _riderMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(widget.riderLng!, widget.riderLat!)),
          iconImage: _riderIconId,
          iconSize: 0.5,
        ),
      );

      // Reajustar vista del mapa para mostrar ambos puntos
      await _fitBounds();
    } catch (e) {
      debugPrint('Error updating rider marker: $e');
    }
  }

  /// Actualiza AMBOS marcadores (rider + destino) cuando cambia el status de la orden
  Future<void> _updateAllMarkers() async {
    if (_mapboxMap == null || _annotationManager == null || !_iconsRegistered) return;

    final isGoingToPickup = widget.order.status == OrderStatus.accepted;

    try {
      // 1. Actualizar marcador del RIDER con la nueva posición capturada
      if (widget.riderLat != null && widget.riderLng != null) {
        if (_riderMarker != null) {
          await _annotationManager!.delete(_riderMarker!);
        }
        _riderMarker = await _annotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(widget.riderLng!, widget.riderLat!)),
            iconImage: _riderIconId,
            iconSize: 0.5,
          ),
        );
      }

      // 2. Actualizar marcador del DESTINO según el nuevo estado
      if (_destinationMarker != null) {
        await _annotationManager!.delete(_destinationMarker!);
        _destinationMarker = null;
      }

      if (isGoingToPickup) {
        _destinationMarker = await _annotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(widget.order.pickupLng, widget.order.pickupLat)),
            iconImage: _pickupIconId,
            iconSize: 0.5,
          ),
        );
      } else {
        _destinationMarker = await _annotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(widget.order.deliveryLng, widget.order.deliveryLat)),
            iconImage: _deliveryIconId,
            iconSize: 0.5,
          ),
        );
      }

      _lastOrderStatus = widget.order.status;

      // Reajustar vista del mapa para mostrar ambos puntos
      await _fitBounds();
    } catch (e) {
      debugPrint('Error updating markers: $e');
    }
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null || _annotationManager == null || !_iconsRegistered) return;

    final isGoingToPickup = widget.order.status == OrderStatus.accepted;

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

    // Marcador del destino (pickup si va a recoger, delivery si va a entregar)
    if (isGoingToPickup) {
      _destinationMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(widget.order.pickupLng, widget.order.pickupLat)),
          iconImage: _pickupIconId,
          iconSize: 0.5,
        ),
      );
    } else {
      _destinationMarker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(widget.order.deliveryLng, widget.order.deliveryLat)),
          iconImage: _deliveryIconId,
          iconSize: 0.5,
        ),
      );
    }

    // Guardar el estado inicial
    _lastOrderStatus = widget.order.status;
  }

  Future<void> _fitBounds() async {
    if (_mapboxMap == null) return;

    final isGoingToPickup = widget.order.status == OrderStatus.accepted;
    final destLat = isGoingToPickup ? widget.order.pickupLat : widget.order.deliveryLat;
    final destLng = isGoingToPickup ? widget.order.pickupLng : widget.order.deliveryLng;

    final List<Position> positions = [
      Position(destLng, destLat),
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

