import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/auth_repository.dart';

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
Future<void> secureLogout(WidgetRef ref) async {
  // 1. Ejecutar logout en el repositorio (limpia tokens, detiene servicios)
  await ref.read(authRepositoryProvider).logout();

  // 2. Invalidar TODOS los providers de la aplicación
  // Esto es CRÍTICO para prevenir Cross-User Data Leakage
  // Los datos del usuario anterior se eliminan completamente de memoria
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserProvider);
  ref.invalidate(loginProvider);

  // NOTA: No necesitamos invalidar riderStateProvider y activeOrderProvider
  // explícitamente porque ahora tienen listeners de authStateProvider que
  // se invalidan automáticamente cuando el usuario cambia
}