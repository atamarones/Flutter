import 'package:flutter/foundation.dart';

/// Sistema de logging centralizado con niveles y control de producción
///
/// Niveles:
/// - ERROR: Errores críticos que deben ser reportados (enviar a servicio remoto)
/// - WARNING: Advertencias importantes pero no bloquean funcionalidad
/// - INFO: Información importante de eventos (solo enviar eventos críticos)
/// - DEBUG: Información detallada solo para desarrollo (NUNCA enviar a remoto)
class AppLogger {
  // Contadores para rate limiting
  static final Map<String, DateTime> _lastLogTime = {};
  static const Duration _minLogInterval = Duration(seconds: 60);

  /// ERROR - Solo para errores críticos que deben ser reportados
  /// Estos SÍ se enviarán al servicio de logging remoto
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    final logMessage = '❌ [ERROR] $message';

    if (kDebugMode) {
      debugPrint(logMessage);
      if (error != null) debugPrint('Error details: $error');
      if (stackTrace != null) debugPrint('Stack trace: $stackTrace');
    }

    // TODO: Aquí enviar a servicio remoto (Sentry, Firebase, etc.)
    _sendToRemoteLogging(LogLevel.error, message, error, stackTrace);
  }

  /// WARNING - Para situaciones anormales que no bloquean funcionalidad
  /// Solo se envían al remoto si son críticas (con throttling)
  static void warning(String message, {bool sendRemote = false}) {
    final logMessage = '⚠️ [WARNING] $message';

    if (kDebugMode) {
      debugPrint(logMessage);
    }

    if (sendRemote && _shouldLog(message)) {
      // TODO: Enviar warnings críticos con rate limiting
      _sendToRemoteLogging(LogLevel.warning, message, null, null);
    }
  }

  /// INFO - Eventos importantes pero normales del flujo
  /// Solo loguear en desarrollo y eventos MUY específicos en producción
  static void info(String message, {bool sendRemote = false}) {
    if (kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }

    // Solo enviar al remoto eventos específicos importantes con rate limiting
    if (sendRemote && _shouldLog(message)) {
      _sendToRemoteLogging(LogLevel.info, message, null, null);
    }
  }

  /// DEBUG - Solo para desarrollo, NUNCA en producción
  /// NO se envía a servicio remoto para ahorrar cuota
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 [DEBUG] $message');
    }
  }

  /// SUCCESS - Para eventos exitosos importantes
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ [SUCCESS] $message');
    }
  }

  // Rate limiting: solo loguear mismo mensaje cada 60 segundos
  static bool _shouldLog(String message) {
    final now = DateTime.now();
    final key = message.hashCode.toString();

    if (_lastLogTime.containsKey(key)) {
      final diff = now.difference(_lastLogTime[key]!);
      if (diff < _minLogInterval) {
        return false; // Muy pronto, skip
      }
    }

    _lastLogTime[key] = now;
    return true;
  }

  /// Enviar a servicio de logging remoto
  /// TODO: Implementar con Sentry, Firebase, o tu servicio preferido
  static void _sendToRemoteLogging(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // Solo en release mode
    if (kReleaseMode) {
      // Aquí implementar envío a servicio remoto
      // Ejemplo con Sentry:
      // if (error != null) {
      //   Sentry.captureException(error, stackTrace: stackTrace);
      // } else {
      //   Sentry.captureMessage(message, level: _toSentryLevel(level));
      // }
    }
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Categorías específicas para mejor organización
extension LoggerCategories on AppLogger {
  /// Logs específicos del Foreground Service
  static void foregroundService(String message, {LogLevel level = LogLevel.debug}) {
    final prefix = '[FOREGROUND SERVICE]';
    switch (level) {
      case LogLevel.error:
        AppLogger.error('$prefix $message');
        break;
      case LogLevel.warning:
        AppLogger.warning('$prefix $message');
        break;
      case LogLevel.info:
        AppLogger.info('$prefix $message');
        break;
      case LogLevel.debug:
        AppLogger.debug('$prefix $message');
        break;
    }
  }

  /// Logs de ubicación (muy frecuentes, solo debug)
  static void location(String message) {
    AppLogger.debug('[LOCATION] $message');
  }

  /// Logs de heartbeat (frecuente, solo debug, reportar solo errores)
  static void heartbeat(String message, {bool isError = false}) {
    if (isError) {
      AppLogger.error('[HEARTBEAT] $message');
    } else {
      AppLogger.debug('[HEARTBEAT] $message');
    }
  }

  /// Logs de autenticación (importante, reportar eventos clave)
  static void auth(String message, {LogLevel level = LogLevel.info}) {
    final prefix = '[AUTH]';
    switch (level) {
      case LogLevel.error:
        AppLogger.error('$prefix $message');
        break;
      case LogLevel.warning:
        AppLogger.warning('$prefix $message', sendRemote: true);
        break;
      case LogLevel.info:
        AppLogger.info('$prefix $message', sendRemote: true);
        break;
      case LogLevel.debug:
        AppLogger.debug('$prefix $message');
        break;
    }
  }

  /// Logs de pedidos (eventos importantes)
  static void order(String message, {LogLevel level = LogLevel.info}) {
    final prefix = '[ORDER]';
    switch (level) {
      case LogLevel.error:
        AppLogger.error('$prefix $message');
        break;
      case LogLevel.warning:
        AppLogger.warning('$prefix $message', sendRemote: true);
        break;
      case LogLevel.info:
        AppLogger.info('$prefix $message', sendRemote: true);
        break;
      case LogLevel.debug:
        AppLogger.debug('$prefix $message');
        break;
    }
  }
}
