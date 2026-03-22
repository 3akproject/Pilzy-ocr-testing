import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/medicine_history.dart';
import '../models/medicine.dart';
import '../utils/time_formatter.dart';

class HistoryPage extends StatefulWidget {
  final int? userId;

  const HistoryPage({super.key, this.userId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<MedicineHistory> _historyList = [];
  List<MedicineHistory> _filteredList = [];
  List<Medicine> _medicines = [];

  String _selectedMedicine = "All";
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final history = await DatabaseHelper.instance.getAllMedicineHistory(userId: widget.userId);
    final meds = await DatabaseHelper.instance.getAllMedicines(userId: widget.userId);

    setState(() {
      _historyList = history;
      _filteredList = history;
      _medicines = meds;
    });
    
    _applyFilters();
  }

  void _applyFilters() {
    List<MedicineHistory> temp = List.from(_historyList);

    // Filter by medicine
    if (_selectedMedicine != "All") {
      final med = _medicines.firstWhere(
        (m) => m.name == _selectedMedicine,
      );
      temp = temp.where((h) => h.medicineId == med.id).toList();
    }

    // Filter by date range
    if (_fromDate != null) {
      temp = temp.where((h) {
        final historyDate = DateTime(h.takenTime.year, h.takenTime.month, h.takenTime.day);
        final fromDateOnly = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        return historyDate.isAtSameMomentAs(fromDateOnly) || historyDate.isAfter(fromDateOnly);
      }).toList();
    }

    if (_toDate != null) {
      temp = temp.where((h) {
        final historyDate = DateTime(h.takenTime.year, h.takenTime.month, h.takenTime.day);
        final toDateOnly = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
        return historyDate.isAtSameMomentAs(toDateOnly) || historyDate.isBefore(toDateOnly);
      }).toList();
    }

    temp.sort((a, b) => b.takenTime.compareTo(a.takenTime));

    setState(() {
      _filteredList = temp;
    });
  }

  String _getMedicineName(int id) {
    try {
      return _medicines.firstWhere((m) => m.id == id).name;
    } catch (_) {
      return "Unknown";
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _applyFilters();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medicine History")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medicine Filter
                DropdownButtonFormField<String>(
                  value: _selectedMedicine,
                  items: [
                    const DropdownMenuItem(
                      value: "All",
                      child: Text("All Medicines"),
                    ),
                    ..._medicines.map((m) => DropdownMenuItem(
                          value: m.name,
                          child: Text(m.name),
                        )),
                  ],
                  onChanged: (value) {
                    _selectedMedicine = value!;
                    _applyFilters();
                  },
                  decoration: const InputDecoration(
                    labelText: "Medicine",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Date Range Pickers
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickFromDate,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('From Date', style: TextStyle(fontSize: 12)),
                            Text(
                              _fromDate == null ? 'Select' : formatDate(_fromDate!),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickToDate,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('To Date', style: TextStyle(fontSize: 12)),
                            Text(
                              _toDate == null ? 'Select' : formatDate(_toDate!),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Clear filters button
                    if (_fromDate != null || _toDate != null)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _fromDate = null;
                            _toDate = null;
                          });
                          _applyFilters();
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _filteredList.isEmpty
                ? const Center(child: Text("No history found"))
                : ListView.builder(
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(_getMedicineName(item.medicineId)),
                        subtitle: Text(
                          "${item.doseAmount} ${item.doseUnit}",
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${item.takenTime.day}/${item.takenTime.month}/${item.takenTime.year}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              formatDateTime12Hour(item.takenTime),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}