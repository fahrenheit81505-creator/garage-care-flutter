import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_schedule.dart';
import '../models/service_record.dart';
import '../state/garage_controller.dart';
import 'form_helpers.dart';

Future<void> showRecordFormSheet(
  BuildContext context,
  GarageController controller, {
  ServiceRecord? editing,
  MaintenanceSchedule? prefillSchedule,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _RecordFormSheet(
      controller: controller,
      editing: editing,
      prefillSchedule: prefillSchedule,
    ),
  );
}

class _RecordFormSheet extends StatefulWidget {
  final GarageController controller;
  final ServiceRecord? editing;
  final MaintenanceSchedule? prefillSchedule;

  const _RecordFormSheet({
    required this.controller,
    this.editing,
    this.prefillSchedule,
  });

  @override
  State<_RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<_RecordFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _odoCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _shopCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime _date;
  late ServiceCategory _category;
  late Set<String> _linkedScheduleIds;

  /// Fixed for the lifetime of the sheet so a repeated save updates the same
  /// record instead of adding another one.
  late final String _recordId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final pre = widget.prefillSchedule;
    final vehicle = widget.controller.activeVehicle;

    _recordId = e?.id ?? widget.controller.generateId('rec');
    _titleCtrl = TextEditingController(text: e?.title ?? pre?.name ?? '');
    _odoCtrl = TextEditingController(
      text: '${e?.odometer ?? vehicle.odometer}',
    );
    _costCtrl = TextEditingController(
      text: '${e?.cost ?? pre?.estimatedCost ?? 0}',
    );
    _shopCtrl = TextEditingController(text: e?.shop ?? vehicle.shopName);
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? pre?.category ?? ServiceCategory.maintenance;
    _linkedScheduleIds = {
      ...?e?.linkedScheduleIds,
      if (e == null && pre != null) pre.id,
    };
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _odoCtrl.dispose();
    _costCtrl.dispose();
    _shopCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final record = ServiceRecord(
      id: _recordId,
      vehicleId:
          widget.editing?.vehicleId ?? widget.controller.activeVehicle.id,
      title: _titleCtrl.text.trim(),
      date: DateTime(_date.year, _date.month, _date.day),
      odometer: int.tryParse(_odoCtrl.text.trim()) ?? 0,
      category: _category,
      cost: int.tryParse(_costCtrl.text.trim()) ?? 0,
      shop: _shopCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      linkedScheduleIds: _linkedScheduleIds.toList(),
    );

    final saved = await runStorageAction(
      context,
      () => widget.controller.saveRecord(record),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _linkedScheduleIds.isNotEmpty ? '已儲存保養紀錄，並自動重設下次到期提醒' : '已儲存保養維修紀錄',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await confirmDestructive(
      context,
      title: '刪除這筆紀錄？',
      message: '「${widget.editing!.title}」將被永久刪除，連動排程的下次到期日會依其餘紀錄重新計算。此動作無法復原。',
      confirmLabel: '刪除',
    );
    if (!confirmed || !mounted || _busy) return;
    setState(() => _busy = true);
    final deleted = await runStorageAction(
      context,
      () => widget.controller.deleteRecord(widget.editing!.id),
    );
    if (!mounted) return;
    if (!deleted) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final dateFmt = DateFormat('yyyy/MM/dd');
    final schedules = widget.controller.activeSchedules;

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
                    isEdit
                        ? '編輯保養紀錄'
                        : widget.prefillSchedule != null
                            ? '完成保養登記'
                            : '新增保養維修紀錄',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (isEdit)
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
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
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '保養 / 維修項目 *',
                  hintText: '例如：6 萬公里定期保養',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '請輸入項目名稱' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(dateFmt.format(_date)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _odoCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '當時里程 *',
                        suffixText: 'km',
                      ),
                      validator: (v) =>
                          requiredWholeNumber(v, emptyMessage: '請輸入里程'),
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
                      decoration: const InputDecoration(labelText: '分類'),
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
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '花費金額',
                        prefixText: 'NT\$ ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shopCtrl,
                decoration: const InputDecoration(
                  labelText: '保養廠 / 服務地點',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '工單明細與備註',
                ),
              ),
              if (schedules.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '連動重設以下排程的下次到期日與系統通知：',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: schedules.map((sch) {
                    final selected = _linkedScheduleIds.contains(sch.id);
                    return FilterChip(
                      selected: selected,
                      label: Text(sch.name),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _linkedScheduleIds.add(sch.id);
                          } else {
                            _linkedScheduleIds.remove(sch.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(isEdit ? '儲存修改' : '確認儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
