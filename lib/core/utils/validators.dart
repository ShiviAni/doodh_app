/// Input checks shared by forms and the cubits behind them.
///
/// The form uses these to decide whether to close; the cubit uses the same
/// check again so a bad value never reaches Firestore whatever calls it.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// A light shape check, not a deliverability check. Firebase Auth is the
  /// real gate.
  static bool isPlausibleEmail(String input) =>
      _email.hasMatch(input.trim().toLowerCase());

  /// A positive, finite number (a rate or an amount), or null.
  static double? parsePositive(String input) {
    final rate = double.tryParse(input.trim());
    return (rate == null || rate <= 0 || !rate.isFinite) ? null : rate;
  }
}
