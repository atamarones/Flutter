import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../routing/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  /// Verifica el estado de autenticación después de mostrar el splash
  Future<void> _checkAuthState() async {
    // Delay para mostrar el splash screen (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Marcar que ya no es el primer arranque
    ref.read(isInitialBootProvider.notifier).markAsNotInitial();

    // Obtener sesión actual de forma síncrona (no esperar stream)
    final currentSession = SupabaseService.client.auth.currentSession;

    if (!mounted) return;

    if (currentSession != null) {
      // Usuario autenticado - navegar a home
      context.go('/home');
    } else {
      // No autenticado - navegar a login
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de la marca
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 5,
                    blurRadius: 15,
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Image.asset(
                    'assets/icons/Icon-maskable-512.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Urbango',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Logistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            // Indicador de carga
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}