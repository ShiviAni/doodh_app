import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/bill.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../auth/auth_service.dart';
import 'stat_tile.dart';

/// Who owes what, and what has been collected.
///
/// Everything here is owner-only at the rules level. The delivery role has no
/// read access to payments or the rate, so none of these figures are reachable
/// from his install even with a modified build.
class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key, required this.session});

  final Session session;

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  DateTime _month = DateTime.now();

  String get _monthKey => DateKeys.month(_month);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return StreamBuilder<double>(
      stream: sl<SettingsRepository>().watchRate(),
      builder: (context, rateSnap) {
        final rate = rateSnap.data ?? SettingsRepository.defaultRate;

        return StreamBuilder<List<Customer>>(
          stream: sl<CustomerRepository>().watchAll(),
          builder: (context, custSnap) {
            final customers = custSnap.data ?? const <Customer>[];

            return StreamBuilder<List<Payment>>(
              stream: sl<PaymentRepository>().watchAll(),
              builder: (context, paySnap) {
                final payments = paySnap.data ?? const <Payment>[];
                final pending = payments.where((p) => !p.approved).toList();

                return StreamBuilder<List<Delivery>>(
                  stream: sl<DeliveryRepository>().watchRange(
                    '$_monthKey-01',
                    DateKeys.day(DateKeys.endOfMonth(_month)),
                  ),
                  builder: (context, delSnap) {
                    final deliveries = delSnap.data ?? const <Delivery>[];
                    final calc = const ReportCalculator();

                    final bills = <String, Bill>{
                      for (final c in customers)
                        c.id: calc.billFor(
                          customer: c,
                          monthKey: _monthKey,
                          monthDeliveries: deliveries,
                          allPayments: payments,
                          ratePerLitre: rate,
                        ),
                    };

                    final billed = bills.values.fold<double>(
                      0,
                      (sum, b) => sum + b.amount,
                    );
                    final collected = bills.values.fold<double>(
                      0,
                      (sum, b) => sum + b.paidAmount,
                    );

                    return ListView(
                      padding: const EdgeInsets.all(Sizes.gap),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month - 1,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Fmt.monthLabel(_month),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: Sizes.bodyText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month + 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Sizes.gap),

                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: StatTile(
                                  label: hindi ? 'कुल बिल' : 'Billed',
                                  value: Fmt.money(billed),
                                  icon: Icons.receipt_long_outlined,
                                ),
                              ),
                              const SizedBox(width: Sizes.gap),
                              Expanded(
                                child: StatTile(
                                  label: hindi ? 'जमा हुआ' : 'Collected',
                                  value: Fmt.money(collected),
                                  icon: Icons.savings_outlined,
                                  color: AppTheme.confirm,
                                ),
                              ),
                              const SizedBox(width: Sizes.gap),
                              Expanded(
                                child: StatTile(
                                  label: s.balance,
                                  value: Fmt.money(billed - collected),
                                  icon: Icons.pending_actions_outlined,
                                  color: AppTheme.decline,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (pending.isNotEmpty) ...[
                          const SizedBox(height: Sizes.gapLarge),
                          _ApprovalSection(
                            pending: pending,
                            customers: customers,
                            hindi: hindi,
                            approverEmail: widget.session.email,
                          ),
                        ],

                        const SizedBox(height: Sizes.gapLarge),
                        const Divider(),

                        for (final c in customers.where((c) => c.active))
                          _BillRow(
                            customer: c,
                            bill: bills[c.id]!,
                            perDay: calc.litresByDay(
                              deliveries
                                  .where((d) => d.customerId == c.id)
                                  .toList(),
                            ),
                            hindi: hindi,
                            approverEmail: widget.session.email,
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Cash the delivery person logged at the door, waiting on the owner.
///
/// Nothing here affects a balance until it is approved — an unverified
/// doorstep claim must never be able to clear a real due on its own.
class _ApprovalSection extends StatelessWidget {
  const _ApprovalSection({
    required this.pending,
    required this.customers,
    required this.hindi,
    required this.approverEmail,
  });

  final List<Payment> pending;
  final List<Customer> customers;
  final bool hindi;
  final String approverEmail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.all(Sizes.gap),
      decoration: BoxDecoration(
        color: AppTheme.pending.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Sizes.radius),
        border: Border.all(color: AppTheme.pending),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions, color: AppTheme.pending),
              const SizedBox(width: 8),
              Text(
                '${s.pendingApprovals} (${pending.length})',
                style: const TextStyle(
                  fontSize: Sizes.bodyText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final p in pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                customers
                        .where((c) => c.id == p.customerId)
                        .map((c) => c.displayName(hindi: hindi))
                        .firstOrNull ??
                    p.customerId,
              ),
              subtitle: Text('${Fmt.money(p.amount)}  ·  ${p.dayKey}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: s.approve,
                    icon: const Icon(
                      Icons.check_circle,
                      color: AppTheme.confirm,
                      size: 32,
                    ),
                    onPressed: () =>
                        sl<PaymentRepository>().approve(p.id, approverEmail),
                  ),
                  IconButton(
                    tooltip: s.reject,
                    icon: const Icon(
                      Icons.cancel,
                      color: AppTheme.decline,
                      size: 32,
                    ),
                    onPressed: () => sl<PaymentRepository>().reject(p.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.customer,
    required this.bill,
    required this.perDay,
    required this.hindi,
    required this.approverEmail,
  });

  final Customer customer;
  final Bill bill;
  final Map<String, double> perDay;
  final bool hindi;
  final String approverEmail;

  Color get _statusColor => switch (bill.status) {
    BillStatus.paid => AppTheme.confirm,
    BillStatus.partial => AppTheme.pending,
    BillStatus.unpaid => AppTheme.decline,
  };

  String _statusLabel(S s) => switch (bill.status) {
    BillStatus.paid => s.paid,
    BillStatus.partial => s.partial,
    BillStatus.unpaid => s.unpaid,
  };

  Future<void> _sendWhatsapp(BuildContext context) async {
    final phone = customer.phone;
    if (phone == null || phone.isEmpty) return;

    final message = const ReportCalculator().billMessage(
      customer: customer,
      bill: bill,
      perDay: perDay,
      hindi: hindi,
    );
    // Normalise to the digits wa.me expects, defaulting to +91 when the number
    // was stored without a country code.
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final e164 = digits.length == 10 ? '91$digits' : digits;
    final uri = Uri.parse(
      'https://wa.me/$e164?text=${Uri.encodeComponent(message)}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hindi ? 'व्हाट्सएप नहीं खुला' : 'Could not open WhatsApp',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return ExpansionTile(
      title: Text(
        customer.displayName(hindi: hindi),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${Fmt.litres(bill.litres)} ${s.litre}  ·  '
        '${Fmt.money(bill.amount)}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _statusLabel(s),
          style: TextStyle(
            color: _statusColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Sizes.gap,
            0,
            Sizes.gap,
            Sizes.gap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kv(s.totalAmount, Fmt.money(bill.amount)),
              _kv(s.paid, Fmt.money(bill.paidAmount)),
              _kv(s.balance, Fmt.money(bill.balance)),
              const SizedBox(height: Sizes.gap),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_card),
                      label: Text(s.recordPayment),
                      onPressed: () => _RecordPaymentSheet.show(
                        context,
                        customer: customer,
                        suggested: bill.balance,
                        approverEmail: approverEmail,
                      ),
                    ),
                  ),
                  if (customer.phone?.isNotEmpty ?? false) ...[
                    const SizedBox(width: Sizes.gap),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: Text(s.sendBillWhatsapp),
                        onPressed: () => _sendWhatsapp(context),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

/// Owner-recorded payment. Lands approved immediately — the owner is the
/// authority the approval queue exists to defer to.
class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.customer,
    required this.suggested,
    required this.approverEmail,
  });

  final Customer customer;
  final double suggested;
  final String approverEmail;

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required double suggested,
    required String approverEmail,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RecordPaymentSheet(
      customer: customer,
      suggested: suggested,
      approverEmail: approverEmail,
    ),
  );

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late final _amount = TextEditingController(
    text: widget.suggested > 0 ? widget.suggested.toStringAsFixed(0) : '',
  );
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) return;
    sl<PaymentRepository>().create(
      Payment(
        id: '',
        customerId: widget.customer.id,
        amount: value,
        method: _method,
        dayKey: DateKeys.day(DateTime.now()),
        recordedBy: widget.approverEmail,
        approved: true,
        approvedBy: widget.approverEmail,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return Padding(
      padding: EdgeInsets.only(
        left: Sizes.gapLarge,
        right: Sizes.gapLarge,
        top: Sizes.gapLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sizes.gapLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${s.recordPayment} — ${widget.customer.displayName(hindi: hindi)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: Sizes.bodyText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sizes.gapLarge),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.currency_rupee),
              labelText: 'Amount',
            ),
          ),
          const SizedBox(height: Sizes.gap),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
              ButtonSegment(value: PaymentMethod.upi, label: Text('UPI')),
              ButtonSegment(value: PaymentMethod.other, label: Text('Other')),
            ],
            selected: {_method},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => setState(() => _method = sel.first),
          ),
          const SizedBox(height: Sizes.gapLarge),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(s.save),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
