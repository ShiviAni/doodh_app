import 'package:doodh_app/data/models/customer.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/data/models/payment.dart';

Customer customer({
  String id = 'c1',
  String name = 'Ram Kumar',
  String houseNo = '12',
  double defaultQty = 2.0,
  int routeOrder = 1,
  bool active = true,
  String? phone,
}) => Customer(
  id: id,
  name: name,
  houseNo: houseNo,
  defaultQtyLitres: defaultQty,
  routeOrder: routeOrder,
  active: active,
  phone: phone,
);

Delivery delivery({
  String customerId = 'c1',
  String dayKey = '2026-08-18',
  double qty = 2.0,
  DeliveryStatus status = DeliveryStatus.delivered,
  String recordedBy = 'boy@doodh.local',
}) => Delivery(
  id: '${dayKey}_$customerId',
  dayKey: dayKey,
  customerId: customerId,
  qtyLitres: qty,
  status: status,
  recordedBy: recordedBy,
);

Payment payment({
  String id = 'p1',
  String customerId = 'c1',
  double amount = 1000,
  String dayKey = '2026-08-10',
  bool approved = true,
}) => Payment(
  id: id,
  customerId: customerId,
  amount: amount,
  method: PaymentMethod.cash,
  dayKey: dayKey,
  recordedBy: 'owner@doodh.local',
  approved: approved,
);
