/// Parses raw OCR text from a medication prescription into [ParsedMedicine] objects.
///
/// Handles:
///  - Clean prescriptions where each line is separate
///  - ML Kit OCR merging multiple visual lines into one text line
///    (the most common real-world failure — fixed by _preprocess())
///  - Post-parse correction via parseFragment() for any remaining bleed

class ParsedMedicine {
  final String name;
  final String frequency;
  final List<String> defaultTimes;
  final double doseAmount;
  final String doseUnit;
  final double totalQuantity;
  final String note;

  const ParsedMedicine({
    required this.name,
    required this.frequency,
    required this.defaultTimes,
    required this.doseAmount,
    required this.doseUnit,
    required this.totalQuantity,
    this.note = '',
  });

  ParsedMedicine copyWith({
    String? name,
    String? frequency,
    List<String>? defaultTimes,
    double? doseAmount,
    String? doseUnit,
    double? totalQuantity,
    String? note,
  }) {
    return ParsedMedicine(
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      defaultTimes: defaultTimes ?? this.defaultTimes,
      doseAmount: doseAmount ?? this.doseAmount,
      doseUnit: doseUnit ?? this.doseUnit,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      note: note ?? this.note,
    );
  }
}

class PrescriptionParser {
  // ── Frequency map (sorted longest-first at runtime) ───────────────────────
  static const _freqMap = {
    'three times a day': 'Three Times a Day',
    'morning, afternoon, night': 'Three Times a Day',
    'morning afternoon night': 'Three Times a Day',
    'morning & afternoon & night': 'Three Times a Day',
    'thrice a day': 'Three Times a Day',
    'thrice daily': 'Three Times a Day',
    'three times daily': 'Three Times a Day',
    '3 times a day': 'Three Times a Day',
    'tid': 'Three Times a Day',
    'tds': 'Three Times a Day',
    'twice a day': 'Twice a Day',
    'twice daily': 'Twice a Day',
    'two times a day': 'Twice a Day',
    '2 times a day': 'Twice a Day',
    'morning & night': 'Twice a Day',
    'morning and night': 'Twice a Day',
    'bid': 'Twice a Day',
    'bd': 'Twice a Day',
    'once a day': 'Once a Day',
    'once daily': 'Once a Day',
    'od': 'Once a Day',
  };

  static const _timesMap = {
    'Once a Day': ['08:00'],
    'Twice a Day': ['08:00', '20:00'],
    'Three Times a Day': ['08:00', '14:00', '20:00'],
  };

  static const _unitNormalMap = {
    'tablets': 'Tablet',   'tablet': 'Tablet',
    'capsules': 'Capsule', 'capsule': 'Capsule',
    'drops': 'Drops',      'drop': 'Drops',
    'puffs': 'Puff',       'puff': 'Puff',
    'ml': 'ml',
    'mg': 'mg',
    'g': 'g',
    'bottle': 'Bottle',    'bottles': 'Bottle',
    'sachet': 'Sachet',    'sachets': 'Sachet',
  };

  static const _noiseWords = [
    'review date',
    'general advice',
    'patient name',
    'signature',
    'stamp',
    'reg. no',
    'reg no',
    'mbbs',
    'mds',
    'bds',
    'diagnosis',
    'sex:',
    'age:',
    'date:',
    'rx ',
    'dept',
  ];

  // ── Public: parse full prescription text ──────────────────────────────────
  static List<ParsedMedicine> parse(String rawText) {
    final preprocessed = _preprocess(rawText);
    final lines = preprocessed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return _groupIntoBlocks(lines)
        .map(_parseBlock)
        .whereType<ParsedMedicine>()
        .toList();
  }

  // ── Public: parse a short fragment (used by post-parse correction) ─────────
  /// Parses a short text fragment (not a full prescription) and returns
  /// a ParsedMedicine with only frequency, times, and totalQuantity filled.
  /// Returns null if nothing useful can be extracted.
  static ParsedMedicine? parseFragment(String fragment) {
    if (fragment.isEmpty) return null;
    final lower = fragment.toLowerCase();

    // Frequency
    String frequency = '';
    final sortedKeys = _freqMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      if (lower.contains(key)) {
        frequency = _freqMap[key]!;
        break;
      }
    }
    if (frequency.isEmpty) return null;

    // Quantity from fragment
    double totalQuantity = 0;
    final qtyMatch = RegExp(
      r'quantity[:\s]+(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(fragment);
    if (qtyMatch != null) {
      totalQuantity = double.tryParse(qtyMatch.group(1)!) ?? 0;
    }

    return ParsedMedicine(
      name: '',
      frequency: frequency,
      defaultTimes: _timesMap[frequency] ?? ['08:00'],
      doseAmount: 1,
      doseUnit: 'Tablet',
      totalQuantity: totalQuantity,
    );
  }

  // ── Pre-processing: fix OCR line-merge ────────────────────────────────────
  //
  // ML Kit OCR often collapses several visual rows into one text line:
  //   "1 Tablet — Three Times a Day Qty: 15|Avoid alcohol 5. Vitamin C 500 mg 1 Tablet..."
  //
  // Step 1 – Split on embedded medicine numbers mid-line
  //          "...alcohol 5. Vitamin..." → new line at "5."
  // Step 2 – Split a medicine header from appended dose data on same line
  //          "5. Vitamin C 500 mg 1 Tablet — Once a Day..."
  //          → "5. Vitamin C 500 mg" + "1 Tablet — Once a Day..."
  static String _preprocess(String rawText) {
    // Step 1
    final step1 = <String>[];
    for (final line in rawText.split('\n')) {
      step1.addAll(line.split(RegExp(r'(?<=\s)(?=\d+[\.\)]\s+[A-Z])')));
    }

    // Step 2
    final result = <String>[];
    final doseDataPattern = RegExp(
      r'\s+(\d+(?:\.\d+)?\s+(?:tablet[s]?|capsule[s]?|drop[s]?|puff[s]?|ml)\b)',
      caseSensitive: false,
    );
    final prefixPattern = RegExp(r'^(\d+[\.\)]\s+)');

    for (final rawLine in step1) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final prefixMatch = prefixPattern.firstMatch(line);
      if (prefixMatch != null) {
        final rest = line.substring(prefixMatch.end);
        final dataMatch = doseDataPattern.firstMatch(rest);
        if (dataMatch != null && dataMatch.start > 0) {
          result.add(prefixMatch.group(0)! +
              rest.substring(0, dataMatch.start).trim());
          result.add(rest.substring(dataMatch.start).trim());
          continue;
        }
      }
      result.add(line);
    }

    return result.join('\n');
  }

  // ── Block grouping ────────────────────────────────────────────────────────
  static List<List<String>> _groupIntoBlocks(List<String> lines) {
    final blocks = <List<String>>[];
    List<String>? current;

    for (final line in lines) {
      if (RegExp(r'^\d+[\.\)]\s+\S').hasMatch(line)) {
        if (current != null && current.isNotEmpty) blocks.add(current);
        current = [line];
      } else if (current != null) {
        current.add(line);
      }
    }
    if (current != null && current.isNotEmpty) blocks.add(current);
    return blocks;
  }

  // ── Single block parser ───────────────────────────────────────────────────
  static ParsedMedicine? _parseBlock(List<String> block) {
    if (block.isEmpty) return null;

    final nameLine =
        block[0].replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim();
    if (nameLine.isEmpty) return null;

    double doseAmount = 1;
    String doseUnit = 'Tablet';
    String frequency = 'Once a Day';
    double totalQuantity = 1;
    String note = '';

    final rest = block.skip(1).join(' ');
    final restLower = rest.toLowerCase();

    // Dose: prefer count units (Tablet/Capsule/ml/Drops/Puff) over weight (mg/g)
    final matchA = RegExp(
      r'(\d+(?:\.\d+)?)\s*(tablet[s]?|capsule[s]?|drop[s]?|puff[s]?|ml)',
      caseSensitive: false,
    ).firstMatch(rest);
    final matchB = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mg|g)',
      caseSensitive: false,
    ).firstMatch(rest);

    RegExpMatch? chosen;
    if (matchA != null) {
      chosen = matchA;
    } else if (matchB != null) {
      final val = double.tryParse(matchB.group(1)!) ?? 999;
      if (val <= 10) chosen = matchB;
    }
    final hasDoseCountUnit = matchA != null;

    if (chosen != null) {
      doseAmount = double.tryParse(chosen.group(1)!) ?? 1;
      doseUnit = _unitNormalMap[chosen.group(2)!.toLowerCase()] ?? 'Tablet';
    }

    // Frequency
    final sortedKeys = _freqMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      if (restLower.contains(key)) {
        frequency = _freqMap[key]!;
        break;
      }
    }

    // Quantity — 1 Bottle = 100 ml
    final qtyMatch = RegExp(
      r'quantity[:\s]+(\d+(?:\.\d+)?)\s*'
      r'(tablet[s]?|capsule[s]?|drop[s]?|puff[s]?|ml|mg|g|bottle[s]?|sachet[s]?)?',
      caseSensitive: false,
    ).firstMatch(rest);

    if (qtyMatch != null) {
      final rawQty = double.tryParse(qtyMatch.group(1)!) ?? 1;
      final rawUnit = (qtyMatch.group(2) ?? '').toLowerCase();

      if (rawUnit == 'bottle' || rawUnit == 'bottles') {
        totalQuantity = rawQty * 100;
        if (!hasDoseCountUnit) doseUnit = 'ml';
      } else {
        totalQuantity = rawQty;
        if (rawUnit.isNotEmpty && chosen == null) {
          doseUnit = _unitNormalMap[rawUnit] ?? doseUnit;
        }
      }
    }

    // Note — strip footer noise
    final pipeIndex = rest.indexOf('|');
    if (pipeIndex != -1) {
      String raw = rest.substring(pipeIndex + 1).trim();
      final lowerRaw = raw.toLowerCase();

      for (final noise in _noiseWords) {
        final idx = lowerRaw.indexOf(noise);
        if (idx != -1) {
          raw = raw.substring(0, idx).trim();
          break;
        }
      }

      if (raw.length > 80) raw = raw.substring(0, 80).trim();
      note = raw.replaceAll(RegExp(r'[,;.\s]+$'), '').trim();
    }

    return ParsedMedicine(
      name: nameLine,
      frequency: frequency,
      defaultTimes: _timesMap[frequency] ?? ['08:00'],
      doseAmount: doseAmount,
      doseUnit: doseUnit,
      totalQuantity: totalQuantity,
      note: note,
    );
  }
}
