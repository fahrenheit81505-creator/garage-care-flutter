import 'package:material_ui/material_ui.dart';
import '../state/garage_controller.dart';
import '../widgets/form_helpers.dart';
import '../widgets/odometer_dialog.dart';
import '../widgets/record_form_sheet.dart';
import '../widgets/schedule_form_sheet.dart';
import '../widgets/vehicle_form_sheet.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'overview_screen.dart';
import 'schedule_screen.dart';

class HomeShell extends StatefulWidget {
  final GarageController controller;

  const HomeShell({super.key, required this.controller});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  void _openVehicleSwitcher() {
    final vehicles = widget.controller.vehicles;
    final activeId = widget.controller.activeVehicleId;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '切換個人車輛',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showVehicleFormSheet(context, widget.controller);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新增車輛'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...vehicles.map(
                  (v) => ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selected: v.id == activeId,
                    leading: CircleAvatar(
                      child: Icon(
                        v.fuelType.contains('機車')
                            ? Icons.two_wheeler
                            : Icons.directions_car_outlined,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      v.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${v.plate} · ${v.year} 年 · ${v.odometer} km'),
                    trailing: v.id == activeId
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    onTap: () async {
                      await widget.controller.selectVehicle(v.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildFab() {
    if (_tabIndex == 0 || _tabIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () => showRecordFormSheet(context, widget.controller),
        icon: const Icon(Icons.add),
        label: const Text('新增紀錄'),
      );
    }
    if (_tabIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: () => showScheduleFormSheet(context, widget.controller),
        icon: const Icon(Icons.add_task),
        label: const Text('新增排程'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (widget.controller.loadFailed) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '無法讀取車庫資料',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '已儲存的資料沒有被變更，請再試一次。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: widget.controller.init,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重試'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final vehicle = widget.controller.activeVehicle;
        final alertCount = widget.controller.activeAlertCount;
        final unreadable = widget.controller.unreadableSections;

        final screens = [
          OverviewScreen(
            controller: widget.controller,
            onSwitchTab: (idx) => setState(() => _tabIndex = idx),
          ),
          ScheduleScreen(controller: widget.controller),
          HistoryScreen(controller: widget.controller),
          NotificationsScreen(controller: widget.controller),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _openVehicleSwitcher,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  vehicle.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down, size: 20),
                            ],
                          ),
                          Text(
                            '車庫管家 · ${vehicle.plate}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
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
              ),
            ),
            actions: [
              IconButton(
                tooltip: '快速更新里程',
                icon: const Icon(Icons.speed_outlined),
                onPressed: () => showOdometerDialog(context, widget.controller),
              ),
              PopupMenuButton<String>(
                tooltip: '更多選項',
                onSelected: (value) async {
                  if (value == 'add_vehicle') {
                    await showVehicleFormSheet(context, widget.controller);
                  } else if (value == 'edit_vehicle') {
                    await showVehicleFormSheet(
                      context,
                      widget.controller,
                      editing: vehicle,
                    );
                  } else if (value == 'reset_demo') {
                    final confirmed = await confirmDestructive(
                      context,
                      title: '重置為示範資料？',
                      message: '目前所有車輛、保養排程、保養紀錄與通知設定都會被示範資料取代。此動作無法復原。',
                      confirmLabel: '全部重置',
                    );
                    if (!confirmed) return;
                    await widget.controller.resetDemoData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已重置為預設示範車輛資料')),
                      );
                    }
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'add_vehicle',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.add_circle_outline),
                      title: Text('新增車輛'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit_vehicle',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('編輯目前車輛'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'reset_demo',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.restart_alt),
                      title: Text('重置示範資料'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (unreadable.isNotEmpty)
                MaterialBanner(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  content: Text(
                    '部分已儲存的資料無法讀取（${unreadable.join('、')}），'
                    '無法讀取的項目已略過，原始資料另存備份。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.controller.dismissStorageWarning,
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: _tabIndex, children: screens),
              ),
            ],
          ),
          floatingActionButton: _buildFab(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: '總覽',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: alertCount > 0,
                  label: Text('$alertCount'),
                  child: const Icon(Icons.build_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: alertCount > 0,
                  label: Text('$alertCount'),
                  child: const Icon(Icons.build),
                ),
                label: '保養排程',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: '紀錄',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: !widget.controller.permissionStatus.granted,
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: !widget.controller.permissionStatus.granted,
                  child: const Icon(Icons.notifications),
                ),
                label: '通知管理',
              ),
            ],
          ),
        );
      },
    );
  }
}
