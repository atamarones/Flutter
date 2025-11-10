class City {
  final String id;
  final String name;
  final String country;
  final bool active;
  final DateTime createdAt;

  City({
    required this.id,
    required this.name,
    required this.country,
    required this.active,
    required this.createdAt,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      name: json['name'],
      country: json['country'],
      active: json['active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}