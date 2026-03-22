import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/medicine.dart';
import '../screens/add_medicine_screen.dart';
import '../screens/scan_prescription_screen.dart';

class MedicinesPage extends StatefulWidget {
  final int? userId;

  const MedicinesPage({super.key, this.userId});

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  List<Medicine> medicines = [];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final data =
        await DatabaseHelper.instance.getAllMedicines(userId: widget.userId);
    setState(() {
      medicines = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: medicines.isEmpty
          ? const Center(
              child: Text(
                'No medicines added yet',
                style: TextStyle(fontSize: 18, color: Color(0xFF415F49)),
              ),
            )
          : ListView.builder(
              // Extra bottom padding so last item is not hidden behind FABs
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: medicines.length,
              itemBuilder: (context, index) {
                final med = medicines[index];
                return ListTile(
                  leading:
                      const Icon(Icons.medication, color: Color(0xFF6B9676)),
                  title: Text(med.name),
                  subtitle: Text(
                      '${med.doseAmount} ${med.doseUnit} • ${med.frequency}'),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddMedicineScreen(
                            medicine: med, userId: widget.userId),
                      ),
                    );
                    if (result != null) _loadMedicines();
                  },
                );
              },
            ),

      // ── Two FABs: manual add + scan prescription ────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Scan prescription button
            FloatingActionButton.extended(
              heroTag: 'scan_fab',
              backgroundColor: const Color(0xFF415F49),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ScanPrescriptionScreen(userId: widget.userId),
                  ),
                );
                if (result == true) _loadMedicines();
              },
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan Prescription'),
            ),

            // Manual add button
            FloatingActionButton(
              heroTag: 'add_fab',
              backgroundColor: const Color(0xFF6B9676),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMedicineScreen(userId: widget.userId),
                  ),
                );
                if (result == true) _loadMedicines();
              },
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
