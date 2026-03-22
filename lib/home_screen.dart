import 'package:flutter/material.dart';

import 'pages/medicines_page.dart';
import 'pages/schedules_page.dart';
import 'pages/history_page.dart';
import 'pages/documents_page.dart';
import 'pages/settings_page.dart';
import 'services/database_helper.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final Function(ThemeMode)? onThemeModeChanged;

  const HomeScreen({
    super.key,
    required this.username,
    this.onThemeModeChanged,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  int? userId;
  late String _currentUsername;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.username;
    _initializeUserAndPages();
  }

  Future<void> _initializeUserAndPages() async {
    final db = DatabaseHelper.instance;
    final users = await db.getAllUsers();
    final user = users.firstWhere((u) => u['username'] == _currentUsername);
    userId = user['id'] as int;
    setState(() {
      _initializePages();
    });
  }

  void _updateUsername(String newUsername) {
    setState(() {
      _currentUsername = newUsername;
      _initializePages(); // Recreate pages if username changes
    });
  }

  void _initializePages() {
    // Only initialize if userId is loaded
    if (userId == null) return;
    
    _pages = [
      MedicinesPage(userId: userId),
      SchedulesPage(userId: userId),
      HistoryPage(userId: userId),
      DocumentsPage(userId: userId),
      SettingsPage(
        userId: userId ?? 0,
        username: _currentUsername,
        onThemeModeChanged: widget.onThemeModeChanged,
        onUsernameChanged: _updateUsername,
      ),
    ];
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _selectedIndex == 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Hi, $_currentUsername"),
        ),
        body: userId == null || _pages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_outlined),
              label: "Medicines",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule),
              label: "Schedules",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              label: "Documents",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}