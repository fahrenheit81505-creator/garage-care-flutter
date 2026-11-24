import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../state/garage_controller.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  final GarageController controller;

  const NotificationsScreen({super.key, required this.controller});

  static const List<int> _presetAdvanceDays = [14, 7, 3, 1, 0];

  String _dayLabel(int day) => day == 0 ? '到期當天' : '提前 $day 天';

  Future<void> _pickReminderTime(BuildContext context) async {
    final settings = controller.notificationSettings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (picked != null) {
      await controller.updateNotificationSettings(
        controller.notificationSettings.copyWith(
          reminderHour: picked.hour,
          reminderMinute: picked.minute,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已更新每日推播時間為 ${controller.notificationSettings.formattedTime}，並重新排程系統通知',
            ),
          ),
        );
      }
    }
  }

  Future<void> _addCustomAdvanceDay(BuildContext context) async {
    final ctrl = TextEditingController();
    final added = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增自訂提前提醒天數'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '提前天數（0 ~ 90）',
            hintText: '例如：5 或 30',
            suffixText: '天前',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val >= 0 && val <= 90) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );

    if (added != null) {
      final nextDays = {...controller.notificationSettings.advanceDays, added}
          .toList();
      await controller.updateNotificationSettings(
        controller.notificationSettings.copyWith(advanceDays: nextDays),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已新增「${_dayLabel(added)}」提醒並更新排程')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = controller.notificationSettings;
    final perm = controller.permissionStatus;
    final plans = controller.plannedNotifications;
    final osPending = controller.pendingNotifications;
    final dtFmt = DateFormat('yyyy/MM/dd HH:mm');

    final allDisplayDays = {
      ..._presetAdvanceDays,
      ...settings.advanceDays,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // 1. OS Permission & Device Status Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      perm.granted
                          ? Icons.notifications_active
                          : Icons.notifications_paused_outlined,
                      color: perm.granted
                          ? AppTheme.statusSuccess
                          : AppTheme.statusWarning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perm.granted ? '手機系統通知權限已開啟' : '尚未取得手機系統通知權限',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '系統時區：${perm.timezoneName} · OS 待觸發排程：${osPending.length} 則',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!perm.granted)
                      FilledButton.icon(
                        onPressed: () async {
                          await controller.requestNotificationPermissions();
                        },
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('開啟系統通知權限'),
                      ),
                    if (defaultTargetPlatform == TargetPlatform.android &&
                        !perm.canScheduleExactAlarms)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await controller.requestExactAlarmPermission();
                        },
                        icon: const Icon(Icons.alarm_on, size: 16),
                        label: const Text('允許精準鬧鐘排程 (Android)'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final count = await controller.syncNotificationsNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已與手機系統同步完成，共排程 $count 則保養提醒'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('立即重新同步'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Notification Rule Configuration Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '保養到期前推播規則',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.enabled,
                  onChanged: (v) async {
                    await controller.updateNotificationSettings(
                      controller.notificationSettings.copyWith(enabled: v),
                    );
                  },
                  title: const Text('啟用保養日期自動推播'),
                  subtitle: const Text('關閉後將清除所有已排程的手機系統通知'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.includeDocumentAlerts,
                  onChanged: settings.enabled
                      ? (v) async {
                          await controller.updateNotificationSettings(
                            controller.notificationSettings.copyWith(
                              includeDocumentAlerts: v,
                            ),
                          );
                        }
                      : null,
                  title: const Text('同步提醒定期驗車與車險到期'),
                  subtitle: const Text('依車輛檔案中的驗車日與保單到期日自動排程'),
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: settings.enabled,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('每日通知發送時間'),
                  subtitle: const Text('所有到期前提醒將於此時間準時推送'),
                  trailing: FilledButton.tonal(
                    onPressed:
                        settings.enabled ? () => _pickReminderTime(context) : null,
                    child: Text(
                      settings.formattedTime,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '提前提醒天數（可多選與自訂）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: settings.enabled
                          ? () => _addCustomAdvanceDay(context)
                          : null,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('自訂天數'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDisplayDays.map((day) {
                    final selected = settings.advanceDays.contains(day);
                    return FilterChip(
                      selected: selected,
                      label: Text(_dayLabel(day)),
                      onSelected: settings.enabled
                          ? (isSelected) async {
                              // Read the live settings: the value captured
                              // at build time is stale on a quick second tap.
                              final current = controller.notificationSettings;
                              final next = List<int>.from(current.advanceDays);
                              if (isSelected) {
                                next.add(day);
                              } else {
                                next.remove(day);
                              }
                              await controller.updateNotificationSettings(
                                current.copyWith(advanceDays: next),
                              );
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Real System Notification Testing Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '推播功能驗證與測試',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '可實際觸發 Android / iOS 原生系統通知橫幅與提示音，驗證背景提醒是否正常運作。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          await controller.sendTestNotificationNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已發送立即測試通知')),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_outlined, size: 16),
                        label: const Text('立即測試'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await controller.scheduleDelayedTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已排程 5 秒後通知，可將 App 切到背景測試'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('5 秒後排程測試'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Upcoming Planned OS Notifications List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '即將發送的系統通知排程 (${plans.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!settings.enabled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  '目前系統推播總開關已關閉',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          )
        else if (plans.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  '目前沒有未來的待發送排程（已逾期的項目請更新保養紀錄以重設下次到期日）',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < plans.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      plans[i].title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    subtitle: Text(
                      '排程觸發：${dtFmt.format(plans[i].scheduledAt)}\n${plans[i].body}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                    isThreeLine: true,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
