import '../models/activity.dart';
import 'dairy_refs.dart';

class ActivityRepository {
  ActivityRepository(this._refs);

  final DairyRefs _refs;

  /// Newest first. Owner-only by rule; nothing writes to this collection from
  /// the app, so there is no create/update/delete here on purpose.
  Stream<List<Activity>> watchRecent({int limit = 200}) => _refs.activity
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(Activity.fromDoc).toList());

  /// Everything that touched one house, for answering "what happened here?".
  Stream<List<Activity>> watchForCustomer(
    String customerId, {
    int limit = 100,
  }) => _refs.activity
      .where('customerId', isEqualTo: customerId)
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(Activity.fromDoc).toList());
}
