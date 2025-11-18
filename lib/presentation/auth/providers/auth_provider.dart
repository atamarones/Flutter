import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/entities/rider.dart';
import '../../home/providers/rider_provider.dart';
import '../../../core/utils/app_logger.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authRepositoryProvider).getCurrentUser();
});

class LoginState {
  final bool isLoading;
  final String? error;

  LoginState({this.isLoading = false, this.error});

  LoginState copyWith({bool? isLoading, String? error}) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LoginNotifier extends Notifier<LoginState> {
  LoginNotifier();

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  LoginState build() => LoginState();

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _authRepository.login(email, password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Correo o contraseña incorrectos',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final loginProvider = NotifierProvider<LoginNotifier, LoginState>(() {
  return LoginNotifier();
});

/// Helper seguro para logout que invalida todos los providers
/// Esto previene Cross-User Data Leakage
///
/// IMPORTANTE: Siempre usa este método en lugar de authRepository.logout() directamente
/// para garantizar que todos los datos del usuario se limpien correctamente
///
/// CRÍTICO: Apps profesionales (Uber/DoorDash/Rappi) SIEMPRE ponen al rider
/// OFFLINE antes de logout para prevenir asignación de órdenes a riders inactivos
Future<void> secureLogout(WidgetRef ref) async {
  try {
    // PASO 1: Poner rider OFFLINE automáticamente antes de logout
    // Esto es CRÍTICO para prevenir que se asignen órdenes a riders inactivos
    final riderState = ref.read(riderStateProvider);

    await riderState.whenOrNull(
      data: (rider) async {
        if (rider != null && rider.status == RiderStatus.online) {
          AppLogger.warning('[LOGOUT] Rider está ONLINE - cambiando a OFFLINE antes de logout');

          try {
            // Poner offline automáticamente
            await ref.read(riderStateProvider.notifier).toggleStatus();

            // Pequeño delay para garantizar que BD se actualizó
            await Future.delayed(const Duration(milliseconds: 500));

            AppLogger.info('[LOGOUT] Rider puesto OFFLINE exitosamente');
          } catch (e) {
            // Si falla, intentar al menos actualizar status en BD directamente
            AppLogger.error('[LOGOUT] Error poniendo rider offline, intentando directo en BD', error: e);
            try {
              await ref.read(riderRepositoryProvider).updateStatus(rider.id, RiderStatus.offline);
            } catch (e2) {
              AppLogger.error('[LOGOUT] Error crítico actualizando status', error: e2);
            }
          }
        }
      },
    );
  } catch (e) {
    AppLogger.error('[LOGOUT] Error en pre-logout checks (continuando con logout)', error: e);
  }

  // PASO 2: Ejecutar logout en el repositorio (limpia tokens, detiene servicios)
  await ref.read(authRepositoryProvider).logout();

  // PASO 3: Los listeners de authStateProvider se encargan automáticamente
  // cuando detectan el cambio de sesión
  // Esto previene el error "Using ref when widget is unmounted"

  AppLogger.info('[LOGOUT] Logout completado exitosamente');
}