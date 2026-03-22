import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/pin_input.dart';
import '../widgets/user_switcher_dialog.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../models/medicine.dart';
import '../models/medicine_history.dart';
import '../new_user_screen.dart';
import '../utils/seed_test_data.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  final Function(String)? onUsernameChanged;
  final int userId;
  final String username;

  const SettingsPage({
    super.key,
    this.onThemeModeChanged,
    this.onUsernameChanged,
    required this.userId,
    required this.username,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currentUsername;
  late String _currentPin;
  String _currentThemeMode = 'system';

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.username;
    _loadUserData();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await SessionManager.getThemeMode();
    setState(() => _currentThemeMode = mode ?? 'system');
  }

  Future<void> _loadUserData() async {
    try {
      final user =
          await DatabaseHelper.instance.getUserById(widget.userId);
      _currentPin = user['pin'] as String;
      _currentUsername = user['username'] as String;
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // ================= THEME MODE =================

  Future<void> _changeThemeMode(String mode) async {
    setState(() => _currentThemeMode = mode);
    await SessionManager.saveThemeMode(mode);

    if (widget.onThemeModeChanged != null) {
      ThemeMode themeMode;
      switch (mode) {
        case 'light':
          themeMode = ThemeMode.light;
          break;
        case 'dark':
          themeMode = ThemeMode.dark;
          break;
        default:
          themeMode = ThemeMode.system;
      }
      widget.onThemeModeChanged!(themeMode);
    }
  }



  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _currentUsername);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        final newUsername = controller.text.trim();
        await DatabaseHelper.instance.updateUsername(widget.userId, newUsername);
        setState(() => _currentUsername = newUsername);
        await SessionManager.saveUserSession(widget.userId, newUsername);
        widget.onUsernameChanged?.call(newUsername);
        _showSnackBar('Username updated successfully');
      } catch (e) {
        _showSnackBar('Error updating username: $e');
      }
    }
  }

  // ================= CHANGE PIN =================

  Future<void> _changePin() async {
    // Step 1: Confirm current PIN
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    final step1Result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Current PIN'),
        content: PinInput(
          controller: currentPinController,
          hint: 'Enter current PIN',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (step1Result != true) return;

    if (currentPinController.text != _currentPin) {
      _showSnackBar('Incorrect current PIN');
      return;
    }

    // Step 2: Set new PIN
    final step2Result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set New PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinInput(controller: newPinController, hint: 'New 4-digit PIN'),
            const SizedBox(height: 12),
            PinInput(
              controller: confirmPinController,
              hint: 'Confirm PIN',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (step2Result != true) return;

    final newPin = newPinController.text;
    final confirmPin = confirmPinController.text;

    if (newPin.length != 4 || confirmPin.length != 4) {
      _showSnackBar('PIN must be 4 digits');
      return;
    }

    if (newPin != confirmPin) {
      _showSnackBar('PINs do not match');
      return;
    }

    try {
      await DatabaseHelper.instance.updatePin(widget.userId, newPin);
      setState(() => _currentPin = newPin);
      _showSnackBar('PIN changed successfully');
    } catch (e) {
      _showSnackBar('Error changing PIN: $e');
    }
  }

  // ================= DELETE USER =================

  Future<void> _deleteUser() async {
    final pinController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This will permanently delete your account and all data. This cannot be undone.'),
            const SizedBox(height: 16),
            PinInput(controller: pinController, hint: 'Enter PIN to confirm'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (pinController.text != _currentPin) {
        _showSnackBar('Incorrect PIN');
        return;
      }

      try {
        await DatabaseHelper.instance.deleteUser(widget.userId);
        await SessionManager.clearSession();

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      } catch (e) {
        _showSnackBar('Error deleting account: $e');
      }
    }
  }

  // ================= ADD NEW USER =================

  Future<void> _addNewUser() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const NewUserScreen()),
    );

    if (result != null && result['userId'] != null) {
      final newUserId = result['userId'] as int;
      final newUsername = result['username'] as String;

      // Switch to new user
      await SessionManager.saveUserSession(newUserId, newUsername);

      if (!mounted) return;

      // Restart the app to load new user's home screen
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  // ================= SWITCH USER =================

  Future<void> _switchUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => UserSwitcherDialog(
        currentUserId: widget.userId,
      ),
    );

    if (result != null) {
      if (!mounted) return;
      // Restart the app to load new user's home screen
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  // ================= EXPORT DATA =================

  Future<void> _exportData() async {
    try {
      // Try to save to Downloads folder (/storage/emulated/0/Download)
      final String downloadsPath = '/storage/emulated/0/Download/Pilzy Backup';
      final backupDir = Directory(downloadsPath);
      
      // Create pilzy backup directory if it doesn't exist
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final medicines = await DatabaseHelper.instance
          .getAllMedicines(userId: widget.userId);
      final history = await DatabaseHelper.instance
          .getAllMedicineHistory(userId: widget.userId);

      // Load documents for this user
      final documentsFile = File('${(await getApplicationDocumentsDirectory()).path}/documents_${widget.userId}.json');
      List<dynamic> documents = [];
      if (await documentsFile.exists()) {
        final content = await documentsFile.readAsString();
        documents = jsonDecode(content);
      }

      final exportData = {
        'user': {
          'id': widget.userId,
          'username': _currentUsername,
        },
        'medicines': medicines.map((m) => m.toMap()).toList(),
        'history': history
            .map((h) => {
                  'medicineId': h.medicineId,
                  'takenTime': h.takenTime.toIso8601String(),
                  'doseAmount': h.doseAmount,
                  'doseUnit': h.doseUnit,
                })
            .toList(),
        'documents': documents,
        'exportDate': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(exportData);
      final fileName =
          'pilzy_backup_${_currentUsername}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('$downloadsPath/$fileName');

      await file.writeAsString(jsonString);

      // Format: pilzy_backup_username_YYYY-MM-DD_HH-MM-SS.json
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
      final readableFileName = 'pilzy_backup_${_currentUsername}_${dateStr}_$timeStr.json';
      
      print('✓ Export successful: $downloadsPath/$readableFileName');
      print('  📋 Medicines: ${medicines.length}');
      print('  📝 History entries: ${history.length}');
      print('  📎 Documents: ${documents.length}');
      _showSnackBar('Data exported successfully!\nFile: $readableFileName\nPath: Download/Pilzy Backup');
    } catch (e) {
      print('✗ Export error: $e');
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  // ================= IMPORT DATA =================

  Future<void> _importData() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      
      if (!status.isGranted) {
        _showSnackBar('Storage permission is required to import data');
        return;
      }

      final backupPath = '/storage/emulated/0/Download/Pilzy Backup';
      final backupDir = Directory(backupPath);
      
      // Check if backup directory exists
      if (!await backupDir.exists()) {
        _showSnackBar('Backup folder not found at: $backupPath\nPlease export data first.');
        return;
      }

      // List all JSON files in the backup folder
      final jsonFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      if (jsonFiles.isEmpty) {
        _showSnackBar('No backup files found in: $backupPath');
        return;
      }

      // Show dialog to select a backup file
      if (!mounted) return;
      
      final selectedFile = await showDialog<File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Backup File'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: jsonFiles.length,
              itemBuilder: (_, index) {
                final fileName = jsonFiles[index].path.split('/').last;
                return ListTile(
                  title: Text(fileName),
                  onTap: () => Navigator.pop(ctx, jsonFiles[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFile == null) return;

      // Read and import the selected file
      final jsonString = await selectedFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Parse medicines and create ID mapping (old ID -> new ID)
      final medicinesList = (data['medicines'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      Map<int, int> medicineIdMapping = {}; // old ID -> new ID
      
      for (var medData in medicinesList) {
        final oldId = medData['id'] as int? ?? 0;
        final medicine = Medicine(
          name: medData['name'] ?? '',
          frequency: medData['frequency'] ?? '',
          times: (medData['times'] as dynamic) is List 
              ? List<String>.from(medData['times'] as List)
              : (medData['times'] as String?)?.split(',') ?? [],
          doseAmount: (medData['doseAmount'] ?? 0).toDouble(),
          doseUnit: medData['doseUnit'] ?? '',
          totalQuantity: (medData['totalQuantity'] ?? 0).toDouble(),
          alarmTone: medData['alarmTone'] ?? 'default',
        );
        final newId = await DatabaseHelper.instance
            .insertMedicine(medicine, userId: widget.userId);
        
        // Map old ID to new ID
        if (oldId != 0) {
          medicineIdMapping[oldId] = newId;
        }
        
        print('📋 Imported medicine: ${medicine.name} | Old ID: $oldId → New ID: $newId');
      }

      // Parse history and use the ID mapping
      final historyList = (data['history'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      for (var histData in historyList) {
        final oldMedicineId = histData['medicineId'] as int? ?? 0;
        final newMedicineId = medicineIdMapping[oldMedicineId] ?? oldMedicineId;
        
        // Only insert if medicine exists
        if (newMedicineId == 0) {
          print('⚠️ Warning: History entry has unknown medicine ID: $oldMedicineId');
          continue;
        }
        
        final history = MedicineHistory(
          medicineId: newMedicineId,
          takenTime: DateTime.parse(histData['takenTime'] ?? DateTime.now().toIso8601String()),
          doseAmount: (histData['doseAmount'] ?? 0).toDouble(),
          doseUnit: histData['doseUnit'] ?? '',
        );
        await DatabaseHelper.instance
            .insertMedicineHistory(history, userId: widget.userId);
      }
      
      print('✅ Imported ${medicinesList.length} medicines and ${historyList.length} history entries');

      // Restore documents
      final documentsList = (data['documents'] as List<dynamic>?) ?? [];
      if (documentsList.isNotEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        final docFile = File('${docDir.path}/documents_${widget.userId}.json');
        await docFile.writeAsString(jsonEncode(documentsList));
        print('✅ Imported ${documentsList.length} documents');
      }

      print('✓ Import successful from: ${selectedFile.path}');
      _showSnackBar('Data imported successfully!');
    } catch (e) {
      print('✗ Import error: $e');
      _showSnackBar('Error importing data: $e');
    }
  }

  // ================= LOAD TEST DATA =================

  Future<void> _loadTestData() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Load Test Data?'),
          content: const Text(
            'This will add 4 medicines (Paracetamol, Cough Syrup, Antihistamine, Vitamin C) with 2 weeks of history.\n\nThis is for UI testing only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Load'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await seedTestData(widget.userId);
      _showSnackBar('Test data loaded successfully!');

      // Refresh the app or navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error loading test data: $e');
      _showSnackBar('Error loading test data: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= PROFILE SECTION =================
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Column(
                children: [
                  Text(
                    _currentUsername,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Name'),
                        onPressed: _editUsername,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.lock),
                        label: const Text('Change PIN'),
                        onPressed: _changePin,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= THEME SETTINGS =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('System Default'),
                            value: 'system',
                            groupValue: _currentThemeMode,
                            onChanged: (value) {
                              if (value != null) _changeThemeMode(value);
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Light Mode'),
                            value: 'light',
                            groupValue: _currentThemeMode,
                            onChanged: (value) {
                              if (value != null) _changeThemeMode(value);
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Dark Mode'),
                            value: 'dark',
                            groupValue: _currentThemeMode,
                            onChanged: (value) {
                              if (value != null) _changeThemeMode(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= DATA SECTION =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Management',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Backup Location:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Downloads/Pilzy Backup',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export Data'),
                      onPressed: _exportData,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text('Import Data'),
                      onPressed: _importData,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Load Test Data'),
                      onPressed: _loadTestData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= USER MANAGEMENT =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add New User'),
                      onPressed: _addNewUser,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_3),
                      label: const Text('Switch User'),
                      onPressed: _switchUser,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= DANGER ZONE =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Account'),
                  onPressed: _deleteUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
