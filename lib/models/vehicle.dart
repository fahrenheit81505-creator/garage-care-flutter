import 'dart:convert';

class Vehicle {
  final String id;
  final String brand;
  final String model;
  final String plate;
  final int year;
  final int odometer;
  final String fuelType;
  final String oilSpec;
  final String tireSpec;
  final String shopName;
  final String shopPhone;
  final DateTime? inspectionDue;
  final DateTime? insuranceExpiry;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.plate,
    required this.year,
    required this.odometer,
    this.fuelType = '汽油',
    this.oilSpec = '',
    this.tireSpec = '',
    this.shopName = '',
    this.shopPhone = '',
    this.inspectionDue,
    this.insuranceExpiry,
  });

  String get displayName => '$brand $model';

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    String? plate,
    int? year,
    int? odometer,
    String? fuelType,
    String? oilSpec,
    String? tireSpec,
    String? shopName,
    String? shopPhone,
    DateTime? inspectionDue,
    bool clearInspectionDue = false,
    DateTime? insuranceExpiry,
    bool clearInsuranceExpiry = false,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      plate: plate ?? this.plate,
      year: year ?? this.year,
      odometer: odometer ?? this.odometer,
      fuelType: fuelType ?? this.fuelType,
      oilSpec: oilSpec ?? this.oilSpec,
      tireSpec: tireSpec ?? this.tireSpec,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      inspectionDue:
          clearInspectionDue ? null : (inspectionDue ?? this.inspectionDue),
      insuranceExpiry: clearInsuranceExpiry
          ? null
          : (insuranceExpiry ?? this.insuranceExpiry),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'plate': plate,
        'year': year,
        'odometer': odometer,
        'fuelType': fuelType,
        'oilSpec': oilSpec,
        'tireSpec': tireSpec,
        'shopName': shopName,
        'shopPhone': shopPhone,
        'inspectionDue': inspectionDue?.toIso8601String(),
        'insuranceExpiry': insuranceExpiry?.toIso8601String(),
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        plate: json['plate'] as String? ?? '',
        year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
        odometer: (json['odometer'] as num?)?.toInt() ?? 0,
        fuelType: json['fuelType'] as String? ?? '汽油',
        oilSpec: json['oilSpec'] as String? ?? '',
        tireSpec: json['tireSpec'] as String? ?? '',
        shopName: json['shopName'] as String? ?? '',
        shopPhone: json['shopPhone'] as String? ?? '',
        inspectionDue: json['inspectionDue'] != null
            ? DateTime.tryParse(json['inspectionDue'] as String)
            : null,
        insuranceExpiry: json['insuranceExpiry'] != null
            ? DateTime.tryParse(json['insuranceExpiry'] as String)
            : null,
      );

  static String encodeList(List<Vehicle> list) =>
      jsonEncode(list.map((v) => v.toJson()).toList());

  static List<Vehicle> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
