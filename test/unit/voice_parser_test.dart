import 'package:doodh_app/data/models/customer.dart';
import 'package:doodh_app/features/delivery/voice/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = VoiceParser();

  final customers = <Customer>[
    const Customer(
      id: 'c1',
      name: 'Ram Kumar',
      nameHi: 'राम कुमार',
      houseNo: '12',
      defaultQtyLitres: 2,
      routeOrder: 1,
    ),
    const Customer(
      id: 'c2',
      name: 'Shyam Lal',
      nameHi: 'श्याम लाल',
      houseNo: '14',
      defaultQtyLitres: 1.5,
      routeOrder: 2,
    ),
    const Customer(
      id: 'c3',
      name: 'Sita Devi',
      nameHi: 'सीता देवी',
      houseNo: '15',
      defaultQtyLitres: 1,
      routeOrder: 3,
    ),
    const Customer(
      id: 'c4',
      name: 'Geeta Sharma',
      nameHi: 'गीता शर्मा',
      houseNo: '18',
      defaultQtyLitres: 2.5,
      routeOrder: 4,
    ),
  ];

  group('Hindi quantity words', () {
    // The irregular ones matter most: डेढ़ and ढाई contain no digit and no
    // word for one or two, so a general number parser cannot reach them, and
    // they are exactly what people say when buying milk.
    test('डेढ़ is one and a half', () {
      expect(parser.parseQuantity('डेढ़ लीटर'), 1.5);
      expect(parser.parseQuantity('डेढ लीटर'), 1.5);
    });

    test('ढाई is two and a half', () {
      expect(parser.parseQuantity('ढाई लीटर'), 2.5);
    });

    test('आधा is half', () {
      expect(parser.parseQuantity('आधा लीटर'), 0.5);
    });

    test('साढ़े X is X and a half', () {
      expect(parser.parseQuantity('साढ़े तीन लीटर'), 3.5);
      expect(parser.parseQuantity('साढ़े चार लीटर'), 4.5);
    });

    test('साढ़े तीन is not misread as तीन', () {
      // The bug this guards: scanning shortest-first would match तीन inside
      // साढ़े तीन and silently under-record by half a litre every time.
      expect(parser.parseQuantity('साढ़े तीन लीटर'), isNot(3.0));
      expect(parser.parseQuantity('साढ़े तीन लीटर'), 3.5);
    });

    test('plain whole numbers', () {
      expect(parser.parseQuantity('एक लीटर'), 1);
      expect(parser.parseQuantity('दो लीटर'), 2);
      expect(parser.parseQuantity('तीन लीटर'), 3);
      expect(parser.parseQuantity('पाँच लीटर'), 5);
    });

    test('accepts common speech-engine spelling variants', () {
      // Recognisers are inconsistent about nuqta and matra on these words.
      expect(parser.parseQuantity('देढ़ लीटर'), 1.5);
      expect(parser.parseQuantity('सादे तीन लीटर'), 3.5);
      expect(parser.parseQuantity('छै लीटर'), 6);
    });
  });

  group('digits and English', () {
    test('reads digits directly', () {
      expect(parser.parseQuantity('2 लीटर'), 2);
      expect(parser.parseQuantity('2.5 litre'), 2.5);
    });

    test('a half spoken after a digit is added', () {
      expect(parser.parseQuantity('2 आधा लीटर'), 2.5);
      expect(parser.parseQuantity('two and half'), 2.5);
    });

    test('does not add half to a value that already has one', () {
      expect(parser.parseQuantity('2.5 litre'), 2.5);
    });

    test('English words', () {
      expect(parser.parseQuantity('two litres'), 2);
      expect(parser.parseQuantity('half litre'), 0.5);
    });

    test('rejects an implausible quantity', () {
      // A misheard house number must not become 500 litres of milk.
      expect(parser.parseQuantity('500 लीटर'), isNull);
    });
  });

  group('skip phrases', () {
    test('recognises "not taken" in Hindi', () {
      final entry = parser.parse('सीता देवी नहीं लिया', customers);
      expect(entry.skipped, isTrue);
      expect(entry.qtyLitres, 0);
      expect(entry.customer?.id, 'c3');
    });

    test('a skip beats any quantity also heard', () {
      // "दो" here is incidental; the instruction was that nothing was taken.
      final entry = parser.parse('राम कुमार दो नहीं लिया', customers);
      expect(entry.skipped, isTrue);
      expect(entry.qtyLitres, 0);
    });

    test('English skip', () {
      expect(parser.parseQuantity('not taken'), 0);
    });
  });

  group('name matching', () {
    test('matches a full Hindi name with quantity', () {
      final entry = parser.parse('राम कुमार दो लीटर', customers);
      expect(entry.customer?.id, 'c1');
      expect(entry.qtyLitres, 2);
      expect(entry.isUsable, isTrue);
    });

    test('matches on the first name alone', () {
      // Recognisers very often return only the first name.
      final entry = parser.parse('श्याम डेढ़ लीटर', customers);
      expect(entry.customer?.id, 'c2');
      expect(entry.qtyLitres, 1.5);
    });

    test('matches the English spelling too', () {
      final entry = parser.parse('geeta sharma 3 litre', customers);
      expect(entry.customer?.id, 'c4');
      expect(entry.qtyLitres, 3);
    });

    test('ignores filler words around the name', () {
      final entry = parser.parse('गीता को ढाई लीटर दिया', customers);
      expect(entry.customer?.id, 'c4');
      expect(entry.qtyLitres, 2.5);
    });

    test('returns no customer when nothing resembles a name', () {
      // Better to ask than to guess: a wrong house is a wrong bill.
      final entry = parser.parse('दो लीटर', customers);
      expect(entry.customer, isNull);
      expect(entry.isUsable, isFalse);
      expect(entry.qtyLitres, 2);
    });

    test('does not match an unrelated name', () {
      final entry = parser.parse('मोहन सिंह दो लीटर', customers);
      expect(entry.customer, isNull);
    });

    test('reports confidence so a shaky match can be confirmed', () {
      final exact = parser.parse('राम कुमार दो लीटर', customers);
      final partial = parser.parse('राम दो लीटर', customers);

      expect(exact.nameConfidence, greaterThan(partial.nameConfidence));
      expect(partial.customer?.id, 'c1');
    });
  });

  group('robustness', () {
    test('empty or noise input yields nothing usable, without throwing', () {
      for (final input in ['', '   ', '...', 'हम्म']) {
        final entry = parser.parse(input, customers);
        expect(entry.isUsable, isFalse);
      }
    });

    test('handles an empty customer list', () {
      final entry = parser.parse('राम कुमार दो लीटर', const []);
      expect(entry.customer, isNull);
      expect(entry.qtyLitres, 2);
    });

    test('a word merely containing a number word does not match', () {
      // "अनेक" ends in "एक"; whole-word matching must reject it.
      expect(parser.parseQuantity('अनेक'), isNull);
    });

    test('punctuation from the recogniser is ignored', () {
      final entry = parser.parse('राम कुमार, दो लीटर.', customers);
      expect(entry.customer?.id, 'c1');
      expect(entry.qtyLitres, 2);
    });
  });
}
