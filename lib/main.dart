import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/services/supabase_service.dart';
import 'core/services/foreground_tracking_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar Mapbox
  MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);

  // Inicializar Supabase
  await SupabaseService.initialize();

  // Inicializar Foreground Tracking Service
  await ForegroundTrackingService.initialize();

  // Inicializar Remote Config (carga configuración desde servidor)
  await RemoteConfigService.instance.initialize();

  runApp(
    const ProviderScope(
      child: UrbangoRiderApp(),
    ),
  );
}

class UrbangoRiderApp extends ConsumerWidget {
  const UrbangoRiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Urbango Rider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}