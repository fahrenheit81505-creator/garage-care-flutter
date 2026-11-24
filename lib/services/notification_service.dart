import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/maintenance_schedule.dart';
import '../models/notification_settings.dart';
import '../models/vehicle.dart';

/// Represents a concrete notification planned to be registered with Android/iOS OS.
class ScheduledNotificationPlan {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
  final String vehicleName;
  final int daysBefore;

  const ScheduledNotificationPlan({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
    required this.vehicleName,
    required this.daysBefore,
  });
}

class NotificationPermissionStatus {
  final bool granted;
  final bool canScheduleExactAlarms;
  final String timezoneName;

  const NotificationPermissionStatus({
    required this.granted,
    required this.canScheduleExactAlarms,
    required this.timezoneName,
  });
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String _timezoneName = 'Asia/Taipei';

  static const String maintenanceChannelId = 'garage_care_maintenance';
  static const String maintenanceChannelName = '保養到期提醒';
  static const String maintenanceChannelDesc =
      '於保養預定日、驗車日或車險到期前發送系統推播提醒';

  static const String testChannelId = 'garage_care_test';
  static const String testChannelName = '通知測試';
  static const String testChannelDesc = '用於確認手機系統推播權限與聲音振動設定';

  /// iOS limits apps to 64 pending local notifications at a time.
  /// Reserve 4 slots for test/system notifications and schedule up to 60 upcoming alerts.
  static const int maxPendingNotifications = 60;

  String get timezoneName => _timezoneName;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    try {
      await _plugin.initialize(settings: initSettings);
      await _createAndroidChannels();
    } catch (e) {
      debugPrint('NotificationService initialize skipped/error: $e');
    }

    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      _timezoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(_timezoneName));
    } catch (_) {
      try {
        _timezoneName = 'Asia/Taipei';
        tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
      } catch (_) {
        _timezoneName = 'UTC';
        tz.setLocalLocation(tz.UTC);
      }
    }
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        maintenanceChannelId,
        maintenanceChannelName,
        description: maintenanceChannelDesc,
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        testChannelId,
        testChannelName,
        description: testChannelDesc,
        importance: Importance.high,
      ),
    );
  }

  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    await initialize();
    bool granted = true;
    bool canExact = false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        granted = (await androidPlugin?.areNotificationsEnabled()) ?? true;
        canExact =
            (await androidPlugin?.canScheduleExactNotifications()) ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final perms = await iosPlugin?.checkPermissions();
        granted = perms?.isEnabled ?? false;
        canExact = true;
      }
    } catch (e) {
      debugPrint('checkPermissionStatus error: $e');
    }

    return NotificationPermissionStatus(
      granted: granted,
      canScheduleExactAlarms: canExact,
      timezoneName: _timezoneName,
    );
  }

  Future<NotificationPermissionStatus> requestPermissions() async {
    await initialize();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('requestPermissions error: $e');
    }
    return checkPermissionStatus();
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return (await androidPlugin?.requestExactAlarmsPermission()) ?? false;
    } catch (e) {
      debugPrint('requestExactAlarmPermission error: $e');
      return false;
    }
  }

  /// Pure deterministic calculation of all upcoming OS notification plans.
  static List<ScheduledNotificationPlan> buildNotificationPlans({
    required List<Vehicle> vehicles,
    required List<MaintenanceSchedule> schedules,
    required NotificationSettings settings,
    DateTime? now,
  }) {
    if (!settings.enabled || settings.advanceDays.isEmpty) {
      return const [];
    }

    final reference = now ?? DateTime.now();
    final dateFormat = DateFormat('yyyy/MM/dd');
    final vehicleMap = {for (final v in vehicles) v.id: v};
    final plans = <ScheduledNotificationPlan>[];

    // 1. Maintenance schedule reminders
    for (final sch in schedules) {
      if (!sch.reminderEnabled) continue;
      final vehicle = vehicleMap[sch.vehicleId];
      if (vehicle == null) continue;
      final dueDate = sch.nextDueDate;
      if (dueDate == null) continue;

      for (final advance in settings.advanceDays) {
        final triggerDay = dueDate.subtract(Duration(days: advance));
        final triggerAt = DateTime(
          triggerDay.year,
          triggerDay.month,
          triggerDay.day,
          settings.reminderHour,
          settings.reminderMinute,
        );
        if (!triggerAt.isAfter(reference)) continue;

        final timingText = advance == 0 ? '今天到期' : '還有 $advance 天到期';
        final kmHint = sch.nextDueKm != null
            ? '（建議里程 ${NumberFormat('#,###').format(sch.nextDueKm)} km）'
            : '';

        plans.add(
          ScheduledNotificationPlan(
            id: _stableNotificationId('sch_${sch.id}_$advance'),
            title: '【${vehicle.displayName}】${sch.name} $timingText',
            body:
                '預定保養日 ${dateFormat.format(dueDate)}$kmHint，請提前預約保養廠或更新里程。',
            scheduledAt: triggerAt,
            payload: 'schedule:${sch.id}',
            vehicleName: vehicle.displayName,
            daysBefore: advance,
          ),
        );
      }
    }

    // 2. Vehicle inspection & insurance reminders (if enabled)
    if (settings.includeDocumentAlerts) {
      for (final vehicle in vehicles) {
        final docs = <(String key, String label, DateTime? date)>[
          ('insp', '定期驗車', vehicle.inspectionDue),
          ('ins', '車險保單', vehicle.insuranceExpiry),
        ];

        for (final doc in docs) {
          final dueDate = doc.$3;
          if (dueDate == null) continue;

          for (final advance in settings.advanceDays) {
            final triggerDay = dueDate.subtract(Duration(days: advance));
            final triggerAt = DateTime(
              triggerDay.year,
              triggerDay.month,
              triggerDay.day,
              settings.reminderHour,
              settings.reminderMinute,
            );
            if (!triggerAt.isAfter(reference)) continue;

            final timingText = advance == 0 ? '今天到期' : '還有 $advance 天到期';
            plans.add(
              ScheduledNotificationPlan(
                id: _stableNotificationId(
                  'doc_${vehicle.id}_${doc.$1}_$advance',
                ),
                title: '【${vehicle.displayName}】${doc.$2}$timingText',
                body:
                    '車牌 ${vehicle.plate} 之${doc.$2}到期日為 ${dateFormat.format(dueDate)}，別忘了提前辦理。',
                scheduledAt: triggerAt,
                payload: 'vehicle:${vehicle.id}',
                vehicleName: vehicle.displayName,
                daysBefore: advance,
              ),
            );
          }
        }
      }
    }

    plans.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (plans.length > maxPendingNotifications) {
      return plans.sublist(0, maxPendingNotifications);
    }
    return plans;
  }

  /// Syncs all upcoming notifications with the native Android / iOS notification center.
  Future<int> syncMaintenanceNotifications({
    required List<Vehicle> vehicles,
    required List<MaintenanceSchedule> schedules,
    required NotificationSettings settings,
  }) async {
    await initialize();

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll error: $e');
      return 0;
    }

    if (!settings.enabled) return 0;

    final plans = buildNotificationPlans(
      vehicles: vehicles,
      schedules: schedules,
      settings: settings,
    );

    final perm = await checkPermissionStatus();
    final scheduleMode = perm.canScheduleExactAlarms
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        maintenanceChannelId,
        maintenanceChannelName,
        channelDescription: maintenanceChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    int scheduledCount = 0;
    for (final plan in plans) {
      try {
        final tzDate = tz.TZDateTime.from(plan.scheduledAt, tz.local);
        await _plugin.zonedSchedule(
          id: plan.id,
          title: plan.title,
          body: plan.body,
          scheduledDate: tzDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          payload: plan.payload,
        );
        scheduledCount++;
      } catch (e) {
        debugPrint('zonedSchedule error for ${plan.id}: $e');
      }
    }
    return scheduledCount;
  }

  Future<void> sendTestNotificationNow() async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        testChannelId,
        testChannelName,
        channelDescription: testChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: 990001,
      title: '車庫管家 · 系統通知測試成功',
      body: '您的手機已成功啟用保養到期推播，系統將於設定時間準時提醒您。',
      notificationDetails: details,
      payload: 'test_now',
    );
  }

  Future<void> scheduleDelayedTestNotification({
    Duration delay = const Duration(seconds: 5),
  }) async {
    await initialize();
    final perm = await checkPermissionStatus();
    final scheduleMode = perm.canScheduleExactAlarms
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        testChannelId,
        testChannelName,
        channelDescription: testChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final scheduledAt = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id: 990002,
      title: '車庫管家 · 排程推播測試',
      body: '這是 5 秒排程推播測試，代表背景與待機提醒機制運作正常！',
      scheduledDate: scheduledAt,
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
      payload: 'test_delayed',
    );
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  static int _stableNotificationId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return (hash % 800000) + 1000;
  }
}
