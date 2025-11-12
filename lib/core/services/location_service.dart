import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LocationService {
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  bool _isWakelockEnabled = false;

  Future<bool> checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  void startLocationUpdates(Function(Position) onLocationUpdate) async {
    _locationTimer?.cancel();

    // Habilitar WakeLock para evitar que el dispositivo entre en suspensión
    if (!_isWakelockEnabled) {
      try {
        await WakelockPlus.enable();
        _isWakelockEnabled = true;
        debugPrint('WakeLock enabled - dispositivo se mantendrá activo');
      } catch (e) {
        debugPrint('Error habilitando WakeLock: $e');
      }
    }

    // Obtener ubicación inicial inmediatamente
    final initialPosition = await getCurrentPosition();
    if (initialPosition != null) {
      onLocationUpdate(initialPosition);
    }

    // Continuar con actualizaciones periódicas
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        final position = await getCurrentPosition();
        if (position != null) {
          onLocationUpdate(position);
        }
      },
    );
  }

  void stopLocationUpdates() async {
    _locationTimer?.cancel();
    _positionStream?.cancel();

    // Deshabilitar WakeLock cuando se detienen las actualizaciones
    if (_isWakelockEnabled) {
      try {
        await WakelockPlus.disable();
        _isWakelockEnabled = false;
        debugPrint('WakeLock disabled - dispositivo puede entrar en suspensión');
      } catch (e) {
        debugPrint('Error deshabilitando WakeLock: $e');
      }
    }
  }

  // Método para verificar el estado del WakeLock
  Future<bool> isWakelockEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      debugPrint('Error verificando WakeLock: $e');
      return false;
    }
  }
}