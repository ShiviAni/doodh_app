import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/delivery_repository.dart';

/// How many of today's entries are still waiting to reach the server.
class SyncCubit extends Cubit<int> {
  SyncCubit({required DeliveryRepository deliveries, required String dayKey})
    : super(0) {
    _sub = deliveries.watchPendingCount(dayKey).listen(emit, onError: addError);
  }

  late final StreamSubscription<int> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
