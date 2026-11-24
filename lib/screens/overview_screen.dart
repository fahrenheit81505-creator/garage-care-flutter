import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_schedule.dart';
import '../state/garage_controller.dart';
import '../utils/calendar_date.dart';
import '../theme/app_theme.dart';
import '../widgets/health_ring.dart';
import '../widgets/odometer_dialog.dart';
import '../widgets/record_form_sheet.dart';
import '../widgets/vehicle_form_sheet.dart';

class OverviewScreen extends StatelessWidget {
  final GarageController controller;
  final ValueChanged<int> onSwitchTab;

  const OverviewScreen({
    super.key,
    required this.controller,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = controller.activeVehicle;
    final evals = controller.evaluatedActiveSchedules;
    final numFmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy/MM/dd');
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final overdueCount =
        evals.where((e) => e.status == MaintenanceStatus.overdue).length;
    final soonCount =
        evals.where((e) => e.status == MaintenanceStatus.soon).length;
    final upcoming = evals.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Hero Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    HealthRing(score: controller.activeHealthScore),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle.plate} · ${vehicle.year} 年 · ${vehicle.fuelType}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _StatusChip(
                                label: overdueCount > 0
                                    ? '$overdueCount 項已逾期'
                                    : soonCount > 0
                                        ? '$soonCount 項即將到期'
                                        : '保養狀態良好',
                                color: overdueCount > 0
                                    ? AppTheme.statusError
                                    : soonCount > 0
                                        ? AppTheme.statusWarning
                                        : AppTheme.statusSuccess,
                              ),
                              _StatusChip(
                                label: controller.notificationSettings.enabled
                                    ? '系統推播已啟用'
                                    : '推播已暫停',
                                color: controller.notificationSettings.enabled
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => showOdometerDialog(context, controller),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '目前里程',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 13,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${numFmt.format(vehicle.odometer)} km',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSwitchTab(2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateTime.now().year} 年保養支出',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'NT\$ ${numFmt.format(controller.activeYearSpend)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Priority Maintenance Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '重點保養倒數',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            TextButton(
              onPressed: () => onSwitchTab(1),
              child: const Text('查看全部排程'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (upcoming.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '尚未設定保養排程，請前往「排程」頁籤新增項目',
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
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _UrgentScheduleTile(
                    evaluation: upcoming[i],
                    onComplete: () => showRecordFormSheet(
                      context,
                      controller,
                      prefillSchedule: upcoming[i].schedule,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Document & Specs Card
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '證件期限與車輛規格',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            TextButton(
              onPressed: () => showVehicleFormSheet(
                context,
                controller,
                editing: vehicle,
              ),
              child: const Text('編輯資料'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DocRow(
                  icon: Icons.fact_check_outlined,
                  label: '定期驗車期限',
                  date: vehicle.inspectionDue,
                  today: todayDate,
                  dateFmt: dateFmt,
                ),
                const SizedBox(height: 12),
                _DocRow(
                  icon: Icons.shield_outlined,
                  label: '車險保單到期',
                  date: vehicle.insuranceExpiry,
                  today: todayDate,
                  dateFmt: dateFmt,
                ),
                const Divider(height: 24),
                _SpecLine(
                  label: '建議機油',
                  value: vehicle.oilSpec.isNotEmpty ? vehicle.oilSpec : '未填寫',
                ),
                const SizedBox(height: 8),
                _SpecLine(
                  label: '輪胎規格',
                  value: vehicle.tireSpec.isNotEmpty ? vehicle.tireSpec : '未填寫',
                ),
                const SizedBox(height: 8),
                _SpecLine(
                  label: '常用保養廠',
                  value: vehicle.shopName.isNotEmpty
                      ? '${vehicle.shopName}${vehicle.shopPhone.isNotEmpty ? "（${vehicle.shopPhone}）" : ""}'
                      : '未填寫',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _UrgentScheduleTile extends StatelessWidget {
  final ScheduleEvaluation evaluation;
  final VoidCallback onComplete;

  const _UrgentScheduleTile({
    required this.evaluation,
    required this.onComplete,
  });

  Color _statusColor() {
    switch (evaluation.status) {
      case MaintenanceStatus.overdue:
        return AppTheme.statusError;
      case MaintenanceStatus.soon:
        return AppTheme.statusWarning;
      case MaintenanceStatus.good:
        return AppTheme.statusSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final numFmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy/MM/dd');

    final kmText = evaluation.kmRemaining != null
        ? (evaluation.kmRemaining! < 0
              ? '超出 ${numFmt.format(evaluation.kmRemaining!.abs())} km'
              : evaluation.kmRemaining == 0
              ? '已達保養里程'
              : '剩 ${numFmt.format(evaluation.kmRemaining)} km')
        : '不限里程';

    final dayText = evaluation.daysRemaining != null
        ? (evaluation.daysRemaining! < 0
              ? '逾期 ${evaluation.daysRemaining!.abs()} 天'
              : evaluation.daysRemaining == 0
              ? '今天到期'
              : '剩 ${evaluation.daysRemaining} 天 (${dateFmt.format(evaluation.dueDate!)})')
        : '不限日期';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        evaluation.schedule.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(label: evaluation.statusLabel, color: color),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('完成'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: evaluation.progress.clamp(0.05, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                evaluation.schedule.reminderEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$kmText · $dayText',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? date;
  final DateTime today;
  final DateFormat dateFmt;

  const _DocRow({
    required this.icon,
    required this.label,
    required this.date,
    required this.today,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    String statusText = '未設定';
    Color badgeColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (date != null) {
      final diff = calendarDaysBetween(today, date!);
      if (diff < 0) {
        statusText = '已逾期 ${diff.abs()} 天';
        badgeColor = AppTheme.statusError;
      } else if (diff == 0) {
        statusText = '今天到期';
        badgeColor = AppTheme.statusWarning;
      } else if (diff <= 30) {
        statusText = '剩餘 $diff 天';
        badgeColor = AppTheme.statusWarning;
      } else {
        statusText = '剩餘 $diff 天';
        badgeColor = AppTheme.statusSuccess;
      }
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                date != null ? dateFmt.format(date!) : '點擊右上「編輯資料」設定日期',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        _StatusChip(label: statusText, color: badgeColor),
      ],
    );
  }
}

class _SpecLine extends StatelessWidget {
  final String label;
  final String value;

  const _SpecLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
