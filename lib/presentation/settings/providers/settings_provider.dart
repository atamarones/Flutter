import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavigationMethod {
  googleMaps('Google Maps'),
  waze('Waze'),
  appleMaps('Apple Maps');

  final String displayName;
  const NavigationMethod(this.displayName);
}

enum LocationAccuracy {
  high('Alta - Más preciso, consume más batería'),
  medium('Media - Balance entre precisión y batería'),
  low('Baja - Menos preciso, ahorra batería');

  final String displayName;
  const LocationAccuracy(this.displayName);
}

class AppSettings {
  final NavigationMethod navigationMethod;
  final LocationAccuracy locationAccuracy;

  const AppSettings({
    this.navigationMethod = NavigationMethod.googleMaps,
    this.locationAccuracy = LocationAccuracy.high,
  });

  AppSettings copyWith({
    NavigationMethod? navigationMethod,
    LocationAccuracy? locationAccuracy,
  }) {
    return AppSettings(
      navigationMethod: navigationMethod ?? this.navigationMethod,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final navigationMethodIndex = prefs.getInt('navigationMethod') ?? 0;
    final locationAccuracyIndex = prefs.getInt('locationAccuracy') ?? 0;

    state = AppSettings(
      navigationMethod: NavigationMethod.values[navigationMethodIndex],
      locationAccuracy: LocationAccuracy.values[locationAccuracyIndex],
    );
  }

  Future<void> setNavigationMethod(NavigationMethod method) async {
    state = state.copyWith(navigationMethod: method);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('navigationMethod', method.index);
  }

  Future<void> setLocationAccuracy(LocationAccuracy accuracy) async {
    state = state.copyWith(locationAccuracy: accuracy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('locationAccuracy', accuracy.index);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});
