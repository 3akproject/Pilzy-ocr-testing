import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/session_manager.dart';
import 'home_screen.dart';
import 'widgets/pin_input.dart';

class PinVerifyScreen extends StatefulWidget {
  final String username;
  const PinVerifyScreen({super.key, required this.username});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final pinController = TextEditingController();
  String error = '';

  Future<void> _verify() async {
    final db = DatabaseHelper.instance;
    final users = await db.getAllUsers();
    final user = users.firstWhere((u) => u['username'] == widget.username);

    final savedPin = user['pin'] as String;
    final userId = user['id'] as int;

    if (pinController.text == savedPin) {
      await SessionManager.saveUserSession(userId, widget.username);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(username: widget.username),
        ),
      );
    } else {
      setState(() => error = 'Wrong PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            PinInput(controller: pinController, hint: 'Enter PIN'),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _verify, child: const Text('Unlock')),
          ],
        ),
      ),
    );
  }
}