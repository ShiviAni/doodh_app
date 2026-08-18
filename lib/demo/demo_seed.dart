import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../core/utils/formats.dart';

/// Realistic sample data for the demo entrypoint.
///
/// Shaped like a real dairy rather than like test fixtures: a partly-finished
/// round, a couple of houses that skipped today, one corrected entry, an
/// unapproved cash collection, and three weeks of history behind it so the
/// reports have something to show.
class DemoSeed {
  static const dairyId = 'main';

  static const ownerEmail = 'owner@doodhhisab.com';
  static const deliveryEmail = 'delivery@doodhhisab.com';

  static const ratePerLitre = 60.0;

  /// Name, Hindi name, house no, usual litres, phone.
  static const _houses = <(String, String, String, double, String)>[
    ('Ram Kumar', 'राम कुमार', '12', 2.0, '9876543210'),
    ('Shyam Lal', 'श्याम लाल', '14', 1.5, '9876543211'),
    ('Sita Devi', 'सीता देवी', '15', 1.0, '9876543212'),
    ('Geeta Sharma', 'गीता शर्मा', '18', 2.5, '9876543213'),
    ('Mohan Singh', 'मोहन सिंह', '21', 3.0, '9876543214'),
    ('Raju Yadav', 'राजू यादव', '23', 2.0, '9876543215'),
    ('Kamla Bai', 'कमला बाई', '26', 1.5, '9876543216'),
    ('Suresh Gupta', 'सुरेश गुप्ता', '29', 2.0, '9876543217'),
    ('Anita Verma', 'अनीता वर्मा', '31', 1.0, '9876543218'),
    ('Vijay Chauhan', 'विजय चौहान', '34', 2.5, '9876543219'),
    ('Pooja Rani', 'पूजा रानी', '37', 2.0, '9876543220'),
    ('Dinesh Patel', 'दिनेश पटेल', '40', 1.5, '9876543221'),
  ];

  static int get houseCount => _houses.length;

  static Future<FakeFirebaseFirestore> build() async {
    final db = FakeFirebaseFirestore();
    final dairy = db.collection('dairies').doc(dairyId);

    await dairy.set({'name': 'Doodh Hisab'});

    await dairy.collection('members').doc(ownerEmail).set({
      'role': 'owner',
      'displayName': 'Shivani',
      'active': true,
    });
    await dairy.collection('members').doc(deliveryEmail).set({
      'role': 'delivery',
      'displayName': 'Ramesh',
      'active': true,
    });

    await dairy.collection('settings').doc('billing').set({
      'ratePerLitre': ratePerLitre,
    });

    for (var i = 0; i < _houses.length; i++) {
      final (name, nameHi, houseNo, qty, phone) = _houses[i];
      await dairy.collection('customers').doc('c${i + 1}').set({
        'name': name,
        'nameHi': nameHi,
        'houseNo': houseNo,
        'phone': phone,
        'defaultQtyLitres': qty,
        'routeOrder': i + 1,
        'active': true,
      });
    }

    final today = DateTime.now();

    // Three weeks of completed history, so week/month reports are populated.
    for (var back = 21; back >= 1; back--) {
      final day = today.subtract(Duration(days: back));
      final dayKey = DateKeys.day(day);
      for (var i = 0; i < _houses.length; i++) {
        final (_, _, _, qty, _) = _houses[i];
        // A house skips roughly every couple of weeks — enough that the
        // skipped counter and the "not taken" styling are visible.
        final skipped = (back + i) % 17 == 0;
        await _writeDelivery(
          dairy,
          dayKey: dayKey,
          customerId: 'c${i + 1}',
          qty: skipped ? 0 : qty,
          status: skipped ? 'skipped' : 'delivered',
          at: DateTime(day.year, day.month, day.day, 6, 30 + i),
        );
      }
    }

    // Today: a round in progress — 8 of 12 done, so the progress bar, the
    // pending count and the missing-house warning all have something to say.
    final todayKey = DateKeys.day(today);
    for (var i = 0; i < 8; i++) {
      final (_, _, _, qty, _) = _houses[i];
      final skipped = i == 2;
      // House 4 took extra today — the everyday case of a usual amount not
      // matching what was actually handed over.
      final actual = i == 3 ? qty + 1.0 : qty;
      await _writeDelivery(
        dairy,
        dayKey: todayKey,
        customerId: 'c${i + 1}',
        qty: skipped ? 0 : actual,
        status: skipped ? 'skipped' : 'delivered',
        at: DateTime(today.year, today.month, today.day, 6, 30 + i * 3),
      );
    }

    await _seedPayments(dairy, today);
    await _seedActivity(dairy, today, todayKey);

    return db;
  }

  static Future<void> _writeDelivery(
    DocumentReference<Map<String, dynamic>> dairy, {
    required String dayKey,
    required String customerId,
    required double qty,
    required String status,
    required DateTime at,
  }) => dairy
      .collection('deliveries')
      .doc(DateKeys.deliveryId(dayKey, customerId))
      .set({
        'dayKey': dayKey,
        'customerId': customerId,
        'qtyLitres': qty,
        'status': status,
        'recordedBy': deliveryEmail,
        'recordedAt': Timestamp.fromDate(at),
        'deviceRecordedAt': Timestamp.fromDate(at),
      });

  static Future<void> _seedPayments(
    DocumentReference<Map<String, dynamic>> dairy,
    DateTime today,
  ) async {
    final payments = dairy.collection('payments');

    // Settled last month.
    for (final id in ['c1', 'c2', 'c5', 'c8']) {
      await payments.add({
        'customerId': id,
        'amount': 3000.0,
        'method': 'cash',
        'dayKey': DateKeys.day(today.subtract(const Duration(days: 20))),
        'recordedBy': ownerEmail,
        'approved': true,
        'approvedBy': ownerEmail,
        'recordedAt': Timestamp.fromDate(
          today.subtract(const Duration(days: 20)),
        ),
      });
    }

    // Part payment — shows the "partly paid" state.
    await payments.add({
      'customerId': 'c4',
      'amount': 1500.0,
      'method': 'upi',
      'dayKey': DateKeys.day(today.subtract(const Duration(days: 8))),
      'recordedBy': ownerEmail,
      'approved': true,
      'approvedBy': ownerEmail,
      'recordedAt': Timestamp.fromDate(today.subtract(const Duration(days: 8))),
    });

    // Collected at the door this morning, still waiting on the owner. This is
    // what puts the approval queue on screen.
    await payments.add({
      'customerId': 'c6',
      'amount': 2000.0,
      'method': 'cash',
      'dayKey': DateKeys.day(today),
      'recordedBy': deliveryEmail,
      'approved': false,
      'recordedAt': Timestamp.fromDate(
        DateTime(today.year, today.month, today.day, 6, 52),
      ),
    });
  }

  /// The change history a Cloud Function would have written in production.
  static Future<void> _seedActivity(
    DocumentReference<Map<String, dynamic>> dairy,
    DateTime today,
    String todayKey,
  ) async {
    final activity = dairy.collection('activity');

    for (var i = 0; i < 8; i++) {
      final (name, _, _, qty, _) = _houses[i];
      final skipped = i == 2;
      await activity.add({
        'type': 'delivery_recorded',
        'actorEmail': deliveryEmail,
        'customerId': 'c${i + 1}',
        'customerName': name,
        'dayKey': todayKey,
        'afterLitres': skipped ? 0 : (i == 3 ? qty + 1.0 : qty),
        'afterStatus': skipped ? 'skipped' : 'delivered',
        'at': Timestamp.fromDate(
          DateTime(today.year, today.month, today.day, 6, 30 + i * 3),
        ),
      });
    }

    // The entry the owner most wants to be told about.
    await activity.add({
      'type': 'delivery_edited',
      'actorEmail': ownerEmail,
      'customerId': 'c4',
      'customerName': 'Geeta Sharma',
      'dayKey': todayKey,
      'beforeLitres': 2.5,
      'afterLitres': 3.5,
      'beforeStatus': 'delivered',
      'afterStatus': 'delivered',
      'reason': 'guests at home',
      'at': Timestamp.fromDate(
        DateTime(today.year, today.month, today.day, 9, 15),
      ),
    });

    await activity.add({
      'type': 'payment_logged',
      'actorEmail': deliveryEmail,
      'customerId': 'c6',
      'customerName': 'Raju Yadav',
      'dayKey': todayKey,
      'amount': 2000.0,
      'at': Timestamp.fromDate(
        DateTime(today.year, today.month, today.day, 6, 52),
      ),
    });
  }
}
