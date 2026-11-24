# 車庫管家 (GarageCare) — Android / iOS 個人車輛保養管理 App

使用 **Flutter (Dart)** 開發的跨平台（Android & iOS）個人車輛保養與手機系統通知管理應用程式。

## 核心功能

- **多台個人車輛管理（汽車／機車皆適用）**：快速切換車輛、更新目前儀表板里程、記錄機油黏度、輪胎規格、常用保養廠、定期驗車日與車險保單到期日。
- **里程＋時間雙條件保養倒數**：依每個項目的里程間隔（km）與時間間隔（月）自動判斷狀態（`已逾期` / `即將到期` / `狀態良好`），並計算車輛健康分數。
- **保養與維修紀錄連動**：登記完成保養時可勾選連動排程，自動更新該項目的上次保養日期與里程，並同步重新排程下次系統提醒。
- **手機原生系統通知管理（Android & iOS）**：
  - 採用 `flutter_local_notifications` + `timezone` + `flutter_timezone` 實作本機離線排程推播。
  - **可自訂提前提醒天數**（預設 `7 天前`、`3 天前`、`到期當天`，支援一鍵勾選 `14 天前`、`1 天前` 或新增任意 0–90 天自訂天數）。
  - **自訂每日推播時段**（預設 `09:00`）、單一保養項目獨立開關通知、驗車與車險到期同步提醒。
  - 內建權限檢查／一鍵授權、Android 精準鬧鐘授權、`立即測試通知` 與 `5 秒後排程測試`（可切到背景驗證），以及完整待觸發系統排程預覽清單。
  - 自動支援 Android 裝置重新開機後恢復排程 (`ScheduledNotificationBootReceiver`)，並針對 iOS 64 筆本機通知上限自動篩選最近 60 筆即將到期提醒。

## 專案結構

```text
lib/
├── main.dart                         # 應用程式入口與 Material 3 淺／深色主題
├── models/
│   ├── vehicle.dart                  # 車輛規格與證件期限模型
│   ├── maintenance_schedule.dart     # 保養排程與雙條件狀態評估邏輯
│   ├── service_record.dart           # 保養維修工單紀錄模型
│   └── notification_settings.dart    # 系統推播規則設定（提前天數、時段）
├── services/
│   ├── storage_service.dart          # SharedPreferences 本機儲存與預設示範資料
│   └── notification_service.dart     # Android / iOS 原生系統通知排程引擎
├── state/
│   └── garage_controller.dart        # 狀態管理與異動自動重算同步排程
├── screens/
│   ├── home_shell.dart               # 主框架、車輛切換器與底部導覽列
│   ├── overview_screen.dart          # 車輛總覽與重點保養倒數
│   ├── schedule_screen.dart          # 保養排程管理與單項通知開關
│   ├── history_screen.dart           # 保養維修紀錄搜尋與花費統計
│   └── notifications_screen.dart     # 手機系統通知管理中心
└── widgets/                          # 健康環形圖與各式表單 BottomSheet
```

## 開發與建置指令

```bash
# 1. 安裝套件
flutter pub get

# 2. 靜態檢查與測試
flutter analyze
flutter test

# 3. 執行於 Android / iOS 實體機或模擬器
flutter run

# 4. 建置 Android APK
flutter build apk --release

# 5. 建置 iOS (需於 macOS + Xcode 環境)
flutter build ios --release
```
