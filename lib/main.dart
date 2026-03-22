import 'package:flutter/material.dart';
import 'package:pilzy/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/session_manager.dart';
import 'screens/alarm_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MedicineReminderApp());
}

class MedicineReminderApp extends StatefulWidget {
  const MedicineReminderApp({super.key});

  @override
  State<MedicineReminderApp> createState() => _MedicineReminderAppState();
}

class _MedicineReminderAppState extends State<MedicineReminderApp> {
  late ThemeMode _themeMode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final savedMode = await SessionManager.getThemeMode();
    setState(() {
      _themeMode = SessionManager.getThemeModeEnum(savedMode);
      _isLoading = false;
    });
  }

  void _updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    SessionManager.saveThemeMode(modeString);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6B9676),
      brightness: Brightness.light,
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6B9676),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Pilzy',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      navigatorKey: NotificationService.instance.navigatorKey,
      home: SplashScreen(onThemeModeChanged: _updateThemeMode),
      onGenerateRoute: (settings) {
        if (settings.name == '/alarm') {
          final data = settings.arguments as String?;

          if (data == null || !data.contains('|')) {
            return null; // ignore invalid payload
          }

          final parts = data.split('|');

          if (parts.length < 5) {
            return null; // prevent RangeError
          }

          return MaterialPageRoute(
            builder: (_) => AlarmScreen(
              notificationId: int.parse(parts[0]),
              medicineName: parts[1],
              doseAmount: parts[2],
              doseUnit: parts[3],
              time: parts[4],
            ),
          );
        }
        return null;
      },
    );
  }
}