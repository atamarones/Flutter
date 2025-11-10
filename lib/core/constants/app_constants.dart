class AppConstants {
  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ciqkhjwgluqbeyndroph.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpcWtoandnbHVxYmV5bmRyb3BoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxOTI2MDEsImV4cCI6MjA3Nzc2ODYwMX0.hwnD2oX_yUy38Aj1PGxRyMt6KUa8eKnsurppg7o0rlg',
  );
  
  // Mapbox
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: 'pk.eyJ1Ijoic2lzdGVtYXMwNzEyIiwiYSI6ImNtaGpnMmVnMjA5MjkycXBzNTV3ZGV4MzgifQ.oD9eoySj-C0jNMs3LIEAZA', 
  );
  
  // Location Settings
  static const int locationUpdateIntervalSeconds = 35;
  static const int heartbeatIntervalSeconds = 35;
  static const double deliveryRadiusMeters = 100.0;
  
  // Order Assignment
  static const int orderTimeoutSeconds = 59;
  
  // App Info
  static const String appName = 'Urbango Logistics';
  static const String appVersion = '1.0.0';
}