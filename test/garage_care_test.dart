import 'package:flutter_test/flutter_test.dart';
import 'package:garage_care/main.dart';
import 'package:garage_care/models/maintenance_schedule.dart';
import 'package:garage_care/models/notification_settings.dart';
import 'package:garage_care/models/vehicle.dart';
import 'package:garage_care/services/notification_service.dart';
import 'package:garage_care/state/garage_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_service.dart';

void main() {
  group('MaintenanceSchedule evaluation', () {
    test('detects overdue status when odometer exceeds interval', () {
      final sch = MaintenanceSchedule(
        id: 'sch_1',
        vehicleId: 'v1',
        name: '更換機油',
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 50000,
        lastDate: DateTime(2026, 10, 1),
      );

      final eval = sch.evaluate(
        currentOdometer: 60500,
        now: DateTime(2026, 11, 1),
      );

      expect(eval.status, MaintenanceStatus.overdue);
      expect(eval.kmRemaining, -500);
    });

    test('detects soon status when due date is within 30 days', () {
      final sch = MaintenanceSchedule(
        id: 'sch_2',
        vehicleId: 'v1',
        name: '冷氣濾網',
        intervalKm: 15000,
        intervalMonths: 6,
        lastKm: 50000,
        lastDate: DateTime(2026, 5, 20),
      );

      final eval = sch.evaluate(
        currentOdometer: 52000,
        now: DateTime(2026, 11, 1),
      );

      expect(eval.status, MaintenanceStatus.soon);
      expect(eval.daysRemaining, 19);
    });
  });

  group('NotificationService.buildNotificationPlans', () {
    test('schedules advance reminders (7d, 3d, 0d) at configured time', () {
      final vehicle = Vehicle(
        id: 'v1',
        brand: 'Toyota',
        model: 'RAV4',
        plate: 'BKL-8826',
        year: 2021,
        odometer: 55000,
        inspectionDue: DateTime(2026, 12, 20),
      );

      final schedule = MaintenanceSchedule(
        id: 's1',
        vehicleId: 'v1',
        name: '更換機油',
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 50000,
        lastDate: DateTime(2026, 6, 10),
        reminderEnabled: true,
      );

      const settings = NotificationSettings(
        enabled: true,
        reminderHour: 9,
        reminderMinute: 30,
        advanceDays: [7, 3, 0],
        includeDocumentAlerts: true,
      );

      final plans = NotificationService.buildNotificationPlans(
        vehicles: [vehicle],
        schedules: [schedule],
        settings: settings,
        now: DateTime(2026, 11, 20, 8, 0),
      );

      // 3 reminders for oil change (Dec 3, Dec 7, Dec 10) + 3 for inspection (Dec 13, Dec 17, Dec 20)
      expect(plans.length, 6);
      expect(plans.first.scheduledAt, DateTime(2026, 12, 3, 9, 30));
      expect(plans.first.daysBefore, 7);
      expect(plans.first.title, contains('更換機油'));
      expect(plans.last.scheduledAt, DateTime(2026, 12, 20, 9, 30));
      expect(plans.last.title, contains('定期驗車'));
    });

    test('returns empty list when master notifications switch is disabled', () {
      final vehicle = Vehicle(
        id: 'v1',
        brand: 'Toyota',
        model: 'RAV4',
        plate: 'BKL-8826',
        year: 2021,
        odometer: 55000,
      );
      final schedule = MaintenanceSchedule(
        id: 's1',
        vehicleId: 'v1',
        name: '更換機油',
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 50000,
        lastDate: DateTime(2026, 6, 10),
      );

      final plans = NotificationService.buildNotificationPlans(
        vehicles: [vehicle],
        schedules: [schedule],
        settings: const NotificationSettings(enabled: false),
        now: DateTime(2026, 11, 20),
      );

      expect(plans, isEmpty);
    });

    test('skips schedule items with reminderEnabled set to false', () {
      final vehicle = Vehicle(
        id: 'v1',
        brand: 'Toyota',
        model: 'RAV4',
        plate: 'BKL-8826',
        year: 2021,
        odometer: 55000,
      );
      final schedule = MaintenanceSchedule(
        id: 's1',
        vehicleId: 'v1',
        name: '冷氣濾網',
        intervalKm: 10000,
        intervalMonths: 6,
        lastKm: 50000,
        lastDate: DateTime(2026, 6, 10),
        reminderEnabled: false,
      );

      final plans = NotificationService.buildNotificationPlans(
        vehicles: [vehicle],
        schedules: [schedule],
        settings: const NotificationSettings(
          enabled: true,
          advanceDays: [7, 3, 0],
          includeDocumentAlerts: false,
        ),
        now: DateTime(2026, 11, 20),
      );

      expect(plans, isEmpty);
    });
  });

  group('GarageCareApp widget smoke test', () {
    testWidgets('renders overview and switches to notification manager tab',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = GarageController(
        notifications: FakeNotificationService(),
      );

      await tester.runAsync(() => controller.init());
      await tester.pumpWidget(GarageCareApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('重點保養倒數'), findsOneWidget);
      expect(find.text('通知管理'), findsOneWidget);

      await tester.tap(find.text('通知管理'));
      await tester.pumpAndSettle();

      expect(find.text('保養到期前推播規則'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('推播功能驗證與測試'), 250);
      expect(find.text('推播功能驗證與測試'), findsOneWidget);
    });
  });
}
