import 'package:flutter/material.dart';
import 'widgets/pin_input.dart';
import 'services/database_helper.dart';
import 'services/session_manager.dart';
import 'home_screen.dart';

class NewUserScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const NewUserScreen({super.key, this.onThemeModeChanged});

  @override
  State<NewUserScreen> createState() => _NewUserScreenState();
}

class _NewUserScreenState extends State<NewUserScreen> {
  final controller = TextEditingController();
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();

  String error = '';

  Future<void> _saveUser() async {
    final name = controller.text.trim();
    final pin = pinController.text;
    final confirmPin = confirmPinController.text;

    if (name.isEmpty || pin.length != 4 || confirmPin.length != 4) {
      setState(() => error = 'Enter name and 4-digit PIN');
      return;
    }

    if (pin != confirmPin) {
      setState(() => error = 'PINs do not match');
      return;
    }

    final userId = await DatabaseHelper.instance.insertUser(name, pin);
    print('✅ New user created: id=$userId, username=$name');

    // Save session
    await SessionManager.saveUserSession(userId, name);

    if (!mounted) return;

    // Navigate to HomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          username: name,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Nickname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            PinInput(
              controller: pinController,
              hint: 'Set 4-digit PIN',
            ),
            const SizedBox(height: 12),

            PinInput(
              controller: confirmPinController,
              hint: 'Confirm PIN',
            ),

            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveUser,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}