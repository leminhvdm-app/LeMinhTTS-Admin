class DeviceModel {
  final String machineKey;
  final String deviceName;
  final String customerName;
  final String status; // "active" | "blocked" | "pending"
  final String note;
  final DateTime createdAt;
  final DateTime lastSeen;
  final DateTime? expiresAt;

  DeviceModel({
    required this.machineKey,
    required this.deviceName,
    required this.customerName,
    required this.status,
    required this.note,
    required this.createdAt,
    required this.lastSeen,
    this.expiresAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isBlocked => status.toLowerCase() == 'blocked';
  bool get isPending => status.toLowerCase() == 'pending';

  factory DeviceModel.fromJson(String key, Map<String, dynamic> json) {
    return DeviceModel(
      machineKey: key,
      deviceName: json['device_name']?.toString() ?? 'Máy tính',
      customerName: json['customer_name']?.toString() ?? 'Chưa đặt tên',
      status: json['status']?.toString() ?? 'active',
      note: json['note']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['created_at'] is int ? json['created_at'] : int.tryParse(json['created_at'].toString()) ?? 0) * 1000,
            )
          : DateTime.now(),
      lastSeen: json['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['last_seen'] is int ? json['last_seen'] : int.tryParse(json['last_seen'].toString()) ?? 0) * 1000,
            )
          : DateTime.now(),
      expiresAt: (json['expires_at'] != null && json['expires_at'] > 0)
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['expires_at'] is int ? json['expires_at'] : int.tryParse(json['expires_at'].toString()) ?? 0) * 1000,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'machine_key': machineKey,
      'device_name': deviceName,
      'customer_name': customerName,
      'status': status,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'last_seen': lastSeen.millisecondsSinceEpoch ~/ 1000,
      'expires_at': expiresAt != null ? (expiresAt!.millisecondsSinceEpoch ~/ 1000) : 0,
    };
  }

  DeviceModel copyWith({
    String? customerName,
    String? status,
    String? note,
    DateTime? expiresAt,
  }) {
    return DeviceModel(
      machineKey: machineKey,
      deviceName: deviceName,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt,
      lastSeen: lastSeen,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
