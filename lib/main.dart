import 'package:material_ui/material_ui.dart';
import 'screens/home_shell.dart';
import 'state/garage_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = GarageController();
  runApp(GarageCareApp(controller: controller));
  await controller.init();
}

class GarageCareApp extends StatelessWidget {
  final GarageController controller;

  const GarageCareApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '車庫管家',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeShell(controller: controller),
    );
  }
}
