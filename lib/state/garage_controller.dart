import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/maintenance_schedule.dart';
import '../models/notification_settings.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class GarageController extends ChangeNotifier {
  GarageController({
    StorageService? storage,
    NotificationService? notifications,
  })  : _storage = storage ?? StorageService(),
        _notifications = notifications ?? NotificationService();

  final StorageService _storage;
  final NotificationService _notifications;

  bool _isLoading = true;
  List<Vehicle> _vehicles = [];
  String _activeVehicleId = '';
  List<MaintenanceSchedule> _schedules = [];
  List<ServiceRecord> _records = [];
  NotificationSettings _notificationSettings = const NotificationSettings();
  NotificationPermissionStatus _permissionStatus =
      const NotificationPermissionStatus(
    granted: false,
    canScheduleExactAlarms: false,
    timezoneName: 'Asia/Taipei',
  );
  List<PendingNotificationRequest> _pendingNotifications = const [];

  bool get isLoading => _isLoading;
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  String get activeVehicleId => _activeVehicleId;
  NotificationSettings get notificationSettings => _notificationSettings;
  NotificationPermissionStatus get permissionStatus => _permissionStatus;
  List<PendingNotificationRequest> get pendingNotifications =>
      List.unmodifiable(_pendingNotifications);

  Vehicle get activeVehicle {
    return _vehicles.firstWhere(
      (v) => v.id == _activeVehicleId,
      orElse: () => _vehicles.first,
    );
  }

  List<MaintenanceSchedule> get activeSchedules => _schedules
      .where((s) => s.vehicleId == activeVehicle.id)
      .toList(growable: false);

  List<ScheduleEvaluation> get evaluatedActiveSchedules {
    final odo = activeVehicle.odometer;
    final list = activeSchedules
        .map((s) => s.evaluate(currentOdometer: odo))
        .toList();
    list.sort((a, b) {
      final statusCmp = a.status.index.compareTo(b.status.index);
      if (statusCmp != 0) return statusCmp;
      return b.progress.compareTo(a.progress);
    });
    return list;
  }

  List<ServiceRecord> get activeRecords {
    final list =
        _records.where((r) => r.vehicleId == activeVehicle.id).toList();
    list.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      return b.odometer.compareTo(a.odometer);
    });
    return list;
  }

  int get activeHealthScore {
    final evals = evaluatedActiveSchedules;
    if (evals.isEmpty) return 100;
    int penalty = 0;
    for (final e in evals) {
      if (e.status == MaintenanceStatus.overdue) {
        penalty += 22;
      } else if (e.status == MaintenanceStatus.soon) {
        penalty += 9;
      }
    }
    return (100 - penalty).clamp(15, 100);
  }

  int get activeAlertCount => evaluatedActiveSchedules
      .where((e) => e.status != MaintenanceStatus.good)
      .length;

  int get activeYearSpend {
    final year = DateTime.now().year;
    return activeRecords
        .where((r) => r.date.year == year)
        .fold(0, (sum, r) => sum + r.cost);
  }

  List<ScheduledNotificationPlan> get plannedNotifications =>
      NotificationService.buildNotificationPlans(
        vehicles: _vehicles,
        schedules: _schedules,
        settings: _notificationSettings,
      );

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final snapshot = await _storage.load();
    _vehicles = List.of(snapshot.vehicles);
    _activeVehicleId = snapshot.activeVehicleId;
    _schedules = List.of(snapshot.schedules);
    _records = List.of(snapshot.records);
    _notificationSettings = snapshot.notificationSettings;

    await _notifications.initialize();
    _permissionStatus = await _notifications.checkPermissionStatus();
    await _syncNotificationsOnly();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _persistAndSync() async {
    await _storage.save(
      GarageSnapshot(
        vehicles: _vehicles,
        activeVehicleId: _activeVehicleId,
        schedules: _schedules,
        records: _records,
        notificationSettings: _notificationSettings,
      ),
    );
    await _syncNotificationsOnly();
    notifyListeners();
  }

  Future<int> _syncNotificationsOnly() async {
    final count = await _notifications.syncMaintenanceNotifications(
      vehicles: _vehicles,
      schedules: _schedules,
      settings: _notificationSettings,
    );
    _pendingNotifications = await _notifications.getPendingNotifications();
    return count;
  }

  Future<int> syncNotificationsNow() async {
    _permissionStatus = await _notifications.checkPermissionStatus();
    final count = await _syncNotificationsOnly();
    notifyListeners();
    return count;
  }

  Future<void> requestNotificationPermissions() async {
    _permissionStatus = await _notifications.requestPermissions();
    await _syncNotificationsOnly();
    notifyListeners();
  }

  Future<void> requestExactAlarmPermission() async {
    await _notifications.requestExactAlarmPermission();
    _permissionStatus = await _notifications.checkPermissionStatus();
    await _syncNotificationsOnly();
    notifyListeners();
  }

  Future<void> sendTestNotificationNow() async {
    await _notifications.sendTestNotificationNow();
  }

  Future<void> scheduleDelayedTestNotification() async {
    await _notifications.scheduleDelayedTestNotification();
    _pendingNotifications = await _notifications.getPendingNotifications();
    notifyListeners();
  }

  // ---- Vehicle CRUD ----

  Future<void> selectVehicle(String vehicleId) async {
    if (_activeVehicleId == vehicleId) return;
    _activeVehicleId = vehicleId;
    await _storage.save(
      GarageSnapshot(
        vehicles: _vehicles,
        activeVehicleId: _activeVehicleId,
        schedules: _schedules,
        records: _records,
        notificationSettings: _notificationSettings,
      ),
    );
    notifyListeners();
  }

  Future<void> updateOdometer(int newOdometer) async {
    final idx = _vehicles.indexWhere((v) => v.id == activeVehicle.id);
    if (idx < 0) return;
    _vehicles[idx] = _vehicles[idx].copyWith(odometer: newOdometer);
    await _persistAndSync();
  }

  Future<void> saveVehicle(
    Vehicle vehicle, {
    bool addDefaultSchedules = false,
  }) async {
    final idx = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (idx >= 0) {
      _vehicles[idx] = vehicle;
    } else {
      _vehicles.add(vehicle);
      _activeVehicleId = vehicle.id;
      if (addDefaultSchedules) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final defaults = [
          MaintenanceSchedule(
            id: _newId('sch'),
            vehicleId: vehicle.id,
            name: '更換機油與機油濾芯',
            category: ServiceCategory.maintenance,
            intervalKm: 10000,
            intervalMonths: 6,
            lastKm: vehicle.odometer,
            lastDate: today,
            estimatedCost: 3800,
          ),
          MaintenanceSchedule(
            id: _newId('sch'),
            vehicleId: vehicle.id,
            name: '輪胎對調與胎壓檢查',
            category: ServiceCategory.tires,
            intervalKm: 10000,
            intervalMonths: 6,
            lastKm: vehicle.odometer,
            lastDate: today,
            estimatedCost: 600,
          ),
          MaintenanceSchedule(
            id: _newId('sch'),
            vehicleId: vehicle.id,
            name: '冷氣濾網更換',
            category: ServiceCategory.maintenance,
            intervalKm: 15000,
            intervalMonths: 12,
            lastKm: vehicle.odometer,
            lastDate: today,
            estimatedCost: 900,
          ),
        ];
        _schedules.addAll(defaults);
      }
    }
    await _persistAndSync();
  }

  Future<void> deleteVehicle(String vehicleId) async {
    if (_vehicles.length <= 1) return;
    _vehicles.removeWhere((v) => v.id == vehicleId);
    _schedules.removeWhere((s) => s.vehicleId == vehicleId);
    _records.removeWhere((r) => r.vehicleId == vehicleId);
    if (_activeVehicleId == vehicleId) {
      _activeVehicleId = _vehicles.first.id;
    }
    await _persistAndSync();
  }

  // ---- Schedule CRUD ----

  Future<void> saveSchedule(MaintenanceSchedule schedule) async {
    final idx = _schedules.indexWhere((s) => s.id == schedule.id);
    if (idx >= 0) {
      _schedules[idx] = schedule;
    } else {
      _schedules.add(schedule);
    }
    await _persistAndSync();
  }

  Future<void> toggleScheduleReminder(String scheduleId, bool enabled) async {
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx < 0) return;
    _schedules[idx] = _schedules[idx].copyWith(reminderEnabled: enabled);
    await _persistAndSync();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    _schedules.removeWhere((s) => s.id == scheduleId);
    await _persistAndSync();
  }

  // ---- Service Record CRUD ----

  Future<void> saveRecord(ServiceRecord record) async {
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
    }

    // Advance odometer if record odometer is newer
    final vIdx = _vehicles.indexWhere((v) => v.id == record.vehicleId);
    if (vIdx >= 0 && record.odometer > _vehicles[vIdx].odometer) {
      _vehicles[vIdx] = _vehicles[vIdx].copyWith(odometer: record.odometer);
    }

    // Sync linked schedules so next due date & OS notification automatically advance!
    for (final schId in record.linkedScheduleIds) {
      final sIdx = _schedules.indexWhere((s) => s.id == schId);
      if (sIdx >= 0 && !record.date.isBefore(_schedules[sIdx].lastDate)) {
        _schedules[sIdx] = _schedules[sIdx].copyWith(
          lastDate: record.date,
          lastKm: record.odometer,
        );
      }
    }

    await _persistAndSync();
  }

  Future<void> deleteRecord(String recordId) async {
    _records.removeWhere((r) => r.id == recordId);
    await _persistAndSync();
  }

  // ---- Notification Settings ----

  Future<void> updateNotificationSettings(NotificationSettings next) async {
    _notificationSettings = next;
    await _persistAndSync();
  }

  Future<void> resetDemoData() async {
    final seed = StorageService.createSeedSnapshot();
    _vehicles = List.of(seed.vehicles);
    _activeVehicleId = seed.activeVehicleId;
    _schedules = List.of(seed.schedules);
    _records = List.of(seed.records);
    _notificationSettings = seed.notificationSettings;
    await _persistAndSync();
  }

  static String _newId(String prefix) {
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  String generateId(String prefix) => _newId(prefix);
}
