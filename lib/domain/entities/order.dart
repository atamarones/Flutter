class Order {
  final String id;
  final String orderNumber;
  final String riderId;
  final OrderStatus status;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? deliveryInstructions;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;
  final List<OrderItem> items;
  final double totalAmount;
  final double? estimatedDistanceKm;
  final int? estimatedDurationMin;
  final String? providerName;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.riderId,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryInstructions,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.items,
    required this.totalAmount,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    this.providerName,
    required this.createdAt,
    this.assignedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['order_number'],
      riderId: json['rider_id'],
      status: OrderStatus.fromString(json['status']),
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      deliveryAddress: json['delivery_address'],
      deliveryInstructions: json['delivery_instructions'],
      pickupAddress: json['pickup_address'],
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      deliveryLat: (json['delivery_lat'] as num).toDouble(),
      deliveryLng: (json['delivery_lng'] as num).toDouble(),
      items: (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      estimatedDistanceKm: json['estimated_distance_km']?.toDouble(),
      estimatedDurationMin: json['estimated_duration_min'],
      providerName: json['provider_name'],
      createdAt: DateTime.parse(json['created_at']),
      assignedAt: json['assigned_at'] != null ? DateTime.parse(json['assigned_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      pickedUpAt: json['picked_up_at'] != null ? DateTime.parse(json['picked_up_at']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
    );
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem({required this.name, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
    );
  }
}

enum OrderStatus {
  pending,
  assigned,
  accepted,
  inProgress,
  delivered,
  released,
  cancelled;

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'in_progress': return OrderStatus.inProgress;
      default: return OrderStatus.values.firstWhere((e) => e.name == value, orElse: () => OrderStatus.pending);
    }
  }

  String toJson() {
    if (this == OrderStatus.inProgress) return 'in_progress';
    return name;
  }
}