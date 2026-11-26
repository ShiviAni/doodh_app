import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../core/utils/validators.dart';
import '../../data/models/bill.dart';
import '../../data/models/customer.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../auth/auth_service.dart';
import 'bloc/money_cubit.dart';
import 'stat_tile.dart';

/// Who owes what, and what has been collected. See [MoneyCubit].
class MoneyPage extends StatelessWidget {
  const MoneyPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MoneyCubit(
      settings: sl<SettingsRepository>(),
      customers: sl<CustomerRepository>(),
      payments: sl<PaymentRepository>(),
      deliveries: sl<DeliveryRepository>(),
      ownerEmail: session.email,
    ),
    child: const _MoneyView(),
  );
}

class _MoneyView extends StatelessWidget {
  const _MoneyView();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final cubit = context.read<MoneyCubit>();

    return BlocBuilder<MoneyCubit, MoneyState>(
      builder: (context, state) {
        final pending = state.pending;
        final bills = state.bills;

        return ListView(
          padding: const EdgeInsets.all(Sizes.gap),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => cubit.shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    Fmt.monthLabel(state.month),
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
                  onPressed: () => cubit.shiftMonth(1),
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
                      value: Fmt.money(state.billed),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: StatTile(
                      label: hindi ? 'जमा हुआ' : 'Collected',
                      value: Fmt.money(state.collected),
                      icon: Icons.savings_outlined,
                      color: AppTheme.confirm,
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: StatTile(
                      label: s.balance,
                      value: Fmt.money(state.balance),
                      icon: Icons.pending_actions_outlined,
                      color: AppTheme.decline,
                    ),
                  ),
                ],
              ),
            ),

            if (pending.isNotEmpty) ...[
              const SizedBox(height: Sizes.gapLarge),
              _ApprovalSection(pending: pending, state: state, hindi: hindi),
            ],

            const SizedBox(height: Sizes.gapLarge),
            const Divider(),

            for (final c in state.activeCustomers)
              _BillRow(
                customer: c,
                bill: bills[c.id]!,
                perDay: state.perDayFor(c.id),
                hindi: hindi,
              ),
          ],
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
    required this.state,
    required this.hindi,
  });

  final List<Payment> pending;
  final MoneyState state;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cubit = context.read<MoneyCubit>();
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
              title: Text(state.customerName(p.customerId, hindi: hindi)),
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
                    onPressed: () => cubit.approve(p.id),
                  ),
                  IconButton(
                    tooltip: s.reject,
                    icon: const Icon(
                      Icons.cancel,
                      color: AppTheme.decline,
                      size: 32,
                    ),
                    onPressed: () => cubit.reject(p.id),
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
  });

  final Customer customer;
  final Bill bill;
  final Map<String, double> perDay;
  final bool hindi;

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
  const _RecordPaymentSheet({required this.customer, required this.suggested});

  final Customer customer;
  final double suggested;

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required double suggested,
  }) {
    // A new route, outside the page's provider: hand the cubit across.
    final cubit = context.read<MoneyCubit>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _RecordPaymentSheet(customer: customer, suggested: suggested),
      ),
    );
  }

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
    if (Validators.parsePositive(_amount.text) == null) return;
    context.read<MoneyCubit>().recordPayment(
      customerId: widget.customer.id,
      amount: _amount.text,
      method: _method,
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
