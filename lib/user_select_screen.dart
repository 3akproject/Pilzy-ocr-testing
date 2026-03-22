import 'package:flutter/material.dart';

import 'pin_verify_screen.dart';
import 'services/database_helper.dart';
import 'new_user_screen.dart';

class UserSelectScreen extends StatefulWidget {
  const UserSelectScreen({super.key});

  @override
  State<UserSelectScreen> createState() => _UserSelectScreenState();
}

class _UserSelectScreenState extends State<UserSelectScreen> {
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    users = await DatabaseHelper.instance.getAllUsers();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Switch User')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final username = user['username'] as String;

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color.fromARGB(255, 158, 158, 158),
                    child: Icon(Icons.person),
                  ),
                  title: Text(username),
                  trailing: const Icon(Icons.lock_outline),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PinVerifyScreen(username: username),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text("Create New User"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NewUserScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}