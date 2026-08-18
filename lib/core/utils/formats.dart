import 'package:intl/intl.dart';

/// Firestore document keys and range queries are built from these strings, so
/// the formats are part of the data contract — do not change them casually.
class DateKeys {
  DateKeys._();

  static final DateFormat _day = DateFormat('yyyy-MM-dd');
  static final DateFormat _month = DateFormat('yyyy-MM');

  /// `2026-08-18` — sorts lexicographically, which is what makes Firestore
  /// range queries over a plain string field work.
  static String day(DateTime d) => _day.format(d);

  /// `2026-08` for monthly rollups and bills.
  static String month(DateTime d) => _month.format(d);

  static DateTime parseDay(String key) => _day.parseStrict(key);

  /// Deterministic delivery document ID.
  ///
  /// This is the mechanism that makes the offline queue safe: if the same
  /// entry syncs twice, it overwrites one document instead of creating two.
  static String deliveryId(String dayKey, String customerId) =>
      '${dayKey}_$customerId';

  static String billId(String monthKey, String customerId) =>
      '${monthKey}_$customerId';

  /// Midnight local time — the anchor for "today".
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday-start week, matching Indian dairy convention.
  static DateTime startOfWeek(DateTime d) {
    final s = startOfDay(d);
    return s.subtract(Duration(days: s.weekday - DateTime.monday));
  }

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  static DateTime endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1).subtract(const Duration(days: 1));

  static DateTime startOfYear(DateTime d) => DateTime(d.year);
}

class Fmt {
  Fmt._();

  static final NumberFormat _rupee = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final NumberFormat _rupeePaise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Indian grouping (₹1,50,000 not ₹150,000). Whole rupees unless there are
  /// paise to show — dairy amounts are almost always round.
  static String money(num amount) => amount == amount.roundToDouble()
      ? _rupee.format(amount)
      : _rupeePaise.format(amount);

  /// `2` / `2.5` — never `2.0`, which reads as clutter on the delivery card.
  static String litres(double l) {
    final s = l.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String dayLabel(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String shortDay(DateTime d) => DateFormat('d MMM').format(d);
  static String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);
}
