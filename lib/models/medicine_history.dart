class MedicineHistory {
  final int? id;
  final int medicineId;
  final DateTime takenTime;
  final double doseAmount;
  final String doseUnit;

  MedicineHistory({
    this.id,
    required this.medicineId,
    required this.takenTime,
    required this.doseAmount,
    required this.doseUnit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'takenTime': takenTime.toIso8601String(),
      'doseAmount': doseAmount,
      'doseUnit': doseUnit,
    };
  }

  factory MedicineHistory.fromMap(Map<String, dynamic> map) {
    return MedicineHistory(
      id: map['id'],
      medicineId: map['medicineId'],
      takenTime: DateTime.parse(map['takenTime']),
      doseAmount: map['doseAmount'],
      doseUnit: map['doseUnit'],
    );
  }
}