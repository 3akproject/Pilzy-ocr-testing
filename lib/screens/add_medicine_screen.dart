import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pilzy/models/medicine.dart';
import 'package:pilzy/services/database_helper.dart';
import 'package:pilzy/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine;
  final int? userId;

  const AddMedicineScreen({super.key, this.medicine, this.userId});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController doseController;
  late TextEditingController quantityController;
  late TextEditingController intervalHourController;
  late TextEditingController intervalMinuteController;

  String frequency = "Once a Day";
  String doseUnit = "Tablet";
  String alarmTone = "Default";

  List<TimeOfDay> times = [];
  TimeOfDay? anchorTime;

  final frequencyOptions = [
    "Once a Day",
    "Twice a Day",
    "Three Times a Day",
    "Specify Time Interval",
  ];

  final unitOptions = [
    "Tablet", "Capsule", "ml", "mg", "g",
    "Spoon", "Drops", "Puff", "Other"
  ];

  bool get isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController();
    doseController = TextEditingController();
    quantityController = TextEditingController();
    intervalHourController = TextEditingController();
    intervalMinuteController = TextEditingController();

    if (widget.medicine != null) {
      final med = widget.medicine!;

      nameController.text = med.name;
      doseController.text = med.doseAmount.toString();
      quantityController.text = med.totalQuantity.toString();
      frequency = med.frequency;
      doseUnit = med.doseUnit;
      alarmTone = med.alarmTone;

      if (frequency == "Specify Time Interval") {
        // Restore anchor time from times[0]
        if (med.times.isNotEmpty) {
          final parts = med.times.first.split(':');
          anchorTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }

        // Restore interval from alarmTone stored as HH:MM
        if (alarmTone.contains(":")) {
          final parts = alarmTone.split(':');
          intervalHourController.text = parts[0];
          intervalMinuteController.text = parts[1];
        }
      } else {
        times = med.times.map((t) {
          final parts = t.split(':');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }).toList();
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    quantityController.dispose();
    intervalHourController.dispose();
    intervalMinuteController.dispose();
    super.dispose();
  }

  int getTimePickersCount() {
    switch (frequency) {
      case "Once a Day":
        return 1;
      case "Twice a Day":
        return 2;
      case "Three Times a Day":
        return 3;
      default:
        return 0;
    }
  }

  Future<void> pickTime(int index) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());

    if (picked != null) {
      setState(() {
        if (times.length > index) {
          times[index] = picked;
        } else {
          times.add(picked);
        }
      });
    }
  }

  Future<void> pickAnchorTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());

    if (picked != null) {
      setState(() {
        anchorTime = picked;
      });
    }
  }

  Future<void> _deleteMedicine() async {
    if (!isEditing) return;

    await DatabaseHelper.instance.deleteMedicine(widget.medicine!.id!);

    for (int i = 0; i < 20; i++) {
      await NotificationService.instance
          .cancelNotification(widget.medicine!.id! * 100 + i);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (frequency != "Specify Time Interval" && times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one time")),
      );
      return;
    }

    if (frequency == "Specify Time Interval" && anchorTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select anchor time")),
      );
      return;
    }

    final med = Medicine(
      id: widget.medicine?.id,
      name: nameController.text.trim(),
      frequency: frequency,
      times: frequency == "Specify Time Interval"
          ? [
              "${anchorTime!.hour.toString().padLeft(2, '0')}:${anchorTime!.minute.toString().padLeft(2, '0')}"
            ]
          : times
              .map((t) =>
                  "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}")
              .toList(),
      doseAmount: double.tryParse(doseController.text) ?? 1,
      doseUnit: doseUnit,
      totalQuantity: double.tryParse(quantityController.text) ?? 1,
      alarmTone: frequency == "Specify Time Interval"
          ? "${intervalHourController.text}:${intervalMinuteController.text}"
          : alarmTone,
    );

    int medicineId;

    if (isEditing) {
      medicineId = widget.medicine!.id!;
      await DatabaseHelper.instance.updateMedicine(med);

      for (int i = 0; i < 20; i++) {
        await NotificationService.instance
            .cancelNotification(medicineId * 100 + i);
      }
    } else {
      medicineId = await DatabaseHelper.instance.insertMedicine(med, userId: widget.userId);
    }

    await _scheduleAlarms(medicineId, med);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _scheduleAlarms(int medicineId, Medicine med) async {
    final now = DateTime.now();

    if (frequency == "Specify Time Interval") {
      int hours = int.tryParse(intervalHourController.text) ?? 0;
      int minutes = int.tryParse(intervalMinuteController.text) ?? 0;
      int intervalMinutes = (hours * 60) + minutes;

      if (intervalMinutes <= 0) return;

      DateTime first = DateTime(
        now.year,
        now.month,
        now.day,
        anchorTime!.hour,
        anchorTime!.minute,
      );

      if (first.isBefore(now)) {
        first = first.add(const Duration(days: 1));
      }

      int timesPerDay = (24 * 60) ~/ intervalMinutes;

      for (int i = 0; i < timesPerDay; i++) {
        DateTime scheduled =
            first.add(Duration(minutes: intervalMinutes * i));

        final tzScheduled =
            tz.TZDateTime.from(scheduled, tz.local);

        await NotificationService.instance.scheduleDailyReminder(
          id: medicineId * 100 + i,
          dateTime: tzScheduled,
          medicineName: med.name,
          doseAmount: med.doseAmount.toString(),
          doseUnit: med.doseUnit,
        );
      }
    } else {
      for (int i = 0; i < times.length; i++) {
        final t = times[i];

        DateTime scheduled = DateTime(
          now.year,
          now.month,
          now.day,
          t.hour,
          t.minute,
        );

        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        final tzScheduled =
            tz.TZDateTime.from(scheduled, tz.local);

        await NotificationService.instance.scheduleDailyReminder(
          id: medicineId * 100 + i,
          dateTime: tzScheduled,
          medicineName: med.name,
          doseAmount: med.doseAmount.toString(),
          doseUnit: med.doseUnit,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Medicine" : "Add Medicine"),
        backgroundColor: const Color(0xFF6B9676),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: "Medicine Name"),
                validator: (val) =>
                    val == null || val.isEmpty
                        ? "Enter medicine name"
                        : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: frequency,
                decoration:
                    const InputDecoration(labelText: "Frequency"),
                items: frequencyOptions
                    .map((f) =>
                        DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    frequency = val!;
                    times = [];
                  });
                },
              ),

              const SizedBox(height: 16),

              if (frequency == "Specify Time Interval") ...[
                ListTile(
                  title: Text(anchorTime == null
                      ? "Select Anchor Time"
                      : DateFormat.jm().format(
                          DateTime(0, 0, 0,
                              anchorTime!.hour,
                              anchorTime!.minute))),
                  trailing: const Icon(Icons.access_time),
                  onTap: pickAnchorTime,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: intervalHourController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Interval Hours"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: intervalMinuteController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Interval Minutes"),
                ),
              ] else ...[
                ...List.generate(getTimePickersCount(), (i) {
                  final time = times.length > i ? times[i] : null;
                  return ListTile(
                    title: Text(
                      time == null
                          ? "Pick Time"
                          : DateFormat.jm().format(
                              DateTime(0, 0, 0,
                                  time.hour, time.minute),
                            ),
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => pickTime(i),
                  );
                }),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: doseController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: "Dose Amount"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: doseUnit,
                      decoration:
                          const InputDecoration(labelText: "Unit"),
                      items: unitOptions
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => doseUnit = val!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Total Quantity"),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveMedicine,
                child: const Text("Save Medicine"),
              ),

              if (isEditing) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: _deleteMedicine,
                  child: const Text("Delete Medicine"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}