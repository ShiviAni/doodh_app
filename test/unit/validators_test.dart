import 'package:doodh_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPlausibleEmail', () {
    for (final ok in ['a@b.co', ' Boy@Doodh.Local ', 'x.y+z@mail.example']) {
      test(
        'accepts "$ok"',
        () => expect(Validators.isPlausibleEmail(ok), isTrue),
      );
    }
    for (final bad in ['', 'abc', 'a@b', '@b.co', 'a b@c.d', 'a@@b.co']) {
      test(
        'rejects "$bad"',
        () => expect(Validators.isPlausibleEmail(bad), isFalse),
      );
    }
  });

  group('parsePositive', () {
    test('parses a trimmed positive number', () {
      expect(Validators.parsePositive(' 62.5 '), 62.5);
    });
    for (final bad in ['', 'x', '0', '-1', 'NaN', 'Infinity']) {
      test(
        'rejects "$bad"',
        () => expect(Validators.parsePositive(bad), isNull),
      );
    }
  });
}
