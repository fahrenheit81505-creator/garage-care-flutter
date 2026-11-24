import 'package:material_ui/material_ui.dart';

/// Asks before an action that cannot be undone. Resolves to true only when
/// the user picks the destructive button.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Runs a save or delete. When it throws, tells the user and returns false so
/// the caller can re-enable its buttons instead of leaving the form stuck.
Future<bool> runStorageAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (e) {
    debugPrint('storage action failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失敗，請再試一次')));
    }
    return false;
  }
}

/// Validator for a required whole-number field such as an odometer reading.
String? requiredWholeNumber(String? value, {required String emptyMessage}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return emptyMessage;
  if (int.tryParse(text) == null) return '請輸入有效的數字';
  return null;
}
