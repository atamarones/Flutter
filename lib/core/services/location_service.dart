import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

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
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  void startLocationUpdates(Function(Position) onLocationUpdate) {
    _locationTimer?.cancel();
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

  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
  }
}