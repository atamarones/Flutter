import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../data/repositories/rider_repository.dart';
import '../../../domain/entities/rider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/background_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

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

      // Guardar estado del rider para servicios en background
      await BackgroundService.saveRiderStatus(newStatus.toString().split('.').last);

      if (newStatus == RiderStatus.online) {
        // Guardar token actualizado antes de iniciar servicios
        await _refreshAndSaveToken();
        _startServices();
      } else {
        _stopServices();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _refreshAndSaveToken() async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        await BackgroundService.saveToken(session.accessToken);
        debugPrint('Token saved: ${session.accessToken.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
  }

  void _startServices() {
    debugPrint('🚀 INICIANDO SERVICIOS DE TRACKING 🚀');

    // Enviar primer heartbeat inmediatamente
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await _refreshAndSaveToken();
        await _riderRepository.sendHeartbeat();
        debugPrint('✅ Primer heartbeat enviado');
      } catch (e) {
        debugPrint('Initial heartbeat error: $e');
      }
    });

    _locationService.startLocationUpdates((position) async {
      try {
        debugPrint('📍 UBICACIÓN ACTUALIZADA: Lat ${position.latitude}, Lng ${position.longitude}');

        await _riderRepository.updateLocation(
          position.latitude,
          position.longitude,
        );

        final rider = state.value;
        if (rider != null) {
          state = AsyncValue.data(rider.copyWith(
            currentLat: position.latitude,
            currentLng: position.longitude,
          ));
        }
      } catch (e) {
        debugPrint('Location update error: $e');
      }
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          await _refreshAndSaveToken();
          await _riderRepository.sendHeartbeat();
          debugPrint('💓 Heartbeat enviado');
        } catch (e) {
          debugPrint('Heartbeat error: $e');
        }
      },
    );

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        final updated = await _loadRider();
        if (updated != null) {
          state = AsyncValue.data(updated);
          debugPrint('🔄 Datos del rider actualizados');
        }
      },
    );

    // Iniciar servicios de background para mantener ubicación activa
    BackgroundService.startHeartbeat();
    BackgroundService.startLocationTracking();
    debugPrint('📡 Servicios de background iniciados (heartbeat + location tracking)');
  }

  void _stopServices() {
    debugPrint('🛑 DETENIENDO SERVICIOS DE TRACKING 🛑');

    _locationService.stopLocationUpdates();
    _heartbeatTimer?.cancel();
    _refreshTimer?.cancel();

    // Detener todos los servicios de background
    BackgroundService.stopHeartbeat();
    BackgroundService.stopLocationTracking();
    debugPrint('📡 Servicios de background detenidos');
  }
}

final riderStateProvider = AsyncNotifierProvider<RiderStateNotifier, Rider?>(() {
  return RiderStateNotifier();
});