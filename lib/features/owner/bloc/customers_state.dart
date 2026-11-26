part of 'customers_cubit.dart';

final class CustomersState extends Equatable {
  const CustomersState({this.loaded = false, this.customers = const []});

  final bool loaded;
  final List<Customer> customers;

  @override
  List<Object?> get props => [loaded, customers];
}
