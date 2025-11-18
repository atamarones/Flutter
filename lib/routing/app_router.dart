import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/auth/screens/splash_screen.dart';
import '../presentation/auth/screens/login_screen.dart';
import '../presentation/auth/screens/forgot_password_screen.dart';
import '../presentation/home/screens/home_screen.dart';
import '../presentation/profile/screens/profile_screen.dart';
import '../presentation/order/screens/order_history_screen.dart';
import '../presentation/settings/screens/settings_screen.dart';
import '../presentation/auth/providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final session = authState.value?.session;
      final isAuthenticated = session != null;

      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isGoingToForgotPassword = state.matchedLocation == '/forgot-password';

      // Si NO está autenticado (incluso si está loading), redirigir a login
      // Esto previene que logout → splash (queremos logout → login directo)
      if (!isAuthenticated && !isGoingToLogin && !isGoingToForgotPassword) {
        // EXCEPCIÓN: Si está en splash y cargando, permitir (primera carga de app)
        if (isGoingToSplash && isAuthLoading) {
          return null;
        }
        return '/login';
      }

      // Si está autenticado e intenta ir a login/splash, redirigir a home
      if (isAuthenticated && (isGoingToLogin || isGoingToSplash || isGoingToForgotPassword)) {
        return '/home';
      }

      // En cualquier otro caso, permitir la navegación
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/history', builder: (context, state) => const OrderHistoryScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});

// Helper para refrescar el router cuando cambia el auth state
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}