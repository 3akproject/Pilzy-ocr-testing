import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';

class UserSwitcherDialog extends StatefulWidget {
  final int currentUserId;
  final Function(int userId, String username)? onUserSelected;

  const UserSwitcherDialog({
    super.key,
    required this.currentUserId,
    this.onUserSelected,
  });

  @override
  State<UserSwitcherDialog> createState() => _UserSwitcherDialogState();
}

class _UserSwitcherDialogState extends State<UserSwitcherDialog> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DatabaseHelper.instance.getAllUsers();
    setState(() {
      _users = users.where((u) => u['id'] != widget.currentUserId).toList();
      _isLoading = false;
    });
  }

  Future<void> _selectUser(Map<String, dynamic> user) async {
    final userId = user['id'] as int;
    final username = user['username'] as String;
    final pinController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter PIN for $username'),
        content: PinInput(controller: pinController, hint: '4-digit PIN'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storedPin = user['pin'] as String;
      if (pinController.text == storedPin) {
        await SessionManager.saveUserSession(userId, username);
        if (mounted) {
          widget.onUserSelected?.call(userId, username);
          Navigator.pop(context, {'userId': userId, 'username': username});
        }
      } else {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Error'),
              content: const Text('Incorrect PIN'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return AlertDialog(
        title: const Text('No Other Users'),
        content: const Text('There are no other users available.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }

    // Calculate height based on user count (approximately 56 pixels per tile + padding)
    final maxHeight = (66.0 * _users.length).clamp(100.0, 400.0);

    return AlertDialog(
      title: const Text('Switch User'),
      content: SizedBox(
        width: double.maxFinite,
        height: maxHeight,
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (ctx, index) {
            final user = _users[index];
            return ListTile(
              title: Text(user['username'] as String),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => _selectUser(user),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
