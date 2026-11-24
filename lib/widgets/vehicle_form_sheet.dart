import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../state/garage_controller.dart';
import 'form_helpers.dart';

const List<String> _fuelOptions = [
  '汽油',
  '油電 Hybrid',
  '純電 EV',
  '柴油',
  '汽油（機車）',
  '電動機車',
];

Future<void> showVehicleFormSheet(
  BuildContext context,
  GarageController controller, {
  Vehicle? editing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _VehicleFormSheet(
      controller: controller,
      editing: editing,
    ),
  );
}

class _VehicleFormSheet extends StatefulWidget {
  final GarageController controller;
  final Vehicle? editing;

  const _VehicleFormSheet({
    required this.controller,
    this.editing,
  });

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _odoCtrl;
  late final TextEditingController _oilCtrl;
  late final TextEditingController _tireCtrl;
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _shopPhoneCtrl;

  late String _fuelType;
  DateTime? _inspectionDue;
  DateTime? _insuranceExpiry;
  bool _addDefaults = true;

  /// Fixed for the lifetime of the sheet so a repeated save updates the same
  /// vehicle instead of adding another one.
  late final String _vehicleId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final v = widget.editing;
    _vehicleId = v?.id ?? widget.controller.generateId('veh');
    _brandCtrl = TextEditingController(text: v?.brand ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _yearCtrl = TextEditingController(text: '${v?.year ?? DateTime.now().year}');
    _odoCtrl = TextEditingController(text: '${v?.odometer ?? 0}');
    _oilCtrl = TextEditingController(text: v?.oilSpec ?? '');
    _tireCtrl = TextEditingController(text: v?.tireSpec ?? '');
    _shopNameCtrl = TextEditingController(text: v?.shopName ?? '');
    _shopPhoneCtrl = TextEditingController(text: v?.shopPhone ?? '');
    _fuelType =
        _fuelOptions.contains(v?.fuelType) ? v!.fuelType : _fuelOptions.first;
    _inspectionDue = v?.inspectionDue;
    _insuranceExpiry = v?.insuranceExpiry;
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _yearCtrl.dispose();
    _odoCtrl.dispose();
    _oilCtrl.dispose();
    _tireCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2015),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final vehicle = Vehicle(
      id: _vehicleId,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      plate: _plateCtrl.text.trim().toUpperCase(),
      year: int.tryParse(_yearCtrl.text.trim()) ?? DateTime.now().year,
      odometer: int.tryParse(_odoCtrl.text.trim()) ?? 0,
      fuelType: _fuelType,
      oilSpec: _oilCtrl.text.trim(),
      tireSpec: _tireCtrl.text.trim(),
      shopName: _shopNameCtrl.text.trim(),
      shopPhone: _shopPhoneCtrl.text.trim(),
      inspectionDue: _inspectionDue,
      insuranceExpiry: _insuranceExpiry,
    );

    final saved = await runStorageAction(
      context,
      () => widget.controller.saveVehicle(
        vehicle,
        addDefaultSchedules: widget.editing == null && _addDefaults,
      ),
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
          widget.editing == null
              ? '已新增車輛 ${vehicle.displayName}'
              : '已更新車輛資料並同步通知排程',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await confirmDestructive(
      context,
      title: '刪除這台車輛？',
      message:
          '「${widget.editing!.displayName}」以及它的所有保養排程、保養紀錄與系統提醒都會被永久刪除。此動作無法復原。',
      confirmLabel: '刪除車輛',
    );
    if (!confirmed || !mounted || _busy) return;
    setState(() => _busy = true);
    final deleted = await runStorageAction(
      context,
      () => widget.controller.deleteVehicle(widget.editing!.id),
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
    final dateFmt = DateFormat('yyyy/MM/dd');
    final isEdit = widget.editing != null;

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
                    isEdit ? '編輯車輛資料' : '新增個人車輛',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (isEdit && widget.controller.vehicles.length > 1)
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandCtrl,
                      decoration: const InputDecoration(
                        labelText: '品牌 *',
                        hintText: 'Toyota / Yamaha',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '請輸入品牌' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(
                        labelText: '車型 *',
                        hintText: 'RAV4 / CR-V',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '請輸入車型' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _plateCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: '車牌號碼 *',
                        hintText: 'ABC-1234',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '請輸入車牌' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: '年份'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _odoCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '目前里程 *',
                        suffixText: 'km',
                      ),
                      validator: (v) =>
                          requiredWholeNumber(v, emptyMessage: '請輸入里程'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _fuelType,
                      decoration: const InputDecoration(labelText: '動力類型'),
                      items: _fuelOptions
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _fuelType = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _oilCtrl,
                      decoration: const InputDecoration(
                        labelText: '機油規格',
                        hintText: '0W-20 全合成',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tireCtrl,
                      decoration: const InputDecoration(
                        labelText: '輪胎規格',
                        hintText: '225/60 R18',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(
                        initial: _inspectionDue,
                        onPicked: (d) => _inspectionDue = d,
                      ),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(
                        _inspectionDue != null
                            ? '驗車：${dateFmt.format(_inspectionDue!)}'
                            : '設定驗車日',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(
                        initial: _insuranceExpiry,
                        onPicked: (d) => _insuranceExpiry = d,
                      ),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: Text(
                        _insuranceExpiry != null
                            ? '車險：${dateFmt.format(_insuranceExpiry!)}'
                            : '設定車險到期日',
                        overflow: TextOverflow.ellipsis,
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
                      controller: _shopNameCtrl,
                      decoration: const InputDecoration(labelText: '常用保養廠'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _shopPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: '保養廠電話'),
                    ),
                  ),
                ],
              ),
              if (!isEdit) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _addDefaults,
                  onChanged: (v) => setState(() => _addDefaults = v ?? true),
                  title: const Text('自動建立常用保養排程'),
                  subtitle: const Text('機油與濾芯、輪胎對調、冷氣濾網'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(isEdit ? '儲存變更' : '加入車庫'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
