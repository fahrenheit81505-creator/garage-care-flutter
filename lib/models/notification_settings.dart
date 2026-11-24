import 'dart:convert';

class NotificationSettings {
  /// Master toggle for all OS local notifications.
  final bool enabled;

  /// Hour of day (0-23) when maintenance date reminders fire.
  final int reminderHour;

  /// Minute of hour (0-59) when maintenance date reminders fire.
  final int reminderMinute;

  /// List of advance days before due date to trigger OS notifications.
  /// Example: [7, 3, 0] means 7 days before, 3 days before, and on the due date.
  final List<int> advanceDays;

  /// Whether to also schedule notifications for vehicle inspection & insurance dates.
  final bool includeDocumentAlerts;

  const NotificationSettings({
    this.enabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.advanceDays = const [7, 3, 0],
    this.includeDocumentAlerts = true,
  });

  String get formattedTime =>
      '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}';

  NotificationSettings copyWith({
    bool? enabled,
    int? reminderHour,
    int? reminderMinute,
    List<int>? advanceDays,
    bool? includeDocumentAlerts,
  }) {
    final sortedDays = advanceDays != null
        ? (List<int>.from(advanceDays.toSet())..sort((a, b) => b.compareTo(a)))
        : this.advanceDays;
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      advanceDays: sortedDays,
      includeDocumentAlerts:
          includeDocumentAlerts ?? this.includeDocumentAlerts,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'advanceDays': advanceDays,
        'includeDocumentAlerts': includeDocumentAlerts,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['advanceDays'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .where((d) => d >= 0 && d <= 90)
            .toSet()
            .toList() ??
        [7, 3, 0];
    rawDays.sort((a, b) => b.compareTo(a));

    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      reminderHour: (json['reminderHour'] as num?)?.toInt().clamp(0, 23) ?? 9,
      reminderMinute:
          (json['reminderMinute'] as num?)?.toInt().clamp(0, 59) ?? 0,
      advanceDays: rawDays,
      includeDocumentAlerts: json['includeDocumentAlerts'] as bool? ?? true,
    );
  }

  String encode() => jsonEncode(toJson());

  static NotificationSettings decode(String raw) =>
      NotificationSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
