import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/medicine_history.dart';
import '../services/database_helper.dart';
import '../utils/time_formatter.dart';

class SchedulesPage extends StatefulWidget {
  final int? userId;

  const SchedulesPage({super.key, this.userId});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage>
    with WidgetsBindingObserver {
  List<_ScheduleItem> _scheduleList = [];
  Map<String, bool> _takenMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSchedules();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🔥 This makes checkbox update when returning from notification
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSchedules();
    }
  }

  Future<void> _loadSchedules() async {
    try {
      if (widget.userId == null) {
        print('❌ Error: userId is null');
        return;
      }

      final medicines = await DatabaseHelper.instance.getAllMedicines(userId: widget.userId);
      final todayHistory =
          await DatabaseHelper.instance.getTodayMedicineHistory(userId: widget.userId);

      print('📋 Loading schedules: ${medicines.length} medicines, ${todayHistory.length} history entries');
      todayHistory.forEach((h) {
        print('  📝 History: medicineId=${h.medicineId}, time=${h.takenTime.hour}:${h.takenTime.minute.toString().padLeft(2, '0')}');
      });

      List<_ScheduleItem> tempList = [];
      Map<String, bool> tempTakenMap = {};

      for (var med in medicines) {
        for (var timeString in med.times) {
          final scheduleTime = _parseTimeToday(timeString);

          bool alreadyTaken = todayHistory.any((history) {
            final matches = history.medicineId == med.id &&
                history.takenTime.hour == scheduleTime.hour &&
                history.takenTime.minute == scheduleTime.minute;
            if (matches) {
              print('  ✅ Found match: med=${med.id}, time=${scheduleTime.hour}:${scheduleTime.minute.toString().padLeft(2, '0')}');
            }
            return matches;
          });

          final key = "${med.id}_$timeString";
          tempTakenMap[key] = alreadyTaken;
          print('  Key: $key -> isTaken=$alreadyTaken');

          tempList.add(
            _ScheduleItem(
              medicine: med,
              time: scheduleTime,
              timeString: timeString,
            ),
          );
        }
      }

      tempList.sort((a, b) => a.time.compareTo(b.time));

      if (mounted) {
        setState(() {
          _scheduleList = tempList;
          _takenMap = tempTakenMap;
        });
        print('🎨 UI updated with ${tempList.length} items');
      }
    } catch (e) {
      print('❌ Error loading schedules: $e');
    }
  }

  DateTime _parseTimeToday(String timeString) {
    final parts = timeString.split(":");
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Future<void> _toggleTaken(_ScheduleItem item) async {
    final key = "${item.medicine.id}_${item.timeString}";
    final isTaken = _takenMap[key] ?? false;

    print('🔄 Toggle: key=$key, isTaken=$isTaken');

    try {
      if (!isTaken) {
        // MARK AS TAKEN: add history and decrease quantity
        print('✅ Marking as taken');
        
        final history = MedicineHistory(
          medicineId: item.medicine.id!,
          takenTime: item.time,  // Use scheduled time, not current time!
          doseAmount: item.medicine.doseAmount,
          doseUnit: item.medicine.doseUnit,
        );

        await DatabaseHelper.instance.insertMedicineHistory(history, userId: widget.userId);
        print('✅ History added at ${item.time.hour}:${item.time.minute.toString().padLeft(2, '0')}');

        // Use the medicine directly from item
        final updatedMedicine = Medicine(
          id: item.medicine.id,
          name: item.medicine.name,
          frequency: item.medicine.frequency,
          times: item.medicine.times,
          doseAmount: item.medicine.doseAmount,
          doseUnit: item.medicine.doseUnit,
          totalQuantity: item.medicine.totalQuantity - item.medicine.doseAmount,
          alarmTone: item.medicine.alarmTone,
        );

        await DatabaseHelper.instance.updateMedicine(updatedMedicine);
        print('✅ Quantity decreased: ${item.medicine.totalQuantity} -> ${updatedMedicine.totalQuantity}');
      } else {
        // MARK AS NOT TAKEN: remove today's history for this time and increase quantity
        print('❌ Marking as not taken');
        
        final allHistory = await DatabaseHelper.instance.getAllMedicineHistory(userId: widget.userId);
        final todayHistory = allHistory.where((h) {
          final isToday = h.takenTime.year == DateTime.now().year &&
                          h.takenTime.month == DateTime.now().month &&
                          h.takenTime.day == DateTime.now().day;
          final isThisTime = h.takenTime.hour == item.time.hour &&
                             h.takenTime.minute == item.time.minute;
          final isThisMedicine = h.medicineId == item.medicine.id;
          return isToday && isThisTime && isThisMedicine;
        }).toList();

        print('❌ Found ${todayHistory.length} matching history entries');

        // Delete only the most recent one
        if (todayHistory.isNotEmpty) {
          final mostRecent = todayHistory.last;
          print('❌ Deleting history id: ${mostRecent.id}');
          await DatabaseHelper.instance.deleteMedicineHistory(mostRecent.id ?? 0);
        }

        // Use the medicine directly from item
        final updatedMedicine = Medicine(
          id: item.medicine.id,
          name: item.medicine.name,
          frequency: item.medicine.frequency,
          times: item.medicine.times,
          doseAmount: item.medicine.doseAmount,
          doseUnit: item.medicine.doseUnit,
          totalQuantity: item.medicine.totalQuantity + item.medicine.doseAmount,
          alarmTone: item.medicine.alarmTone,
        );

        await DatabaseHelper.instance.updateMedicine(updatedMedicine);
        print('❌ Quantity increased: ${item.medicine.totalQuantity} -> ${updatedMedicine.totalQuantity}');
      }

      print('🔄 Reloading schedules...');
      await _loadSchedules();
      print('✅ Toggle complete');
    } catch (e) {
      print('❌ Error toggling medicine: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Medicines"),
      ),
      body: _scheduleList.isEmpty
          ? const Center(
              child: Text("No medicines scheduled for today"),
            )
          : ListView.builder(
              itemCount: _scheduleList.length,
              itemBuilder: (context, index) {
                final item = _scheduleList[index];
                final key = "${item.medicine.id}_${item.timeString}";
                final isTaken = _takenMap[key] ?? false;

                final scheme = Theme.of(context).colorScheme;
                final cardColor = isTaken
                    ? scheme.primary.withOpacity(0.1)
                    : scheme.error.withOpacity(0.1);
                final textColor = isTaken ? scheme.primary : scheme.error;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: cardColor,
                  child: ListTile(
                    leading: Checkbox(
                      value: isTaken,
                      onChanged: (_) => _toggleTaken(item),
                    ),
                    title: Text(
                      item.medicine.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                        "${item.medicine.doseAmount} ${item.medicine.doseUnit} • ${formatTime12Hour(item.timeString)}"),
                    trailing: Text(
                        "Left: ${item.medicine.totalQuantity.toStringAsFixed(1)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ScheduleItem {
  final Medicine medicine;
  final DateTime time;
  final String timeString;

  _ScheduleItem({
    required this.medicine,
    required this.time,
    required this.timeString,
  });
}