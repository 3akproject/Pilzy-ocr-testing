class Medicine {
  int? id;
  String name;
  String frequency;
  List<String> times;
  double doseAmount;
  String doseUnit;
  double totalQuantity;
  String alarmTone;

  Medicine({
    this.id,
    required this.name,
    required this.frequency,
    required this.times,
    required this.doseAmount,
    required this.doseUnit,
    required this.totalQuantity,
    required this.alarmTone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'times': times.join(','), // store as string
      'doseAmount': doseAmount,
      'doseUnit': doseUnit,
      'totalQuantity': totalQuantity,
      'alarmTone': alarmTone,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      times: map['times'].split(','),
      doseAmount: map['doseAmount'],
      doseUnit: map['doseUnit'],
      totalQuantity: map['totalQuantity'],
      alarmTone: map['alarmTone'],
    );
  }
}