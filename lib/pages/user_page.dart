import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/database_helper.dart';
import '../new_user_screen.dart';
import '../user_select_screen.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String username = "User";
  String pin = "1234";
  int? userId;

  File? profileImage;
  bool hasMultipleUsers = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUser();
    await _loadProfileImage();
    await _checkUsers();
  }

  // ================= LOAD CURRENT USER =================

  Future<void> _loadUser() async {
    final users = await DatabaseHelper.instance.getAllUsers();

    if (users.isNotEmpty) {
      final user = users.first; // TEMP: first user until session wiring
      userId = user['id'] as int;
      username = user['username'] as String;
      pin = user['pin'] as String;
      if (mounted) setState(() {});
    }
  }

  // ================= USERS CHECK =================

  Future<void> _checkUsers() async {
    final users = await DatabaseHelper.instance.getAllUsers();
    if (!mounted) return;
    setState(() => hasMultipleUsers = users.length > 1);
  }

  void _goToAddUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewUserScreen()),
    );
    _initialize();
  }

  void _goToSwitchUser() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserSelectScreen()),
    );
  }

  // ================= PROFILE IMAGE =================

  Future<void> _loadProfileImage() async {
    if (userId == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/profile_$userId.png');

    if (await file.exists()) {
      if (mounted) setState(() => profileImage = file);
    }
  }

  Future<void> _pickProfileImage() async {
    if (userId == null) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(result.files.single.path!)
        .copy('${dir.path}/profile_$userId.png');

    setState(() => profileImage = saved);
  }

  // ================= EDIT USERNAME =================

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: username);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Username"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save")),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      setState(() => username = controller.text.trim());
    }
  }

  // ================= EDIT PIN =================

  Future<void> _editPin() async {
    final controller = TextEditingController(text: pin);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change PIN"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save")),
        ],
      ),
    );

    if (ok == true && controller.text.length == 4) {
      setState(() => pin = controller.text);
    }
  }

  // ================= DELETE USER =================

  Future<void> _confirmDeleteUser() async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Enter PIN"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (ok == true && controller.text == pin) {
      if (profileImage != null && await profileImage!.exists()) {
        await profileImage!.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User Deleted")),
      );
      Navigator.pop(context);
    } else if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect PIN")),
      );
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Profile")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    profileImage != null ? FileImage(profileImage!) : null,
                child: profileImage == null
                    ? const Icon(Icons.person, size: 55)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Username"),
            subtitle: Text(username),
            trailing: const Icon(Icons.edit),
            onTap: _editUsername,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("PIN"),
            subtitle: const Text("••••"),
            trailing: const Icon(Icons.edit),
            onTap: _editPin,
          ),
          const Divider(height: 40),
          hasMultipleUsers
              ? ListTile(
                  leading:
                      const Icon(Icons.switch_account, color: Colors.blue),
                  title: const Text("Switch User"),
                  onTap: _goToSwitchUser,
                )
              : ListTile(
                  leading:
                      const Icon(Icons.person_add, color: Colors.green),
                  title: const Text("Add User"),
                  onTap: _goToAddUser,
                ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Delete User"),
            onTap: _confirmDeleteUser,
          ),
        ],
      ),
    );
  }
}