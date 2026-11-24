import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/maintenance_schedule.dart';
import '../models/notification_settings.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../utils/calendar_date.dart';

class GarageSnapshot {
  final List<Vehicle> vehicles;
  final String activeVehicleId;
  final List<MaintenanceSchedule> schedules;
  final List<ServiceRecord> records;
  final NotificationSettings notificationSettings;

  /// Labels of the stored sections that could not be read completely.
  /// Their original raw value has been kept under a backup key.
  final List<String> unreadableSections;

  const GarageSnapshot({
    required this.vehicles,
    required this.activeVehicleId,
    required this.schedules,
    required this.records,
    required this.notificationSettings,
    this.unreadableSections = const [],
  });
}

class StorageService {
  static const _kVehicles = 'gc_vehicles_v1';
  static const _kActiveVehicleId = 'gc_active_vehicle_id_v1';
  static const _kSchedules = 'gc_schedules_v1';
  static const _kRecords = 'gc_records_v1';
  static const _kNotificationSettings = 'gc_notification_settings_v1';

  /// Suffix of the key an unreadable raw value is copied to before anything
  /// can overwrite it.
  static const backupSuffix = '_backup';

  Future<GarageSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawVehicles = prefs.getString(_kVehicles);
    if (rawVehicles == null || rawVehicles.isEmpty) {
      // First launch: nothing stored yet.
      final seed = createSeedSnapshot();
      await save(seed);
      return seed;
    }

    final rawSchedules = prefs.getString(_kSchedules);
    final rawRecords = prefs.getString(_kRecords);
    final rawSettings = prefs.getString(_kNotificationSettings);

    // Each section is decoded on its own so one bad entry cannot take the
    // rest of the garage with it.
    final vehicles = _decodeList(rawVehicles, Vehicle.fromJson);
    final schedules = _decodeList(rawSchedules, MaintenanceSchedule.fromJson);
    final records = _decodeList(rawRecords, ServiceRecord.fromJson);
    final settings = _decodeSettings(rawSettings);

    final unreadable = <String>[
      if (vehicles.damaged) '車輛',
      if (schedules.damaged) '保養排程',
      if (records.damaged) '保養紀錄',
      if (settings.damaged) '通知設定',
    ];

    if (vehicles.items.isEmpty) {
      if (!vehicles.damaged) {
        // A valid but empty list: nothing to lose, start from the demo data.
        final seed = createSeedSnapshot();
        await save(seed);
        return seed;
      }
      // No vehicle could be read. Keep every raw value before the next save
      // replaces it, and show the demo data without writing it.
      await _backup(prefs, {
        _kVehicles: rawVehicles,
        _kSchedules: rawSchedules,
        _kRecords: rawRecords,
        _kNotificationSettings: rawSettings,
      });
      final seed = createSeedSnapshot();
      return GarageSnapshot(
        vehicles: seed.vehicles,
        activeVehicleId: seed.activeVehicleId,
        schedules: seed.schedules,
        records: seed.records,
        notificationSettings: seed.notificationSettings,
        unreadableSections: unreadable,
      );
    }

    // Entries that failed to decode are skipped; keep the raw value they came
    // from so the next save does not erase them for good.
    await _backup(prefs, {
      if (vehicles.damaged) _kVehicles: rawVehicles,
      if (schedules.damaged) _kSchedules: rawSchedules,
      if (records.damaged) _kRecords: rawRecords,
      if (settings.damaged) _kNotificationSettings: rawSettings,
    });

    final activeId =
        prefs.getString(_kActiveVehicleId) ?? vehicles.items.first.id;
    final resolvedActiveId = vehicles.items.any((v) => v.id == activeId)
        ? activeId
        : vehicles.items.first.id;

    return GarageSnapshot(
      vehicles: vehicles.items,
      activeVehicleId: resolvedActiveId,
      schedules: schedules.items,
      records: records.items,
      notificationSettings: settings.value,
      unreadableSections: unreadable,
    );
  }

  static ({List<T> items, bool damaged}) _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return (items: <T>[], damaged: false);

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      debugPrint('StorageService: stored list is not valid JSON: $e');
      return (items: <T>[], damaged: true);
    }
    if (decoded is! List) return (items: <T>[], damaged: true);

    final items = <T>[];
    var damaged = false;
    for (final entry in decoded) {
      try {
        items.add(fromJson(entry as Map<String, dynamic>));
      } catch (e) {
        debugPrint('StorageService: skipped unreadable entry: $e');
        damaged = true;
      }
    }
    return (items: items, damaged: damaged);
  }

  static ({NotificationSettings value, bool damaged}) _decodeSettings(
    String? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return (value: const NotificationSettings(), damaged: false);
    }
    try {
      return (value: NotificationSettings.decode(raw), damaged: false);
    } catch (e) {
      debugPrint('StorageService: notification settings unreadable: $e');
      return (value: const NotificationSettings(), damaged: true);
    }
  }

  static Future<void> _backup(
    SharedPreferences prefs,
    Map<String, String?> rawByKey,
  ) async {
    for (final entry in rawByKey.entries) {
      final raw = entry.value;
      if (raw == null || raw.isEmpty) continue;
      await prefs.setString('${entry.key}$backupSuffix', raw);
    }
  }

  Future<void> save(GarageSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kVehicles, Vehicle.encodeList(snapshot.vehicles)),
      prefs.setString(_kActiveVehicleId, snapshot.activeVehicleId),
      prefs.setString(
        _kSchedules,
        MaintenanceSchedule.encodeList(snapshot.schedules),
      ),
      prefs.setString(_kRecords, ServiceRecord.encodeList(snapshot.records)),
      prefs.setString(
        _kNotificationSettings,
        snapshot.notificationSettings.encode(),
      ),
    ]);
  }

  static GarageSnapshot createSeedSnapshot({DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    const v1Id = 'veh_rav4';
    const v2Id = 'veh_gogoro';

    final vehicles = [
      Vehicle(
        id: v1Id,
        brand: 'Toyota',
        model: 'RAV4 Hybrid 旗艦',
        plate: 'BKL-8826',
        year: 2021,
        odometer: 58420,
        fuelType: '油電 Hybrid',
        oilSpec: '0W-16 全合成 (4.5L)',
        tireSpec: '225/60 R18',
        shopName: '豐田北投服務廠',
        shopPhone: '02-2891-5520',
        inspectionDue: addCalendarDays(today, 45),
        insuranceExpiry: addCalendarDays(today, 28),
      ),
      Vehicle(
        id: v2Id,
        brand: 'Yamaha',
        model: 'CYGNUS GRYPHUS 125',
        plate: 'NKA-5912',
        year: 2022,
        odometer: 14680,
        fuelType: '汽油（機車）',
        oilSpec: '10W-40 4T 機油 (0.9L)',
        tireSpec: '120/70-12 / 130/70-12',
        shopName: '祥發機車精品保養',
        shopPhone: '02-2823-1148',
        inspectionDue: addCalendarDays(today, 90),
        insuranceExpiry: addCalendarDays(today, 62),
      ),
    ];

    final schedules = [
      MaintenanceSchedule(
        id: 'sch_oil',
        vehicleId: v1Id,
        name: '更換機油與機油濾芯',
        category: ServiceCategory.maintenance,
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 50100,
        lastDate: addCalendarDays(today, -170),
        estimatedCost: 4200,
        notes: '使用原廠 0W-16 機油與墊片',
        reminderEnabled: true,
      ),
      MaintenanceSchedule(
        id: 'sch_tire_rot',
        vehicleId: v1Id,
        name: '輪胎對調與胎壓檢查',
        category: ServiceCategory.tires,
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 48200,
        lastDate: addCalendarDays(today, -192),
        estimatedCost: 600,
        notes: '前後對調並維持胎壓 35 PSI',
        reminderEnabled: true,
      ),
      MaintenanceSchedule(
        id: 'sch_ac_filter',
        vehicleId: v1Id,
        name: '冷氣濾網更換',
        category: ServiceCategory.maintenance,
        intervalKm: 15000,
        intervalMonths: 12,
        lastKm: 46000,
        lastDate: addCalendarDays(today, -330),
        estimatedCost: 950,
        notes: 'PM2.5 活性碳濾網',
        reminderEnabled: true,
      ),
      MaintenanceSchedule(
        id: 'sch_brake_fluid',
        vehicleId: v1Id,
        name: '煞車油更換與來令片檢查',
        category: ServiceCategory.repair,
        intervalKm: 40000,
        intervalMonths: 24,
        lastKm: 40000,
        lastDate: addCalendarDays(today, -365),
        estimatedCost: 2200,
        notes: 'DOT4 煞車油，同步檢測含水量',
        reminderEnabled: true,
      ),
      MaintenanceSchedule(
        id: 'sch_hv_filter',
        vehicleId: v1Id,
        name: '油電大電池散熱濾網清潔',
        category: ServiceCategory.maintenance,
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 50100,
        lastDate: addCalendarDays(today, -162),
        estimatedCost: 0,
        notes: '後座右側吸風口濾網清潔',
        reminderEnabled: true,
      ),
      // Motorcycle schedules
      MaintenanceSchedule(
        id: 'sch_moto_oil',
        vehicleId: v2Id,
        name: '機車機油與齒輪油更換',
        category: ServiceCategory.maintenance,
        intervalKm: 1000,
        intervalMonths: 3,
        lastKm: 13850,
        lastDate: addCalendarDays(today, -78),
        estimatedCost: 550,
        notes: '每 1,000 公里更換機油、每 2,000 公里更換齒輪油',
        reminderEnabled: true,
      ),
      MaintenanceSchedule(
        id: 'sch_moto_air',
        vehicleId: v2Id,
        name: '空氣濾清棉與傳動檢查',
        category: ServiceCategory.maintenance,
        intervalKm: 5000,
        intervalMonths: 6,
        lastKm: 10000,
        lastDate: addCalendarDays(today, -160),
        estimatedCost: 900,
        notes: '檢查皮帶裂紋與普利珠磨耗',
        reminderEnabled: true,
      ),
    ];

    final records = [
      ServiceRecord(
        id: 'rec_1',
        vehicleId: v1Id,
        title: '5 萬公里定期保養',
        date: addCalendarDays(today, -170),
        odometer: 50100,
        category: ServiceCategory.maintenance,
        cost: 4380,
        shop: '豐田北投服務廠',
        notes: '更換 0W-16 機油、機油濾芯與油底殼墊片，大電池濾網清潔。',
        linkedScheduleIds: const ['sch_oil', 'sch_hv_filter'],
      ),
      ServiceRecord(
        id: 'rec_2',
        vehicleId: v1Id,
        title: '更換 12V 輔助電瓶 (湯淺 AGM)',
        date: addCalendarDays(today, -35),
        odometer: 57250,
        category: ServiceCategory.repair,
        cost: 5200,
        shop: '電池達人內湖店',
        notes: '啟動電壓偏低，預防性更換新電瓶。',
      ),
      ServiceRecord(
        id: 'rec_3',
        vehicleId: v1Id,
        title: '四輪更換 Michelin Primacy 4+',
        date: addCalendarDays(today, -192),
        odometer: 48200,
        category: ServiceCategory.tires,
        cost: 21600,
        shop: '米其林馳加士林店',
        notes: '含四輪平衡與電腦四輪定位。',
        linkedScheduleIds: const ['sch_tire_rot'],
      ),
      ServiceRecord(
        id: 'rec_4',
        vehicleId: v2Id,
        title: '例行更換機油與齒輪油',
        date: addCalendarDays(today, -78),
        odometer: 13850,
        category: ServiceCategory.maintenance,
        cost: 550,
        shop: '祥發機車精品保養',
        notes: '檢查前後胎壓與煞車皮厚度正常。',
        linkedScheduleIds: const ['sch_moto_oil'],
      ),
    ];

    return GarageSnapshot(
      vehicles: vehicles,
      activeVehicleId: v1Id,
      schedules: schedules,
      records: records,
      notificationSettings: const NotificationSettings(
        enabled: true,
        reminderHour: 9,
        reminderMinute: 0,
        advanceDays: [7, 3, 0],
        includeDocumentAlerts: true,
      ),
    );
  }
}
