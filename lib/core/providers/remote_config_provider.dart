import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/remote_config_service.dart';

/// Provider para el servicio de configuración remota
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService.instance;
});

/// Provider para valores individuales de configuración
final locationUpdateIntervalProvider = Provider<int>((ref) {
  return ref.watch(remoteConfigServiceProvider).locationUpdateIntervalSeconds;
});

final heartbeatIntervalProvider = Provider<int>((ref) {
  return ref.watch(remoteConfigServiceProvider).heartbeatIntervalSeconds;
});

final deliveryRadiusMetersProvider = Provider<double>((ref) {
  return ref.watch(remoteConfigServiceProvider).deliveryRadiusMeters;
});

final orderTimeoutSecondsProvider = Provider<int>((ref) {
  return ref.watch(remoteConfigServiceProvider).orderTimeoutSeconds;
});

final supportWhatsAppNumberProvider = Provider<String>((ref) {
  return ref.watch(remoteConfigServiceProvider).supportWhatsAppNumber;
});

final notTakenReleaseOrderWebhookProvider = Provider<String>((ref) {
  return ref.watch(remoteConfigServiceProvider).notTakenReleaseOrderWebhook;
});
