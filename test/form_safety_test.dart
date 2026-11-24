import 'package:flutter_test/flutter_test.dart';
import 'package:garage_care/main.dart';
import 'package:garage_care/state/garage_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_service.dart';

Future<GarageController> _pumpApp(
  WidgetTester tester, {
  FakeNotificationService? notifications,
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller = GarageController(
    notifications: notifications ?? FakeNotificationService(),
  );
  await tester.runAsync(() => controller.init());
  await tester.pumpWidget(GarageCareApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _openNewRecordForm(WidgetTester tester) async {
  await tester.tap(find.text('新增紀錄'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, '保養 / 維修項目 *'),
    '測試保養',
  );
}

Future<void> _openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('更多選項'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a record cannot be saved with the odometer left empty',
      (tester) async {
    final controller = await _pumpApp(tester);
    final recordsBefore = controller.activeRecords.length;

    await _openNewRecordForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '當時里程 *'), '');
    await tester.ensureVisible(find.text('確認儲存'));
    await tester.tap(find.text('確認儲存'));
    await tester.pumpAndSettle();

    expect(find.text('請輸入里程'), findsOneWidget);
    expect(controller.activeRecords.length, recordsBefore);
  });

  testWidgets('tapping save twice stores one record and keeps the home screen',
      (tester) async {
    final fake = FakeNotificationService();
    final controller = await _pumpApp(tester, notifications: fake);
    final recordsBefore = controller.activeRecords.length;

    await _openNewRecordForm(tester);
    await tester.ensureVisible(find.text('確認儲存'));

    // Keep the first save in flight while the second tap lands.
    fake.syncDelay = const Duration(milliseconds: 300);
    await tester.tap(find.text('確認儲存'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('確認儲存'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(controller.activeRecords.length, recordsBefore + 1);
    expect(find.text('通知管理'), findsOneWidget);
  });

  testWidgets('resetting to demo data asks first', (tester) async {
    final controller = await _pumpApp(tester);
    await tester.runAsync(() => controller.updateOdometer(99999));
    await tester.pumpAndSettle();

    await _openMenu(tester, '重置示範資料');
    expect(find.text('重置為示範資料？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.activeVehicle.odometer, 99999);

    await _openMenu(tester, '重置示範資料');
    await tester.tap(find.text('全部重置'));
    await tester.pumpAndSettle();
    expect(controller.activeVehicle.odometer, 58420);
  });

  testWidgets('deleting a vehicle asks first', (tester) async {
    final controller = await _pumpApp(tester);
    final vehiclesBefore = controller.vehicles.length;

    await _openMenu(tester, '編輯目前車輛');
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(find.text('刪除這台車輛？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.vehicles.length, vehiclesBefore);

    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除車輛'));
    await tester.pumpAndSettle();
    expect(controller.vehicles.length, vehiclesBefore - 1);
  });
}
