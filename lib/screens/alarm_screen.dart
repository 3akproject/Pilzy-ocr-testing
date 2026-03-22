import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final int notificationId;
  final String medicineName;
  final String doseAmount;
  final String doseUnit;
  final String time;

  const AlarmScreen({
    super.key,
    required this.notificationId,
    required this.medicineName,
    required this.doseAmount,
    required this.doseUnit,
    required this.time,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startAlarm();
  }

  Future<void> _startAlarm() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audios/samsung.mp3'));
  }

  Future<void> _stopAlarm() async {
    await _player.stop();

    // 🔥 Cancel the notification from tray
    await NotificationService.instance
        .cancelNotification(widget.notificationId);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTime =
        widget.time.length >= 16 ? widget.time.substring(11, 16) : widget.time;

    return Scaffold(
      backgroundColor: const Color(0xFFFFCDD2),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, size: 100, color: Colors.red),
              const SizedBox(height: 20),

              Text(
                displayTime,
                style: const TextStyle(fontSize: 28),
              ),

              const SizedBox(height: 20),

              Text(
                widget.medicineName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "${widget.doseAmount} ${widget.doseUnit}",
                style: const TextStyle(fontSize: 24),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                ),
                onPressed: _stopAlarm,
                child: const Text(
                  "STOP",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}