import 'package:doodh_app/core/utils/formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateKeys', () {
    test('day keys sort lexicographically in chronological order', () {
      // Firestore range queries over dayKey depend on this being true.
      final keys = [
        DateKeys.day(DateTime(2026, 8, 9)),
        DateKeys.day(DateTime(2026, 8, 10)),
        DateKeys.day(DateTime(2026, 12, 1)),
        DateKeys.day(DateTime(2027, 1, 1)),
      ];
      final sorted = [...keys]..sort();

      expect(keys, sorted);
      expect(keys.first, '2026-08-09');
    });

    test('delivery id is deterministic for the same house and day', () {
      // Two syncs of the same entry must land on one document.
      final a = DateKeys.deliveryId('2026-08-18', 'cust042');
      final b = DateKeys.deliveryId('2026-08-18', 'cust042');

      expect(a, b);
      expect(a, '2026-08-18_cust042');
    });

    test('week starts on Monday', () {
      // Tuesday 18 Aug 2026 belongs to the week beginning Monday the 17th.
      expect(
        DateKeys.startOfWeek(DateTime(2026, 8, 18)),
        DateTime(2026, 8, 17),
      );
      // A Monday is its own week start.
      expect(
        DateKeys.startOfWeek(DateTime(2026, 8, 17)),
        DateTime(2026, 8, 17),
      );
      // A Sunday belongs to the week that began six days earlier.
      expect(
        DateKeys.startOfWeek(DateTime(2026, 8, 23)),
        DateTime(2026, 8, 17),
      );
    });

    test('endOfMonth handles 30, 31 and February', () {
      expect(DateKeys.endOfMonth(DateTime(2026, 8, 5)), DateTime(2026, 8, 31));
      expect(DateKeys.endOfMonth(DateTime(2026, 4, 5)), DateTime(2026, 4, 30));
      expect(DateKeys.endOfMonth(DateTime(2026, 2, 5)), DateTime(2026, 2, 28));
      // 2028 is a leap year.
      expect(DateKeys.endOfMonth(DateTime(2028, 2, 5)), DateTime(2028, 2, 29));
    });
  });

  group('Fmt.litres', () {
    test('drops a trailing .0 but keeps a genuine half', () {
      expect(Fmt.litres(2.0), '2');
      expect(Fmt.litres(2.5), '2.5');
      expect(Fmt.litres(0.5), '0.5');
      expect(Fmt.litres(10.0), '10');
    });
  });

  group('Fmt.money', () {
    test('uses Indian digit grouping', () {
      // Rs 1,50,000 rather than Rs 150,000.
      expect(Fmt.money(150000), '₹1,50,000');
      expect(Fmt.money(3600), '₹3,600');
    });
  });
}
