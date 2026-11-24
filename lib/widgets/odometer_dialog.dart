import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../state/garage_controller.dart';

Future<void> showOdometerDialog(
  BuildContext context,
  GarageController controller,
) async {
  final vehicle = controller.activeVehicle;
  final textCtrl = TextEditingController(text: '${vehicle.odometer}');

  final result = await showDialog<int>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('更新目前里程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vehicle.displayName}（${vehicle.plate}）',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '目前儀表板里程',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '更新後，系統將即時重新計算各保養項目的剩餘里程。',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(textCtrl.text.trim());
              if (parsed != null && parsed >= 0) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('儲存里程'),
          ),
        ],
      );
    },
  );

  if (result != null) {
    await controller.updateOdometer(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已更新里程為 ${NumberFormat('#,###').format(result)} km'),
        ),
      );
    }
  }
}
