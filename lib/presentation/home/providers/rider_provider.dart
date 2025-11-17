import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Retry mechanism para obtener el usuario (soluciona race condition después del login)
    User? user;
    int retries = 0;
    const maxRetries = 5;

    AppLogger.info('[RIDER_PROVIDER] Iniciando build - Obteniendo usuario autenticado');

    while (user == null && retries < maxRetries) {
      user = ref.read(authRepositoryProvider).getCurrentUser();
      if (user == null) {
        AppLogger.warning('[RIDER_PROVIDER] Usuario no disponible, retry ${retries + 1}/$maxRetries');
        await Future.delayed(Duration(milliseconds: 200 * (retries + 1)));
        retries++;
      }
    }

    if (user == null) {
      AppLogger.error('[RIDER_PROVIDER] No se pudo obtener usuario después de $maxRetries intentos');
      throw Exception('User not authenticated. Por favor, cierra e inicia sesión nuevamente.');
    }

    AppLogger.info('[RIDER_PROVIDER] Usuario autenticado: ${user.email} (ID: ${user.id})');

    _userId = user.id;
    _riderRepository = ref.read(riderRepositoryProvider);
    _locationService = ref.read(locationServiceProvider);

    // Escuchar cambios en el estado de autenticación
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((authState) {
        final currentUser = authState.session?.user;
        // Si el usuario cambió o se deslogueó, invalidar este provider
        if (currentUser == null || currentUser.id != _userId) {
          ref.invalidateSelf();
        }
      });
    });

    ref.onDispose(() {
      _stopServices();
    });

    return await _loadRider();
  }

  Future<Rider?> _loadRider() async {
    try {
      AppLogger.info('[RIDER_PROVIDER] Cargando rider desde BD para user_id: $_userId');
      final rider = await _riderRepository.getRiderByUserId(_userId);

      if (rider == null) {
        AppLogger.error('[RIDER_PROVIDER] No se encontró rider en la BD para user_id: $_userId');
        final errorMsg = 'No se encontró un perfil de repartidor asociado a esta cuenta.\n\n'
            'User ID: $_userId\n\n'
            'Por favor, contacta al administrador para verificar que tu cuenta '
            'esté correctamente configurada en el sistema.';
        throw Exception(errorMsg);
      }

      AppLogger.info('[RIDER_PROVIDER] Rider cargado exitosamente: ${rider.fullName} (ID: ${rider.id})');
      return rider;
    } catch (e) {
      // Solo loguear errores que no sean de conexión
      if (!e.toString().contains('SocketException') &&
          !e.toString().contains('Failed host lookup')) {
        AppLogger.error('[RIDER_PROVIDER] Error cargando rider', error: e);
      }
      // Si es el primer intento de carga (no hay estado previo), propagar el error
      if (state.value == null) {
        rethrow;
      }
      // Si hay error de red y ya tenemos datos, mantener el estado actual del rider
      AppLogger.warning('[RIDER_PROVIDER] Error de red, manteniendo estado actual');
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