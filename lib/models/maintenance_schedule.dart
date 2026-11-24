import 'dart:convert';

enum MaintenanceStatus {
  overdue,
  soon,
  good,
}

enum ServiceCategory {
  maintenance('定期保養'),
  repair('檢修更換'),
  tires('輪胎底盤'),
  taxInsurance('稅費保險'),
  care('洗車美容');

  const ServiceCategory(this.label);
  final String label;

  static ServiceCategory fromName(String? value) {
    return ServiceCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ServiceCategory.maintenance,
    );
  }
}

class MaintenanceSchedule {
  final String id;
  final String vehicleId;
  final String name;
  final ServiceCategory category;
  final int intervalKm;
  final int intervalMonths;
  final int lastKm;
  final DateTime lastDate;
  final int estimatedCost;
  final String notes;
  final bool reminderEnabled;

  const MaintenanceSchedule({
    required this.id,
    required this.vehicleId,
    required this.name,
    this.category = ServiceCategory.maintenance,
    this.intervalKm = 10000,
    this.intervalMonths = 6,
    required this.lastKm,
    required this.lastDate,
    this.estimatedCost = 0,
    this.notes = '',
    this.reminderEnabled = true,
  });

  /// Next due date calculated from [lastDate] + [intervalMonths].
  DateTime? get nextDueDate {
    if (intervalMonths <= 0) return null;
    final totalMonths = lastDate.month - 1 + intervalMonths;
    final targetYear = lastDate.year + (totalMonths ~/ 12);
    final targetMonth = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = lastDate.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : lastDate.day;
    return DateTime(targetYear, targetMonth, clampedDay);
  }

  /// Next due odometer in km.
  int? get nextDueKm => intervalKm > 0 ? lastKm + intervalKm : null;

  ScheduleEvaluation evaluate({
    required int currentOdometer,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);

    final int? kmRemaining =
        intervalKm > 0 ? (lastKm + intervalKm) - currentOdometer : null;
    final double kmProgress = intervalKm > 0
        ? ((currentOdometer - lastKm) / intervalKm).clamp(0.0, 1.3)
        : 0.0;

    final DateTime? dueDate = nextDueDate;
    int? daysRemaining;
    double timeProgress = 0.0;
    if (dueDate != null) {
      daysRemaining = dueDate.difference(today).inDays;
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final totalDays = dueDate.difference(lastDay).inDays;
      final elapsedDays = today.difference(lastDay).inDays;
      if (totalDays > 0) {
        timeProgress = (elapsedDays / totalDays).clamp(0.0, 1.3);
      }
    }

    final worstProgress = kmProgress > timeProgress ? kmProgress : timeProgress;
    final bool isOverdue = (kmRemaining != null && kmRemaining <= 0) ||
        (daysRemaining != null && daysRemaining <= 0);
    final bool isSoon = !isOverdue &&
        ((kmRemaining != null &&
                kmRemaining <= (intervalKm * 0.15).round().clamp(500, 1500)) ||
            (daysRemaining != null && daysRemaining <= 30) ||
            worstProgress >= 0.85);

    final MaintenanceStatus status = isOverdue
        ? MaintenanceStatus.overdue
        : isSoon
            ? MaintenanceStatus.soon
            : MaintenanceStatus.good;

    return ScheduleEvaluation(
      schedule: this,
      kmRemaining: kmRemaining,
      daysRemaining: daysRemaining,
      dueDate: dueDate,
      progress: worstProgress.clamp(0.0, 1.0),
      status: status,
    );
  }

  MaintenanceSchedule copyWith({
    String? id,
    String? vehicleId,
    String? name,
    ServiceCategory? category,
    int? intervalKm,
    int? intervalMonths,
    int? lastKm,
    DateTime? lastDate,
    int? estimatedCost,
    String? notes,
    bool? reminderEnabled,
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      category: category ?? this.category,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      lastKm: lastKm ?? this.lastKm,
      lastDate: lastDate ?? this.lastDate,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'name': name,
        'category': category.name,
        'intervalKm': intervalKm,
        'intervalMonths': intervalMonths,
        'lastKm': lastKm,
        'lastDate': lastDate.toIso8601String(),
        'estimatedCost': estimatedCost,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
      };

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) =>
      MaintenanceSchedule(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String,
        name: json['name'] as String? ?? '',
        category: ServiceCategory.fromName(json['category'] as String?),
        intervalKm: (json['intervalKm'] as num?)?.toInt() ?? 0,
        intervalMonths: (json['intervalMonths'] as num?)?.toInt() ?? 0,
        lastKm: (json['lastKm'] as num?)?.toInt() ?? 0,
        lastDate: DateTime.tryParse(json['lastDate'] as String? ?? '') ??
            DateTime.now(),
        estimatedCost: (json['estimatedCost'] as num?)?.toInt() ?? 0,
        notes: json['notes'] as String? ?? '',
        reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      );

  static String encodeList(List<MaintenanceSchedule> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<MaintenanceSchedule> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => MaintenanceSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class ScheduleEvaluation {
  final MaintenanceSchedule schedule;
  final int? kmRemaining;
  final int? daysRemaining;
  final DateTime? dueDate;
  final double progress;
  final MaintenanceStatus status;

  const ScheduleEvaluation({
    required this.schedule,
    required this.kmRemaining,
    required this.daysRemaining,
    required this.dueDate,
    required this.progress,
    required this.status,
  });

  String get statusLabel {
    switch (status) {
      case MaintenanceStatus.overdue:
        return '已逾期';
      case MaintenanceStatus.soon:
        return '即將到期';
      case MaintenanceStatus.good:
        return '狀態良好';
    }
  }
}
