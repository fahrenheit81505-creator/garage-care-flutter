import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_care/models/maintenance_schedule.dart';
import 'package:garage_care/models/notification_settings.dart';
import 'package:garage_care/models/vehicle.dart';
import 'package:garage_care/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const delayedTestNotificationId = 990002;
  const staleMaintenanceId = 4242;

  final vehicles = [
    Vehicle(
      id: 'v1',
      brand: 'Toyota',
      model: 'RAV4',
      plate: 'BKL-8826',
      year: 2021,
      odometer: 55000,
    ),
  ];
  final now = DateTime.now();
  final schedules = [
    MaintenanceSchedule(
      id: 's1',
      vehicleId: 'v1',
      name: '更換機油',
      intervalKm: 10000,
      intervalMonths: 6,
      lastKm: 50000,
      lastDate: DateTime(now.year, now.month, now.day),
    ),
  ];
  const settings = NotificationSettings(
    advanceDays: [7, 3, 0],
    includeDocumentAlerts: false,
  );

  test('sync cancels only stale pending reminders, never everything',
      () async {
    final wanted = NotificationService.buildNotificationPlans(
      vehicles: vehicles,
      schedules: schedules,
      settings: settings,
    );
    expect(wanted, hasLength(3));

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'pendingNotificationRequests':
          return [
            for (final id in [
              staleMaintenanceId,
              delayedTestNotificationId,
              wanted.first.id,
            ])
              {'id': id, 'title': 't', 'body': 'b', 'payload': 'p'},
          ];
        case 'initialize':
        case 'areNotificationsEnabled':
        case 'canScheduleExactNotifications':
          return true;
        default:
          return null;
      }
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    // Tests run with the Android target platform; route the plugin to its
    // Android implementation, which talks to the mocked channel.
    final plugin = FlutterLocalNotificationsPlugin();
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();

    final scheduled =
        await NotificationService(plugin: plugin).syncMaintenanceNotifications(
      vehicles: vehicles,
      schedules: schedules,
      settings: settings,
    );

    expect(scheduled, 3);
    final methods = calls.map((c) => c.method).toList();
    expect(methods, isNot(contains('cancelAll')));
    expect(methods, isNot(contains('cancelAllPendingNotifications')));

    final cancelledIds = calls
        .where((c) => c.method == 'cancel')
        .map((c) => (c.arguments as Map)['id'])
        .toList();
    expect(cancelledIds, [staleMaintenanceId]);

    final scheduledIds = calls
        .where((c) => c.method == 'zonedSchedule')
        .map((c) => (c.arguments as Map)['id'])
        .toSet();
    expect(scheduledIds, wanted.map((p) => p.id).toSet());
  });
}
