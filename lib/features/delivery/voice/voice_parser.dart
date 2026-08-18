import '../../../data/models/customer.dart';

/// What a spoken phrase was understood to mean.
class VoiceEntry {
  const VoiceEntry({
    required this.transcript,
    this.customer,
    this.qtyLitres,
    this.skipped = false,
    this.nameConfidence = 0,
  });

  final String transcript;
  final Customer? customer;

  /// Null when no quantity was heard — the card then keeps the usual amount.
  final double? qtyLitres;

  /// True when he said the house took nothing today.
  final bool skipped;

  /// 0..1. Low values are still returned rather than discarded, so the
  /// confirmation step can show a doubtful match instead of silently dropping
  /// it and leaving him wondering why nothing happened.
  final double nameConfidence;

  bool get hasCustomer => customer != null;
  bool get isUsable => hasCustomer && (qtyLitres != null || skipped);
}

/// Turns a spoken sentence into an entry.
///
/// Built for how the delivery person actually speaks: "राम कुमार ढाई लीटर",
/// "शयाम को दो", "सीता नहीं लिया". Hindi milk quantities are mostly irregular
/// words rather than digits — डेढ़ is 1.5 and ढाई is 2.5, neither of which
/// contains the word for one or two — so a plain number parser is useless here.
class VoiceParser {
  const VoiceParser();

  /// Standalone quantity words. Order matters when scanning: longer phrases
  /// are matched before their own prefixes.
  static const _quantityWords = <String, double>{
    // Irregular Hindi fractions — the common ones in daily use.
    'सवा तीन': 3.25,
    'साढ़े नौ': 9.5,
    'साढ़े आठ': 8.5,
    'साढ़े सात': 7.5,
    'साढ़े छह': 6.5,
    'साढ़े पांच': 5.5,
    'साढ़े पाँच': 5.5,
    'साढ़े चार': 4.5,
    'साढ़े तीन': 3.5,
    'सादे तीन': 3.5,
    'सादे चार': 4.5,
    'डेढ़': 1.5,
    'डेढ': 1.5,
    'देढ़': 1.5,
    'ढाई': 2.5,
    'ढाइ': 2.5,
    'अढ़ाई': 2.5,
    'आधा': 0.5,
    'आधी': 0.5,
    'अाधा': 0.5,

    // Whole numbers.
    'एक': 1,
    'दो': 2,
    'तीन': 3,
    'चार': 4,
    'पांच': 5,
    'पाँच': 5,
    'छह': 6,
    'छै': 6,
    'छे': 6,
    'सात': 7,
    'आठ': 8,
    'नौ': 9,
    'दस': 10,

    // English, including the way half is usually said.
    'two and half': 2.5,
    'one and half': 1.5,
    'three and half': 3.5,
    'half': 0.5,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
  };

  /// Phrases meaning the house took nothing today.
  static const _skipWords = [
    'नहीं लिया',
    'नही लिया',
    'नहीं चाहिए',
    'नहीं दिया',
    'बंद',
    'छुट्टी',
    'मना',
    'not taken',
    'skip',
    'nothing',
    'no milk',
  ];

  /// Words to strip before matching a name, so "श्याम को दो लीटर" still finds
  /// श्याम. Deliberately excludes anything that could be part of a name.
  static const _fillerWords = [
    'लीटर',
    'लिटर',
    'ली',
    'litre',
    'liter',
    'litres',
    'को',
    'जी',
    'का',
    'के',
    'दिया',
    'दे',
    'दिए',
    'घर',
    'नंबर',
    'house',
    'number',
    'gave',
    'give',
  ];

  VoiceEntry parse(String transcript, List<Customer> customers) {
    final text = _normalise(transcript);

    final skipped = _skipWords.any((w) => text.contains(_normalise(w)));
    final qty = skipped ? 0.0 : _findQuantity(text);
    final (customer, confidence) = _findCustomer(text, customers);

    return VoiceEntry(
      transcript: transcript,
      customer: customer,
      qtyLitres: skipped ? 0 : qty,
      skipped: skipped,
      nameConfidence: confidence,
    );
  }

  /// Quantity only — used on a card where the house is already known.
  double? parseQuantity(String transcript) {
    final text = _normalise(transcript);
    if (_skipWords.any((w) => text.contains(_normalise(w)))) return 0;
    return _findQuantity(text);
  }

  String _normalise(String input) {
    // A full stop is punctuation everywhere except between digits, where it is
    // the decimal point of "2.5". Stripping it blindly turned two and a half
    // litres into "2 5" and then into 2 — half a litre lost on every spoken
    // decimal. Protect it, strip the rest, then restore it.
    const decimalMarker = '~dot~';
    return input
        .toLowerCase()
        .replaceAllMapped(
          RegExp(r'(\d)\.(\d)'),
          (m) => '${m[1]}$decimalMarker${m[2]}',
        )
        .replaceAll(RegExp(r'[.,!?|]'), ' ')
        .replaceAll(decimalMarker, '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double? _findQuantity(String text) {
    // Digits win when present: "2.5 लीटर" is unambiguous, and a speech engine
    // that produced a digit was already confident.
    final digits = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (digits != null) {
      final value = double.tryParse(digits.group(1)!);
      if (value != null && value > 0 && value <= 50) {
        // "2 आधा" / "2 and half" — a half spoken after the digit.
        final hasHalf =
            text.contains('आधा') ||
            text.contains('आधी') ||
            text.contains('half');
        return hasHalf && value == value.roundToDouble() ? value + 0.5 : value;
      }
    }

    // Longest phrase first, so "साढ़े तीन" is not read as "तीन".
    final keys = _quantityWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (_containsWord(text, _normalise(key))) return _quantityWords[key];
    }
    return null;
  }

  /// Whole-phrase match, so "एक" does not fire inside "अनेक".
  bool _containsWord(String haystack, String needle) {
    final pattern = RegExp(
      '(^|\\s)${RegExp.escape(needle)}(\$|\\s)',
      unicode: true,
    );
    return pattern.hasMatch(haystack);
  }

  (Customer?, double) _findCustomer(String text, List<Customer> customers) {
    if (customers.isEmpty) return (null, 0);

    // Strip filler so the remaining words are mostly the name.
    var cleaned = text;
    for (final filler in _fillerWords) {
      cleaned = cleaned.replaceAll(
        RegExp(
          '(^|\\s)${RegExp.escape(_normalise(filler))}(\$|\\s)',
          unicode: true,
        ),
        ' ',
      );
    }
    cleaned = _normalise(cleaned);

    Customer? best;
    var bestScore = 0.0;

    for (final c in customers) {
      final score = [
        _score(cleaned, _normalise(c.name)),
        if (c.nameHi != null) _score(cleaned, _normalise(c.nameHi!)),
      ].reduce((a, b) => a > b ? a : b);

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    // Below this the "match" is usually one incidental shared syllable.
    return bestScore >= 0.34 ? (best, bestScore) : (null, bestScore);
  }

  /// Fraction of the customer's name tokens that appear in what was said.
  ///
  /// Token-based rather than whole-string: speech engines routinely return a
  /// first name only, or mangle a surname, and matching "राम" against
  /// "राम कुमार" has to succeed.
  double _score(String spoken, String name) {
    if (name.isEmpty || spoken.isEmpty) return 0;
    if (spoken.contains(name)) return 1;

    final nameTokens = name.split(' ').where((t) => t.length > 1).toList();
    if (nameTokens.isEmpty) return 0;

    final spokenTokens = spoken.split(' ').where((t) => t.length > 1).toList();
    if (spokenTokens.isEmpty) return 0;

    var hits = 0;
    for (final token in nameTokens) {
      final matched = spokenTokens.any(
        (s) =>
            s == token ||
            (token.length >= 3 && s.contains(token)) ||
            (s.length >= 3 && token.contains(s)),
      );
      if (matched) hits++;
    }
    return hits / nameTokens.length;
  }
}
