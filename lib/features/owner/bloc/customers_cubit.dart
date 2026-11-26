import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customer_repository.dart';

part 'customers_state.dart';

/// Every house, active or not, and the owner's edits to them.
class CustomersCubit extends Cubit<CustomersState> {
  CustomersCubit({required this._customers}) : super(const CustomersState()) {
    _sub = _customers.watchAll().listen(
      (list) => emit(CustomersState(loaded: true, customers: list)),
      onError: addError,
    );
  }

  final CustomerRepository _customers;
  late final StreamSubscription<List<Customer>> _sub;

  /// Adds a new house when [draft] has no id, otherwise updates it.
  ///
  /// Not awaited, like every write in the app: offline, the future would not
  /// complete until signal returns, and the editor would sit open until then.
  void save(Customer draft) {
    if (draft.name.trim().isEmpty) return;
    fireAndForget(
      draft.id.isEmpty ? _customers.add(draft) : _customers.upsert(draft),
    );
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
