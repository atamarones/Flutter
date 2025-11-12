import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../data/repositories/rider_repository.dart';
import '../../../domain/entities/rider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/foreground_tracking_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/app_logger.dart';

export '../../../core/services/location_service.dart';

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return RiderRepository();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentRiderProvider = FutureProvider<Rider?>((ref) async {
  final user = ref.watch(authRepositoryProvider).getCurrentUser();
  if (user == null) return null;
  
  return await ref.read(riderRepositoryProvider).getRiderByUserId(user.id);
});

class RiderStateNotifier extends AsyncNotifier<Rider?> {
  late RiderRepository _riderRepository;
  late LocationService _locationService;
  late String _userId;
  Timer? _heartbeatTimer;
  Timer? _refreshTimer;

  @override
  Future<Rider?> build() async {
    final user = ref.read(authRepositoryProvider).getCurrentUser();
    if (user == null) throw Exception('User not authenticated');
    
    _userId = user.id;
    _riderRepository = ref.read(riderRepositoryProvider);
    _locationService = ref.read(locationServiceProvider);
    
    ref.onDispose(() {
      _stopServices();
    });
    
    return await _loadRider();
  }

  Future<Rider?> _loadRider() async {
    try {
      final rider = await _riderRepository.getRiderByUserId(_userId);
      if (rider == null) {
        debugPrint('Rider not found for user: $_userId');
      }
      return rider;
    } catch (e) {
      // Solo loguear errores que no sean de conexión
      if (!e.toString().contains('SocketException') &&
          !e.toString().contains('Failed host lookup')) {
        debugPrint('Error loading rider: $e');
      }
      // Si hay error de red, mantener el estado actual del rider
      return state.value;
    }
  }

  Future<void> toggleStatus() async {
    final rider = state.value;
    if (rider == null) return;

    if (rider.status == RiderStatus.offline) {
      final hasPermission = await _locationService.checkPermissions();
      if (!hasPermission) {
        state = AsyncValue.error(
          'Debes permitir el acceso a la ubicación para conectarte',
          StackTrace.current,
        );
        return;
      }
    }

    final newStatus = rider.status == RiderStatus.online
        ? RiderStatus.offline
        : RiderStatus.online;

    try {
      await _riderRepository.updateStatus(rider.id, newStatus);
      state = AsyncValue.data(rider.copyWith(status: newStatus));

      // Guardar estado del rider para el foreground service
      await ForegroundTrackingService.saveRiderStatus(newStatus.toString().split('.').last);

      if (newStatus == RiderStatus.online) {
        // Guardar token actualizado antes de iniciar servicios
        await _refreshAndSaveToken();
        await _startServices();
      } else {
        await _stopServices();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _refreshAndSaveToken() async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        await ForegroundTrackingService.saveToken(session.accessToken);
      }
    } catch (e) {
      AppLogger.error('[RIDER] Error refreshing token', error: e);
    }
  }

  Future<void> _startServices() async {
    // Iniciar el Foreground Service (este maneja heartbeat y location en background)
    final started = await ForegroundTrackingService.start();
    if (!started) {
      AppLogger.error('[RIDER] Error iniciando Foreground Service');
    }

    // Iniciar tracking de ubicación en la app para UI en tiempo real
    _locationService.startLocationUpdates((position) async {
      try {
        // Actualizar ubicación en el backend
        await _riderRepository.updateLocation(
          position.latitude,
          position.longitude,
        );

        // Actualizar estado local para el UI
        final rider = state.value;
        if (rider != null) {
          state = AsyncValue.data(rider.copyWith(
            currentLat: position.latitude,
            currentLng: position.longitude,
          ));
        }
      } catch (e) {
        AppLogger.error('[RIDER] Location update error', error: e);
      }
    });

    // Heartbeat desde la app (adicional al del Foreground Service)
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          await _refreshAndSaveToken();
          await _riderRepository.sendHeartbeat();
        } catch (e) {
          AppLogger.error('[RIDER] Heartbeat error', error: e);
        }
      },
    );

    // Refrescar datos del rider periódicamente
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        final updated = await _loadRider();
        if (updated != null) {
          state = AsyncValue.data(updated);
        }
      },
    );
  }

  Future<void> _stopServices() async {
    // Detener Foreground Service
    await ForegroundTrackingService.stop();

    // Detener servicios de la app
    _locationService.stopLocationUpdates();
    _heartbeatTimer?.cancel();
    _refreshTimer?.cancel();
  }
}

final riderStateProvider = AsyncNotifierProvider<RiderStateNotifier, Rider?>(() {
  return RiderStateNotifier();
});