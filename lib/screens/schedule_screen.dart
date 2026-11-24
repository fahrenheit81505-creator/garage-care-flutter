import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_schedule.dart';
import '../state/garage_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/record_form_sheet.dart';
import '../widgets/schedule_form_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  final GarageController controller;

  const ScheduleScreen({super.key, required this.controller});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  MaintenanceStatus? _filter;

  Color _colorFor(MaintenanceStatus status) {
    switch (status) {
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
    final all = widget.controller.evaluatedActiveSchedules;
    final filtered = _filter == null
        ? all
        : all.where((e) => e.status == _filter).toList();
    final numFmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy/MM/dd');

    final overdueCount =
        all.where((e) => e.status == MaintenanceStatus.overdue).length;
    final soonCount =
        all.where((e) => e.status == MaintenanceStatus.soon).length;
    final goodCount =
        all.where((e) => e.status == MaintenanceStatus.good).length;

    return Column(
      children: [
        // Status Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('全部 (${all.length})'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('已逾期 ($overdueCount)'),
                selected: _filter == MaintenanceStatus.overdue,
                onSelected: (_) =>
                    setState(() => _filter = MaintenanceStatus.overdue),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('即將到期 ($soonCount)'),
                selected: _filter == MaintenanceStatus.soon,
                onSelected: (_) =>
                    setState(() => _filter = MaintenanceStatus.soon),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('狀態良好 ($goodCount)'),
                selected: _filter == MaintenanceStatus.good,
                onSelected: (_) =>
                    setState(() => _filter = MaintenanceStatus.good),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '此分類目前沒有保養項目',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final eval = filtered[idx];
                    final sch = eval.schedule;
                    final color = _colorFor(eval.status);

                    final kmDesc = eval.kmRemaining != null
                        ? (eval.kmRemaining! <= 0
                            ? '超出 ${numFmt.format(eval.kmRemaining!.abs())} km（每 ${numFmt.format(sch.intervalKm)} km）'
                            : '剩餘 ${numFmt.format(eval.kmRemaining)} km（每 ${numFmt.format(sch.intervalKm)} km）')
                        : '未設定里程週期';

                    final dateDesc = eval.daysRemaining != null
                        ? (eval.daysRemaining! <= 0
                            ? '逾期 ${eval.daysRemaining!.abs()} 天（預定 ${dateFmt.format(eval.dueDate!)}）'
                            : '剩餘 ${eval.daysRemaining} 天（預定 ${dateFmt.format(eval.dueDate!)}）')
                        : '未設定時間週期';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            sch.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  color.withValues(alpha: 0.13),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              eval.statusLabel,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: color,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '上次：${dateFmt.format(sch.lastDate)} · ${numFmt.format(sch.lastKm)} km${sch.estimatedCost > 0 ? " · 預估 NT\$ ${numFmt.format(sch.estimatedCost)}" : ""}',
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
                                IconButton(
                                  tooltip: sch.reminderEnabled
                                      ? '點擊關閉此項目系統通知'
                                      : '點擊開啟此項目系統通知',
                                  icon: Icon(
                                    sch.reminderEnabled
                                        ? Icons.notifications_active
                                        : Icons.notifications_off_outlined,
                                    color: sch.reminderEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await widget.controller
                                        .toggleScheduleReminder(
                                      sch.id,
                                      !sch.reminderEnabled,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            !sch.reminderEnabled
                                                ? '已開啟「${sch.name}」的系統到期提醒'
                                                : '已關閉「${sch.name}」的系統到期提醒',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: eval.progress.clamp(0.05, 1.0),
                                minHeight: 6,
                                color: color,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '里程：$kmDesc\n日期：$dateDesc',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.45,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            if (sch.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '備註：${sch.notes}',
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
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => showScheduleFormSheet(
                                    context,
                                    widget.controller,
                                    editing: sch,
                                  ),
                                  child: const Text('編輯週期'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () => showRecordFormSheet(
                                    context,
                                    widget.controller,
                                    prefillSchedule: sch,
                                  ),
                                  child: const Text('登記完成'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
