class Rider {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final RiderStatus status;
  final double? currentLat;
  final double? currentLng;
  final String? geohash;
  final String vehicleType;
  final double rating;
  final int dailyDeliveries;
  final int totalDeliveries;
  final DateTime? lastHeartbeatAt;
  final DateTime createdAt;

  Rider({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.status,
    this.currentLat,
    this.currentLng,
    this.geohash,
    required this.vehicleType,
    required this.rating,
    required this.dailyDeliveries,
    required this.totalDeliveries,
    this.lastHeartbeatAt,
    required this.createdAt,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      status: RiderStatus.fromString(json['status'] as String? ?? 'offline'),
      currentLat: _parseDouble(json['current_lat']),
      currentLng: _parseDouble(json['current_lng']),
      geohash: json['geohash'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorcycle',
      rating: _parseDouble(json['rating']) ?? 5.0,
      dailyDeliveries: (json['daily_deliveries'] as int?) ?? 0,
      totalDeliveries: (json['total_deliveries'] as int?) ?? 0,
      lastHeartbeatAt: json['last_heartbeat_at'] != null 
          ? DateTime.parse(json['last_heartbeat_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Rider copyWith({
    RiderStatus? status,
    double? currentLat,
    double? currentLng,
  }) {
    return Rider(
      id: id,
      userId: userId,
      fullName: fullName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      status: status ?? this.status,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      geohash: geohash,
      vehicleType: vehicleType,
      rating: rating,
      dailyDeliveries: dailyDeliveries,
      totalDeliveries: totalDeliveries,
      lastHeartbeatAt: lastHeartbeatAt,
      createdAt: createdAt,
    );
  }
}

enum RiderStatus {
  online,
  offline,
  delivering;

  static RiderStatus fromString(String value) {
    return RiderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RiderStatus.offline,
    );
  }
}