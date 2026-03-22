import 'package:pilzy/models/medicine.dart';
import 'package:pilzy/models/medicine_history.dart';
import 'package:pilzy/services/database_helper.dart';

/// Creates sample medicine history for testing UI
/// Call this from your app to populate test data
Future<void> seedTestData(int userId) async {
  print('🌱 Seeding test data for userId=$userId...');
  
  try {
    // Create medicines for cold and fever
    final medicines = [
      Medicine(
        name: 'Paracetamol',
        frequency: 'Daily',
        times: ['08:00', '14:00', '20:00'],
        doseAmount: 2.0,
        doseUnit: 'tablets',
        totalQuantity: 20.0,
        alarmTone: 'default',
      ),
      Medicine(
        name: 'Cough Syrup',
        frequency: 'Daily',
        times: ['10:00', '18:00'],
        doseAmount: 5.0,
        doseUnit: 'ml',
        totalQuantity: 100.0,
        alarmTone: 'default',
      ),
      Medicine(
        name: 'Antihistamine',
        frequency: 'Daily',
        times: ['12:00', '22:00'],
        doseAmount: 1.0,
        doseUnit: 'tablet',
        totalQuantity: 14.0,
        alarmTone: 'default',
      ),
      Medicine(
        name: 'Vitamin C',
        frequency: 'Daily',
        times: ['09:00'],
        doseAmount: 1.0,
        doseUnit: 'tablet',
        totalQuantity: 14.0,
        alarmTone: 'default',
      ),
    ];

    // Insert medicines
    List<int> medicineIds = [];
    for (var med in medicines) {
      final id = await DatabaseHelper.instance.insertMedicine(med, userId: userId);
      medicineIds.add(id);
      print('✅ Added medicine: ${med.name} (id=$id)');
    }

    // Create history for the past 14 days
    final now = DateTime.now();
    for (int day = 13; day >= 0; day--) {
      final date = now.subtract(Duration(days: day));

      // Paracetamol - 3 times a day
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[0],
          takenTime: DateTime(date.year, date.month, date.day, 8, 0),
          doseAmount: 2.0,
          doseUnit: 'tablets',
        ),
        userId: userId,
      );
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[0],
          takenTime: DateTime(date.year, date.month, date.day, 14, 0),
          doseAmount: 2.0,
          doseUnit: 'tablets',
        ),
        userId: userId,
      );
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[0],
          takenTime: DateTime(date.year, date.month, date.day, 20, 0),
          doseAmount: 2.0,
          doseUnit: 'tablets',
        ),
        userId: userId,
      );

      // Cough Syrup - 2 times a day
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[1],
          takenTime: DateTime(date.year, date.month, date.day, 10, 0),
          doseAmount: 5.0,
          doseUnit: 'ml',
        ),
        userId: userId,
      );
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[1],
          takenTime: DateTime(date.year, date.month, date.day, 18, 0),
          doseAmount: 5.0,
          doseUnit: 'ml',
        ),
        userId: userId,
      );

      // Antihistamine - 2 times a day
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[2],
          takenTime: DateTime(date.year, date.month, date.day, 12, 0),
          doseAmount: 1.0,
          doseUnit: 'tablet',
        ),
        userId: userId,
      );
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[2],
          takenTime: DateTime(date.year, date.month, date.day, 22, 0),
          doseAmount: 1.0,
          doseUnit: 'tablet',
        ),
        userId: userId,
      );

      // Vitamin C - 1 time a day
      await DatabaseHelper.instance.insertMedicineHistory(
        MedicineHistory(
          medicineId: medicineIds[3],
          takenTime: DateTime(date.year, date.month, date.day, 9, 0),
          doseAmount: 1.0,
          doseUnit: 'tablet',
        ),
        userId: userId,
      );
    }

    print('✅ Test data seeded successfully!');
    print('   - 4 medicines added');
    print('   - 84 history entries created (14 days × 6 doses per day)');
  } catch (e) {
    print('❌ Error seeding test data: $e');
  }
}
