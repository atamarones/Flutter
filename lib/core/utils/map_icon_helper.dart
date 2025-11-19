import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Helper para crear iconos personalizados para marcadores de Mapbox
/// Convierte iconos de Flutter a imágenes PNG para usarlos en el mapa
class MapIconHelper {
  /// Crea una imagen de icono para usar en Mapbox
  ///
  /// [icon] - El icono de Material Icons a usar
  /// [color] - Color del icono
  /// [size] - Tamaño del icono en pixels (default: 48)
  /// [backgroundColor] - Color de fondo circular (opcional)
  static Future<MbxImage> createIconImage({
    required IconData icon,
    required Color color,
    double size = 48,
    Color? backgroundColor,
  }) async {
    // Crear un PictureRecorder para dibujar
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Dibujar círculo de fondo si se proporciona
    if (backgroundColor != null) {
      paint.color = backgroundColor;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        paint,
      );
    }

    // Dibujar el icono
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.6, // 60% del tamaño total
        fontFamily: icon.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();

    // Centrar el icono
    final offset = Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    // Convertir a imagen
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return MbxImage(
      width: size.toInt(),
      height: size.toInt(),
      data: bytes,
    );
  }

  /// IDs de los iconos registrados en el mapa
  static const String riderIconId = 'rider-icon';
  static const String pickupIconId = 'pickup-icon';
  static const String deliveryIconId = 'delivery-icon';

  /// Colores para cada tipo de marcador (estilo Uber/DoorDash)
  static const Color riderColor = Color(0xFF0066FF); // Azul
  static const Color pickupColor = Color(0xFFFF5722); // Naranja
  static const Color deliveryColor = Color(0xFF4CAF50); // Verde

  /// Crear imagen del marcador del rider (repartidor)
  static Future<MbxImage> createRiderIcon() {
    return createIconImage(
      icon: Icons.directions_bike,
      color: Colors.white,
      backgroundColor: riderColor,
      size: 48,
    );
  }

  /// Crear imagen del marcador del pickup (tienda/restaurante)
  static Future<MbxImage> createPickupIcon() {
    return createIconImage(
      icon: Icons.store,
      color: Colors.white,
      backgroundColor: pickupColor,
      size: 48,
    );
  }

  /// Crear imagen del marcador del delivery (cliente)
  static Future<MbxImage> createDeliveryIcon() {
    return createIconImage(
      icon: Icons.person_pin_circle,
      color: Colors.white,
      backgroundColor: deliveryColor,
      size: 48,
    );
  }
}
