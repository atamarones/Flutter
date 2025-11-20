import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

class SupabaseService {
  static bool _isClearing = false; // Prevenir loop infinito

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    } catch (e) {
      // Capturar errores de inicialización (tokens expirados, etc.)
      // Esto es normal cuando la app se reinicia con tokens expirados
      AppLogger.warning('[SUPABASE] Error durante inicialización (token expirado): $e');
      // Continuar con la inicialización - el usuario simplemente verá el login
    }

    // Auto-recovery de tokens corruptos (PROFESIONAL)
    await _handleSessionRecovery();
    _setupAuthErrorListener();
  }

  /// Auto-recovery de sesión corrupta
  /// Apps profesionales (Uber/DoorDash) detectan y limpian automáticamente
  static Future<void> _handleSessionRecovery() async {
    try {
      final session = client.auth.currentSession;

      if (session != null) {
        // Verificar si el token está cerca de expirar o corrupto
        final expiresAt = session.expiresAt;
        if (expiresAt != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          final isExpired = expiryDate.isBefore(DateTime.now());

          if (isExpired) {
            AppLogger.warning('[SUPABASE] Sesión expirada detectada - Limpiando automáticamente');
            await _forceClearSession();
          }
        }
      }
    } catch (e) {
      AppLogger.error('[SUPABASE] Error en session recovery', error: e);
      // Si hay cualquier error, limpiar todo para estado fresco
      await _forceClearSession();
    }
  }

  /// Listener global de errores de autenticación
  /// Detecta y maneja automáticamente tokens corruptos/expirados
  static void _setupAuthErrorListener() {
    client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      // Eventos normales - NO hacer nada en signedOut para evitar loop
      if (event == AuthChangeEvent.signedIn) {
        AppLogger.info('[SUPABASE] Usuario autenticado exitosamente');
        _isClearing = false; // Reset flag
      } else if (event == AuthChangeEvent.signedOut) {
        AppLogger.info('[SUPABASE] Usuario cerró sesión');
        // NO llamar _forceClearSession aquí - causaba loop infinito
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        AppLogger.info('[SUPABASE] Token refreshed exitosamente');
      }
    }, onError: (error) async {
      // CRÍTICO: Manejar errores de refresh token automáticamente
      AppLogger.error('[SUPABASE] Error de autenticación detectado', error: error);

      if (_isClearing) {
        AppLogger.warning('[SUPABASE] Ya estamos limpiando sesión - ignorando error');
        return;
      }

      if (error is AuthException) {
        // Refresh token inválido/corrupto/expirado
        if (error.message.contains('refresh_token_not_found') ||
            error.message.contains('Invalid Refresh Token') ||
            error.statusCode == '400') {
          AppLogger.warning('[SUPABASE] Token corrupto detectado - Auto-limpiando sesión');
          await _forceClearSession();
        }
      }
    });
  }

  /// Limpieza forzada de sesión (sin errores)
  /// Garantiza estado limpio para próximo login
  /// Apps profesionales (Uber/DoorDash) hacen esto automáticamente
  static Future<void> _forceClearSession() async {
    // Prevenir llamadas recursivas (loop infinito)
    if (_isClearing) {
      AppLogger.warning('[SUPABASE] Ya estamos limpiando sesión - evitando loop');
      return;
    }

    _isClearing = true;

    try {
      AppLogger.warning('[SUPABASE] Ejecutando limpieza forzada de sesión...');

      // 1. Limpiar SharedPreferences PRIMERO (antes de signOut)
      try {
        final prefs = await SharedPreferences.getInstance();

        // Limpiar SOLO las keys de Supabase, preservar otras configuraciones de la app
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('sb-') ||
              key.contains('supabase') ||
              key.contains('auth') ||
              key.contains('session') ||
              key.contains('token')) {
            await prefs.remove(key);
            AppLogger.info('[SUPABASE] Limpiada key: $key');
          }
        }

        // Limpiar foreground service data
        await prefs.remove('rider_token');
        await prefs.remove('rider_status');
        await prefs.remove('rider_id');
      } catch (e) {
        AppLogger.error('[SUPABASE] Error limpiando SharedPreferences', error: e);
      }

      // 2. SignOut DESPUÉS de limpiar storage (para evitar que se re-escriba)
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        // Ignorar errores de signOut si la sesión ya está corrupta
        AppLogger.warning('[SUPABASE] SignOut error (esperado con token corrupto): $e');
      }

      AppLogger.info('[SUPABASE] ✅ Sesión limpiada completamente - Estado fresco para próximo login');
    } catch (e) {
      AppLogger.error('[SUPABASE] Error en _forceClearSession (no crítico)', error: e);
    } finally {
      // Reset flag después de 2 segundos para permitir retry si es necesario
      Future.delayed(const Duration(seconds: 2), () {
        _isClearing = false;
      });
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}