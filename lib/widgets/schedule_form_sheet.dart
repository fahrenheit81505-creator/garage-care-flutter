import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_schedule.dart';
import '../state/garage_controller.dart';

Future<void> showScheduleFormSheet(
  BuildContext context,
  GarageController controller, {
  MaintenanceSchedule? editing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _ScheduleFormSheet(
      controller: controller,
      editing: editing,
    ),
  );
}

class _ScheduleFormSheet extends StatefulWidget {
  final GarageController controller;
  final MaintenanceSchedule? editing;

  const _ScheduleFormSheet({
    required this.controller,
    this.editing,
  });

  @override
  State<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _intervalKmCtrl;
  late final TextEditingController _intervalMonthsCtrl;
  late final TextEditingController _lastKmCtrl;
  late final TextEditingController _estCostCtrl;
  late final TextEditingController _notesCtrl;

  late ServiceCategory _category;
  late DateTime _lastDate;
  late bool _reminderEnabled;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final vehicle = widget.controller.activeVehicle;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _intervalKmCtrl = TextEditingController(text: '${e?.intervalKm ?? 10000}');
    _intervalMonthsCtrl =
        TextEditingController(text: '${e?.intervalMonths ?? 6}');
    _lastKmCtrl =
        TextEditingController(text: '${e?.lastKm ?? vehicle.odometer}');
    _estCostCtrl = TextEditingController(text: '${e?.estimatedCost ?? 0}');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? ServiceCategory.maintenance;
    _lastDate = e?.lastDate ?? DateTime.now();
    _reminderEnabled = e?.reminderEnabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _intervalKmCtrl.dispose();
    _intervalMonthsCtrl.dispose();
    _lastKmCtrl.dispose();
    _estCostCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final schedule = MaintenanceSchedule(
      id: widget.editing?.id ?? widget.controller.generateId('sch'),
      vehicleId: widget.editing?.vehicleId ?? widget.controller.activeVehicle.id,
      name: _nameCtrl.text.trim(),
      category: _category,
      intervalKm: int.tryParse(_intervalKmCtrl.text.trim()) ?? 0,
      intervalMonths: int.tryParse(_intervalMonthsCtrl.text.trim()) ?? 0,
      lastKm: int.tryParse(_lastKmCtrl.text.trim()) ?? 0,
      lastDate: DateTime(_lastDate.year, _lastDate.month, _lastDate.day),
      estimatedCost: int.tryParse(_estCostCtrl.text.trim()) ?? 0,
      notes: _notesCtrl.text.trim(),
      reminderEnabled: _reminderEnabled,
    );

    await widget.controller.saveSchedule(schedule);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editing == null ? '已建立保養排程並更新系統推播' : '已更新保養排程並同步系統推播',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final dateFmt = DateFormat('yyyy/MM/dd');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? '編輯保養排程' : '新增保養排程',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (isEdit)
                    TextButton.icon(
                      onPressed: () async {
                        await widget.controller
                            .deleteSchedule(widget.editing!.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('刪除'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '保養項目名稱 *',
                  hintText: '例如：更換機油與機油濾芯',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '請輸入項目名稱' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _intervalKmCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '週期里程',
                        suffixText: 'km',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _intervalMonthsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '週期時間',
                        suffixText: '個月',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lastKmCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '上次保養里程',
                        suffixText: 'km',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _lastDate,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _lastDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('上次：${dateFmt.format(_lastDate)}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ServiceCategory>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: '類別'),
                      items: ServiceCategory.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _estCostCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '預估費用',
                        prefixText: 'NT\$ ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: '備註 / 料號規格',
                  hintText: '例如：原廠 0W-16 機油、墊片',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
                title: const Text('開啟此項目的手機系統到期推播'),
                subtitle: Text(
                  '將於到期前 ${widget.controller.notificationSettings.advanceDays.map((d) => d == 0 ? "當天" : "$d天").join("、")} 推播通知',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(isEdit ? '儲存變更' : '建立排程'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
