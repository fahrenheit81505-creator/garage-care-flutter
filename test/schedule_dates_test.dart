import 'package:flutter_test/flutter_test.dart';
import 'package:garage_care/models/maintenance_schedule.dart';
import 'package:garage_care/models/notification_settings.dart';
import 'package:garage_care/models/vehicle.dart';
import 'package:garage_care/services/notification_service.dart';
import 'package:garage_care/utils/calendar_date.dart';

void main() {
  group('due today', () {
    final schedule = MaintenanceSchedule(
      id: 's1',
      vehicleId: 'v1',
      name: '更換機油',
      intervalKm: 10000,
      intervalMonths: 6,
      lastKm: 50000,
      lastDate: DateTime(2026, 5, 20),
    );

    test('the due date itself is due today, not overdue', () {
      final eval = schedule.evaluate(
        currentOdometer: 52000,
        now: DateTime(2026, 11, 20, 15, 30),
      );

      expect(eval.daysRemaining, 0);
      expect(eval.isDueToday, true);
      expect(eval.status, MaintenanceStatus.soon);
    });

    test('the day after the due date is overdue', () {
      final eval = schedule.evaluate(
        currentOdometer: 52000,
        now: DateTime(2026, 11, 21),
      );

      expect(eval.daysRemaining, -1);
      expect(eval.status, MaintenanceStatus.overdue);
    });

    test('reaching the due mileage exactly is not overdue yet', () {
      final eval = schedule.evaluate(
        currentOdometer: 60000,
        now: DateTime(2026, 6, 1),
      );

      expect(eval.kmRemaining, 0);
      expect(eval.status, MaintenanceStatus.soon);
    });
  });

  // These hold in every time zone; in one with daylight saving (run the suite
  // with TZ=America/Los_Angeles) they fail if days are counted as 24 hours.
  group('calendar days across a daylight-saving change', () {
    test('counts calendar days, not 24-hour blocks', () {
      expect(
        calendarDaysBetween(DateTime(2027, 3, 14), DateTime(2027, 3, 15)),
        1,
      );
      expect(addCalendarDays(DateTime(2027, 3, 17), -7), DateTime(2027, 3, 10));
    });

    test('a 7-day advance reminder fires exactly 7 calendar days before', () {
      final plans = NotificationService.buildNotificationPlans(
        vehicles: [
          Vehicle(
            id: 'v1',
            brand: 'Toyota',
            model: 'RAV4',
            plate: 'BKL-8826',
            year: 2021,
            odometer: 55000,
          ),
        ],
        schedules: [
          MaintenanceSchedule(
            id: 's1',
            vehicleId: 'v1',
            name: '更換機油',
            intervalKm: 10000,
            intervalMonths: 6,
            lastKm: 50000,
            lastDate: DateTime(2026, 9, 17), // due 2027-03-17
          ),
        ],
        settings: const NotificationSettings(
          reminderHour: 9,
          reminderMinute: 0,
          advanceDays: [7],
          includeDocumentAlerts: false,
        ),
        now: DateTime(2027, 3, 1),
      );

      expect(plans.single.scheduledAt, DateTime(2027, 3, 10, 9, 0));
    });

    test('an item due tomorrow has one day left on the transition day', () {
      final schedule = MaintenanceSchedule(
        id: 's1',
        vehicleId: 'v1',
        name: '更換機油',
        intervalKm: 0,
        intervalMonths: 6,
        lastKm: 0,
        lastDate: DateTime(2026, 9, 15), // due 2027-03-15
      );

      final eval = schedule.evaluate(
        currentOdometer: 0,
        now: DateTime(2027, 3, 14),
      );

      expect(eval.daysRemaining, 1);
      expect(eval.status, MaintenanceStatus.soon);
    });
  });
}
