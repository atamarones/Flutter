import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';

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

  /// Verifica el estado de autenticación de forma reactiva (no síncrona)
  /// Esto previene race conditions donde getCurrentUser() retorna null
  /// mientras el auth state aún se está propagando
  Future<void> _checkAuthState() async {
    // Pequeño delay para animación del splash
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Escuchar el stream de auth una sola vez para obtener el estado actualizado
    final authState = await SupabaseService.client.auth.onAuthStateChange.first;

    if (!mounted) return;

    if (authState.session != null) {
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
          ],
        ),
      ),
    );
  }
}