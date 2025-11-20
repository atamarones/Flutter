import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _iconsRegistered = false;

  // IDs de los iconos
  static const String _riderIconId = 'rider-icon';
  static const String _pickupIconId = 'pickup-icon';
  static const String _deliveryIconId = 'delivery-icon';

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

    try {
      if (_deliveryMarker != null) {
        await _annotationManager!.delete(_deliveryMarker!);
        _deliveryMarker = null;
      }
    } catch (e) {
      debugPrint('Error deleting delivery marker: $e');
      _deliveryMarker = null;
    }

    // Recrear marcadores
    await _addMarkers();
    await _fitBounds();
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null || _annotationManager == null || !_iconsRegistered) return;

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
          iconImage: _riderIconId,
          iconSize: 0.5,
        ),
      );
    }

    // Marcador del pickup (store)
    _pickupMarker = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            widget.order.pickupLng,
            widget.order.pickupLat,
          ),
        ),
        iconImage: _pickupIconId,
        iconSize: 0.5,
      ),
    );

    // Marcador del delivery (customer)
    _deliveryMarker = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            widget.order.deliveryLng,
            widget.order.deliveryLat,
          ),
        ),
        iconImage: _deliveryIconId,
        iconSize: 0.5,
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
