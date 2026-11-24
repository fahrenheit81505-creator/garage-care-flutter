import 'package:flutter_test/flutter_test.dart';
import 'package:garage_care/models/maintenance_schedule.dart';
import 'package:garage_care/models/service_record.dart';
import 'package:garage_care/services/storage_service.dart';
import 'package:garage_care/state/garage_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_service.dart';

const _vehicleId = 'veh_rav4';

/// In the demo data this schedule has no linked record: last service at
/// 40,000 km.
const _brakeFluid = 'sch_brake_fluid';

Future<GarageController> _loadController({
  FakeNotificationService? notifications,
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller = GarageController(
    notifications: notifications ?? FakeNotificationService(),
  );
  await controller.init();
  return controller;
}

MaintenanceSchedule _schedule(GarageController controller, String id) =>
    controller.activeSchedules.firstWhere((s) => s.id == id);

ServiceRecord _completion({
  String id = 'rec_new',
  required DateTime date,
  int odometer = 58500,
  List<String> linked = const [_brakeFluid],
}) =>
    ServiceRecord(
      id: id,
      vehicleId: _vehicleId,
      title: '煞車油更換',
      date: date,
      odometer: odometer,
      linkedScheduleIds: linked,
    );

class _FailingOnceStorage extends StorageService {
  bool failNext = true;

  @override
  Future<GarageSnapshot> load() async {
    if (failNext) {
      failNext = false;
      throw StateError('storage unavailable');
    }
    return super.load();
  }
}

void main() {
  final today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  group('linked schedules follow their records', () {
    test('saving a completion record advances the schedule', () async {
      final controller = await _loadController();

      await controller.saveRecord(_completion(date: today));

      final schedule = _schedule(controller, _brakeFluid);
      expect(schedule.lastKm, 58500);
      expect(schedule.lastDate, today);
    });

    test('deleting that record restores the previous last service', () async {
      final controller = await _loadController();
      final before = _schedule(controller, _brakeFluid);

      await controller.saveRecord(_completion(date: today));
      await controller.deleteRecord('rec_new');

      final after = _schedule(controller, _brakeFluid);
      expect(after.lastKm, before.lastKm);
      expect(after.lastDate, before.lastDate);
    });

    test('deleting the newest record falls back to the remaining one',
        () async {
      final controller = await _loadController();
      final yesterday = DateTime(today.year, today.month, today.day - 1);

      await controller.saveRecord(
        _completion(id: 'rec_a', date: yesterday, odometer: 58000),
      );
      await controller.saveRecord(
        _completion(id: 'rec_b', date: today, odometer: 58500),
      );
      await controller.deleteRecord('rec_b');

      final schedule = _schedule(controller, _brakeFluid);
      expect(schedule.lastKm, 58000);
      expect(schedule.lastDate, yesterday);
    });

    test('unlinking a schedule while editing a record rolls it back',
        () async {
      final controller = await _loadController();
      final before = _schedule(controller, _brakeFluid);

      await controller.saveRecord(_completion(date: today));
      await controller.saveRecord(_completion(date: today, linked: const []));

      expect(_schedule(controller, _brakeFluid).lastKm, before.lastKm);
    });

    test('renaming a schedule keeps the value a record delete restores',
        () async {
      final controller = await _loadController();
      final before = _schedule(controller, _brakeFluid);

      await controller.saveRecord(_completion(date: today));
      final advanced = _schedule(controller, _brakeFluid);

      // The edit form builds a fresh schedule from its fields.
      await controller.saveSchedule(
        MaintenanceSchedule(
          id: advanced.id,
          vehicleId: advanced.vehicleId,
          name: '煞車油（已改名）',
          intervalKm: advanced.intervalKm,
          intervalMonths: advanced.intervalMonths,
          lastKm: advanced.lastKm,
          lastDate: advanced.lastDate,
        ),
      );
      await controller.deleteRecord('rec_new');

      final after = _schedule(controller, _brakeFluid);
      expect(after.name, '煞車油（已改名）');
      expect(after.lastKm, before.lastKm);
      expect(after.lastDate, before.lastDate);
    });
  });

  group('notification sync', () {
    test('overlapping changes never run two syncs at once', () async {
      final fake = FakeNotificationService();
      final controller = await _loadController(notifications: fake);
      fake
        ..syncDelay = const Duration(milliseconds: 20)
        ..maxConcurrentSyncs = 0
        ..syncedSchedules.clear();

      final first = controller.toggleScheduleReminder('sch_oil', false);
      final second = controller.toggleScheduleReminder('sch_tire_rot', false);
      await Future.wait([first, second]);

      expect(fake.maxConcurrentSyncs, 1);
      // The sync that ran last saw both reminders switched off.
      final last = fake.syncedSchedules.last;
      expect(last.firstWhere((s) => s.id == 'sch_oil').reminderEnabled, false);
      expect(
        last.firstWhere((s) => s.id == 'sch_tire_rot').reminderEnabled,
        false,
      );
    });

    test('listeners see a change before saving and syncing finish', () async {
      final fake = FakeNotificationService();
      final controller = await _loadController(notifications: fake);
      fake.syncDelay = const Duration(milliseconds: 20);

      var notified = 0;
      controller.addListener(() => notified++);

      final pending = controller.updateNotificationSettings(
        controller.notificationSettings.copyWith(advanceDays: [14, 7, 3, 0]),
      );

      expect(notified, 1);
      expect(controller.notificationSettings.advanceDays, [14, 7, 3, 0]);
      await pending;
    });
  });

  group('init', () {
    test('a storage failure is reported and can be retried', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = GarageController(
        storage: _FailingOnceStorage(),
        notifications: FakeNotificationService(),
      );

      await controller.init();
      expect(controller.isLoading, false);
      expect(controller.loadFailed, true);

      await controller.init();
      expect(controller.loadFailed, false);
      expect(controller.vehicles, isNotEmpty);
    });
  });
}
