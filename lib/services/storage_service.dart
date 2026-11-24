import 'package:shared_preferences/shared_preferences.dart';
import '../models/maintenance_schedule.dart';
import '../models/notification_settings.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';

class GarageSnapshot {
  final List<Vehicle> vehicles;
  final String activeVehicleId;
  final List<MaintenanceSchedule> schedules;
  final List<ServiceRecord> records;
  final NotificationSettings notificationSettings;

  const GarageSnapshot({
    required this.vehicles,
    required this.activeVehicleId,
    required this.schedules,
    required this.records,
    required this.notificationSettings,
  });
}

class StorageService {
  static const _kVehicles = 'gc_vehicles_v1';
  static const _kActiveVehicleId = 'gc_active_vehicle_id_v1';
  static const _kSchedules = 'gc_schedules_v1';
  static const _kRecords = 'gc_records_v1';
  static const _kNotificationSettings = 'gc_notification_settings_v1';

  Future<GarageSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawVehicles = prefs.getString(_kVehicles);
    if (rawVehicles == null || rawVehicles.isEmpty) {
      final seed = createSeedSnapshot();
      await save(seed);
      return seed;
    }

    try {
      final vehicles = Vehicle.decodeList(rawVehicles);
      if (vehicles.isEmpty) {
        final seed = createSeedSnapshot();
        await save(seed);
        return seed;
      }

      final activeId = prefs.getString(_kActiveVehicleId) ?? vehicles.first.id;
      final resolvedActiveId =
          vehicles.any((v) => v.id == activeId) ? activeId : vehicles.first.id;

      final rawSchedules = prefs.getString(_kSchedules);
      final schedules = rawSchedules != null && rawSchedules.isNotEmpty
          ? MaintenanceSchedule.decodeList(rawSchedules)
          : <MaintenanceSchedule>[];

      final rawRecords = prefs.getString(_kRecords);
      final records = rawRecords != null && rawRecords.isNotEmpty
          ? ServiceRecord.decodeList(rawRecords)
          : <ServiceRecord>[];

      final rawSettings = prefs.getString(_kNotificationSettings);
      final settings = rawSettings != null && rawSettings.isNotEmpty
          ? NotificationSettings.decode(rawSettings)
          : const NotificationSettings();

      return GarageSnapshot(
        vehicles: vehicles,
        activeVehicleId: resolvedActiveId,
        schedules: schedules,
        records: records,
        notificationSettings: settings,
      );
    } catch (_) {
      final seed = createSeedSnapshot();
      await save(seed);
      return seed;
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
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
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
        inspectionDue: today.add(const Duration(days: 45)),
        insuranceExpiry: today.add(const Duration(days: 28)),
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
        inspectionDue: today.add(const Duration(days: 90)),
        insuranceExpiry: today.add(const Duration(days: 62)),
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
        lastDate: today.subtract(const Duration(days: 170)),
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
        lastDate: today.subtract(const Duration(days: 192)),
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
        lastDate: today.subtract(const Duration(days: 330)),
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
        lastDate: today.subtract(const Duration(days: 365)),
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
        lastDate: today.subtract(const Duration(days: 162)),
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
        lastDate: today.subtract(const Duration(days: 78)),
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
        lastDate: today.subtract(const Duration(days: 160)),
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
        date: today.subtract(const Duration(days: 170)),
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
        date: today.subtract(const Duration(days: 35)),
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
        date: today.subtract(const Duration(days: 192)),
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
        date: today.subtract(const Duration(days: 78)),
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
