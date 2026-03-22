import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine.dart';
import '../models/medicine_history.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Map<String, dynamic>> getUserById(int id) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.first;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pilzy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        name TEXT,
        frequency TEXT,
        times TEXT,
        doseAmount REAL,
        doseUnit TEXT,
        totalQuantity REAL,
        alarmTone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medicine_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        medicineId INTEGER,
        takenTime TEXT,
        doseAmount REAL,
        doseUnit TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        pin TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE alert_time (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hour INTEGER,
        minute INTEGER
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medicine_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicineId INTEGER,
          takenTime TEXT,
          doseAmount REAL,
          doseUnit TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      // Add userId column to existing tables
      await db.execute('''
        ALTER TABLE medicines ADD COLUMN userId INTEGER DEFAULT 1
      ''');
      await db.execute('''
        ALTER TABLE medicine_history ADD COLUMN userId INTEGER DEFAULT 1
      ''');
    }
  }

  // ================= ALERT TIME =================

  Future<void> saveAlertTime(int hour, int minute) async {
    final db = await database;
    await db.delete('alert_time');
    await db.insert('alert_time', {
      'hour': hour,
      'minute': minute,
    });
  }

  Future<Map<String, dynamic>?> getAlertTime() async {
    final db = await database;
    final result = await db.query('alert_time');
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // ================= MEDICINES =================

  Future<int> insertMedicine(Medicine medicine, {int? userId}) async {
    final db = await database;
    final data = medicine.toMap();
    if (userId != null) {
      data['userId'] = userId;
    }
    return await db.insert('medicines', data);
  }

  Future<List<Medicine>> getAllMedicines({int? userId}) async {
    final db = await database;
    if (userId != null) {
      final result = await db.query(
        'medicines',
        where: 'userId = ?',
        whereArgs: [userId],
      );
      return result.map((map) => Medicine.fromMap(map)).toList();
    }
    final result = await db.query('medicines');
    return result.map((map) => Medicine.fromMap(map)).toList();
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // ================= MEDICINE HISTORY =================

  Future<int> insertMedicineHistory(MedicineHistory history, {int? userId}) async {
    final db = await database;
    final data = history.toMap();
    if (userId != null) {
      data['userId'] = userId;
    }
    return await db.insert('medicine_history', data);
  }

  Future<List<MedicineHistory>> getTodayMedicineHistory({int? userId}) async {
    final db = await database;

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (userId != null) {
      final result = await db.query(
        'medicine_history',
        where: 'userId = ? AND takenTime >= ?',
        whereArgs: [userId, todayStart.toIso8601String()],
      );
      return result.map((map) => MedicineHistory.fromMap(map)).toList();
    }

    final result = await db.query(
      'medicine_history',
      where: 'takenTime >= ?',
      whereArgs: [todayStart.toIso8601String()],
    );

    return result.map((map) => MedicineHistory.fromMap(map)).toList();
  }

  // ⭐ REQUIRED FOR HISTORY PAGE
  Future<List<MedicineHistory>> getAllMedicineHistory({int? userId}) async {
    final db = await database;
    if (userId != null) {
      final result = await db.query(
        'medicine_history',
        where: 'userId = ?',
        whereArgs: [userId],
      );
      return result.map((map) => MedicineHistory.fromMap(map)).toList();
    }
    final result = await db.query('medicine_history');
    return result.map((map) => MedicineHistory.fromMap(map)).toList();
  }

  Future<int> deleteMedicineHistory(int id) async {
    final db = await database;
    return await db.delete('medicine_history', where: 'id = ?', whereArgs: [id]);
  }

  // ================= USERS =================

  Future<int> insertUser(String username, String pin) async {
    final db = await database;
    return await db.insert('users', {'username': username, 'pin': pin});
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<String?> getUserPin(String username) async {
    final db = await database;
    final result =
        await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (result.isNotEmpty) return result.first['pin'] as String;
    return null;
  }

  Future<void> updateUsername(int id, String newName) async {
    final db = await database;
    await db.update('users', {'username': newName}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> updatePin(int id, String newPin) async {
    final db = await database;
    await db.update('users', {'pin': newPin}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    // Delete all medicines for this user (if user-specific medicines are stored)
    // For now, we're assuming medicines are shared, so we don't delete them
    
    // Delete user
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}