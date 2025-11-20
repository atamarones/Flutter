import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static const String _configUrl = 'https://aima-n8n.yau1cn.easypanel.host/webhook/app-config-rider';
  static const String _cacheKey = 'remote_config_cache';
  static const Duration _cacheDuration = Duration(hours: 1);

  static RemoteConfigService? _instance;
  static RemoteConfigService get instance => _instance ??= RemoteConfigService._();

  RemoteConfigService._();

  Map<String, dynamic> _config = {};
  DateTime? _lastFetch;

  /// Obtener valor de configuración
  T? getValue<T>(String key, {T? defaultValue}) {
    return _config[key] as T? ?? defaultValue;
  }

  /// Inicializar y cargar configuración remota
  Future<void> initialize() async {
    try {
      // Intentar cargar desde cache primero
      await _loadFromCache();

      // Si el cache expiró o no existe, fetch remoto
      if (_shouldFetchRemote()) {
        await fetchAndActivate();
      }
    } catch (e) {
      debugPrint('Error initializing remote config: $e');
    }
  }

  /// Determinar si se debe hacer fetch remoto
  bool _shouldFetchRemote() {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!) > _cacheDuration;
  }

  /// Cargar configuración desde cache local
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final lastFetchMs = prefs.getInt('${_cacheKey}_timestamp');

      if (cachedJson != null && lastFetchMs != null) {
        _config = json.decode(cachedJson) as Map<String, dynamic>;
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(lastFetchMs);
        debugPrint('Remote config loaded from cache');
      }
    } catch (e) {
      debugPrint('Error loading config from cache: $e');
    }
  }

  /// Guardar configuración en cache local
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(_config));
      await prefs.setInt('${_cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving config to cache: $e');
    }
  }

  /// Fetch y activar configuración remota
  Future<bool> fetchAndActivate() async {
    try {
      final response = await http.get(
        Uri.parse(_configUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _config = data;
        _lastFetch = DateTime.now();
        await _saveToCache();
        debugPrint('Remote config fetched successfully: ${_config.keys}');
        return true;
      } else {
        debugPrint('Failed to fetch remote config: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error fetching remote config: $e');
      return false;
    }
  }

  /// Obtener valores específicos con fallback a defaults
  int get locationUpdateIntervalSeconds =>
      getValue<int>('locationUpdateIntervalSeconds', defaultValue: 15) ?? 15;

  int get heartbeatIntervalSeconds =>
      getValue<int>('heartbeatIntervalSeconds', defaultValue: 15) ?? 15;

  double get deliveryRadiusMeters =>
      getValue<double>('deliveryRadiusMeters', defaultValue: 50.0) ?? 50.0;

  int get orderTimeoutSeconds =>
      getValue<int>('orderTimeoutSeconds', defaultValue: 59) ?? 59;

  String get supportWhatsAppNumber =>
      getValue<String>('supportWhatsAppNumber', defaultValue: '+573167107509') ?? '+573167107509';

  String get notTakenReleaseOrderWebhook =>
      getValue<String>('notTakenReleaseOrderWebhook',
          defaultValue: 'https://aima-n8n.yau1cn.easypanel.host/webhook/notaken-release-order-rider') ??
      'https://aima-n8n.yau1cn.easypanel.host/webhook/notaken-release-order-rider';
}
