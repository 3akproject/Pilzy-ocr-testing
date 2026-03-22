import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../services/database_helper.dart';
import '../models/medicine.dart';
import '../models/medicine_history.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  await plugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  if (response.actionId == 'snooze') {
    await _handleSnooze(plugin, response.payload, response.id!);
  }

  if (response.actionId == 'mark_taken') {
    await _handleMarkTaken(response.payload);
  }
}

Future<void> _handleSnooze(
    FlutterLocalNotificationsPlugin plugin,
    String? payload,
    int originalId,
) async {
  if (payload == null) return;

  final parts = payload.split('|');
  if (parts.length < 3) return;

  final medicineName = parts[0];
  final doseAmount = parts[1];
  final doseUnit = parts[2];

  final newTime =
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 3));

  await plugin.zonedSchedule(
    originalId, // 🔥 KEEP SAME ID
    'Snoozed Reminder',
    '$medicineName - $doseAmount $doseUnit',
    newTime,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_channel',
        'Medicine Reminders',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('samsung'),
        actions: const [
          AndroidNotificationAction(
            'snooze',
            'Snooze 3 min',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'mark_taken',
            'Mark as Taken',
            showsUserInterface: false,
          ),
        ],
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    payload: payload,
  );
}

Future<void> _handleMarkTaken(String? payload) async {
  if (payload == null) return;

  final parts = payload.split('|');
  if (parts.length < 3) return;

  final medicineName = parts[0];
  final doseAmount = double.tryParse(parts[1]) ?? 0;
  final doseUnit = parts[2];

  final medicines = await DatabaseHelper.instance.getAllMedicines();

  try {
    final medicine =
        medicines.firstWhere((m) => m.name == medicineName);

    final history = MedicineHistory(
      medicineId: medicine.id!,
      takenTime: DateTime.now(),
      doseAmount: doseAmount,
      doseUnit: doseUnit,
    );

    await DatabaseHelper.instance.insertMedicineHistory(history);

    final updatedMedicine = Medicine(
      id: medicine.id,
      name: medicine.name,
      frequency: medicine.frequency,
      times: medicine.times,
      doseAmount: medicine.doseAmount,
      doseUnit: medicine.doseUnit,
      totalQuantity: medicine.totalQuantity - doseAmount,
      alarmTone: medicine.alarmTone,
    );

    await DatabaseHelper.instance.updateMedicine(updatedMedicine);
  } catch (_) {
    return;
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidNotificationChannel channel =
        AndroidNotificationChannel(
      'medicine_channel',
      'Medicine Reminders',
      description: 'Channel for medicine reminders',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('samsung'),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.actionId == 'snooze') {
          await _handleSnooze(_local, details.payload, details.id!);
          return;
        }

        if (details.actionId == 'mark_taken') {
          await _handleMarkTaken(details.payload);
          return;
        }

        if (details.payload != null) {
          navigatorKey.currentState
              ?.pushNamed('/alarm', arguments: details.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground,
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required tz.TZDateTime dateTime,
    required String medicineName,
    required String doseAmount,
    required String doseUnit,
  }) async {
    await _local.zonedSchedule(
      id,
      'Medicine Reminder',
      '$medicineName - $doseAmount $doseUnit',
      dateTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_channel',
          'Medicine Reminders',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('samsung'),
          actions: const [
            AndroidNotificationAction(
              'snooze',
              'Snooze 3 min',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'mark_taken',
              'Mark as Taken',
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload:
          '$medicineName|$doseAmount|$doseUnit|${dateTime.toIso8601String()}',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _local.cancel(id);
  }

  Future<void> cancelAll() async {
    await _local.cancelAll();
  }
}