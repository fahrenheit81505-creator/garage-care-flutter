import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage_care/models/maintenance_schedule.dart';
import 'package:garage_care/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kVehicles = 'gc_vehicles_v1';
const _kSchedules = 'gc_schedules_v1';
const _kRecords = 'gc_records_v1';

String _vehiclesJson() => jsonEncode([
      {
        'id': 'veh_mine',
        'brand': 'Honda',
        'model': 'CR-V',
        'plate': 'ABC-1234',
        'year': 2020,
        'odometer': 42000,
      },
    ]);

String _schedulesJson() => jsonEncode([
      {
        'id': 'sch_mine',
        'vehicleId': 'veh_mine',
        'name': '更換機油',
        'intervalKm': 10000,
        'intervalMonths': 6,
        'lastKm': 40000,
        'lastDate': '2026-06-10T00:00:00.000',
      },
    ]);

void main() {
  group('StorageService.load', () {
    test('first launch stores the demo data', () async {
      SharedPreferences.setMockInitialValues({});

      final snapshot = await StorageService().load();

      expect(snapshot.vehicles, isNotEmpty);
      expect(snapshot.unreadableSections, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kVehicles), isNotNull);
    });

    test('one malformed record does not replace the garage with demo data',
        () async {
      final rawRecords = jsonEncode([
        {
          'id': 'rec_ok',
          'vehicleId': 'veh_mine',
          'title': '定期保養',
          'date': '2026-06-10T00:00:00.000',
          'odometer': 40000,
        },
        {'id': 'rec_bad', 'vehicleId': null, 'title': '壞掉的紀錄'},
      ]);
      SharedPreferences.setMockInitialValues({
        _kVehicles: _vehiclesJson(),
        _kSchedules: _schedulesJson(),
        _kRecords: rawRecords,
      });

      final snapshot = await StorageService().load();

      expect(snapshot.vehicles.single.id, 'veh_mine');
      expect(snapshot.schedules.single.id, 'sch_mine');
      expect(snapshot.records.single.id, 'rec_ok');
      expect(snapshot.unreadableSections, ['保養紀錄']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kVehicles), _vehiclesJson());
      expect(
        prefs.getString('$_kRecords${StorageService.backupSuffix}'),
        rawRecords,
      );
    });

    test('unreadable vehicles are kept on disk instead of being overwritten',
        () async {
      const rawVehicles = '{not json';
      SharedPreferences.setMockInitialValues({
        _kVehicles: rawVehicles,
        _kSchedules: _schedulesJson(),
      });

      final snapshot = await StorageService().load();

      // The app still gets something to show...
      expect(snapshot.vehicles, isNotEmpty);
      expect(snapshot.unreadableSections, contains('車輛'));

      // ...but nothing the user had stored was touched, and it is backed up
      // before any later save can replace it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kVehicles), rawVehicles);
      expect(prefs.getString(_kSchedules), _schedulesJson());
      expect(
        prefs.getString('$_kVehicles${StorageService.backupSuffix}'),
        rawVehicles,
      );
      expect(
        prefs.getString('$_kSchedules${StorageService.backupSuffix}'),
        _schedulesJson(),
      );
    });

    test('schedules saved before baselines existed use their last service',
        () async {
      SharedPreferences.setMockInitialValues({
        _kVehicles: _vehiclesJson(),
        _kSchedules: _schedulesJson(),
      });

      final snapshot = await StorageService().load();
      final MaintenanceSchedule schedule = snapshot.schedules.single;

      expect(schedule.baselineKm, 40000);
      expect(schedule.baselineDate, DateTime(2026, 6, 10));
    });
  });
}
