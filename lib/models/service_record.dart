import 'dart:convert';
import 'maintenance_schedule.dart';

class ServiceRecord {
  final String id;
  final String vehicleId;
  final String title;
  final DateTime date;
  final int odometer;
  final ServiceCategory category;
  final int cost;
  final String shop;
  final String notes;
  final List<String> linkedScheduleIds;

  const ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.date,
    required this.odometer,
    this.category = ServiceCategory.maintenance,
    this.cost = 0,
    this.shop = '',
    this.notes = '',
    this.linkedScheduleIds = const [],
  });

  ServiceRecord copyWith({
    String? id,
    String? vehicleId,
    String? title,
    DateTime? date,
    int? odometer,
    ServiceCategory? category,
    int? cost,
    String? shop,
    String? notes,
    List<String>? linkedScheduleIds,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      title: title ?? this.title,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      category: category ?? this.category,
      cost: cost ?? this.cost,
      shop: shop ?? this.shop,
      notes: notes ?? this.notes,
      linkedScheduleIds: linkedScheduleIds ?? this.linkedScheduleIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'title': title,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'category': category.name,
        'cost': cost,
        'shop': shop,
        'notes': notes,
        'linkedScheduleIds': linkedScheduleIds,
      };

  factory ServiceRecord.fromJson(Map<String, dynamic> json) => ServiceRecord(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String,
        title: json['title'] as String? ?? '',
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        odometer: (json['odometer'] as num?)?.toInt() ?? 0,
        category: ServiceCategory.fromName(json['category'] as String?),
        cost: (json['cost'] as num?)?.toInt() ?? 0,
        shop: json['shop'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        linkedScheduleIds: (json['linkedScheduleIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  static String encodeList(List<ServiceRecord> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ServiceRecord> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ServiceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
