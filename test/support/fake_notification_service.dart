import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:garage_care/models/maintenance_schedule.dart';
import 'package:garage_care/models/notification_settings.dart';
import 'package:garage_care/models/vehicle.dart';
import 'package:garage_care/services/notification_service.dart';

/// Stands in for the OS notification plugin and records every sync it is
/// asked to run.
class FakeNotificationService extends NotificationService {
  /// When set, each sync waits for this long before finishing, so tests can
  /// make syncs overlap.
  Duration? syncDelay;

  int runningSyncs = 0;
  int maxConcurrentSyncs = 0;
  final List<List<MaintenanceSchedule>> syncedSchedules = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    return const NotificationPermissionStatus(
      granted: true,
      canScheduleExactAlarms: true,
      timezoneName: 'Asia/Taipei',
    );
  }

  @override
  Future<int> syncMaintenanceNotifications({
    required List<Vehicle> vehicles,
    required List<MaintenanceSchedule> schedules,
    required NotificationSettings settings,
  }) async {
    runningSyncs++;
    if (runningSyncs > maxConcurrentSyncs) maxConcurrentSyncs = runningSyncs;
    syncedSchedules.add(schedules);
    final delay = syncDelay;
    if (delay != null) await Future<void>.delayed(delay);
    runningSyncs--;
    return NotificationService.buildNotificationPlans(
      vehicles: vehicles,
      schedules: schedules,
      settings: settings,
    ).length;
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async =>
      const [];
}
