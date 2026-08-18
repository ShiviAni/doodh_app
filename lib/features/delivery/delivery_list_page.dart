import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';

/// The delivery person's home screen: every house, in route order, tappable.
///
/// Replaced a forced one-house-at-a-time sequence. In practice he does not
/// walk the route in a fixed order — he drops the milk, then reaches for the
/// phone — so being able to tap the house he just served matters more than
/// being marched through a queue.
class DeliveryListPage extends StatelessWidget {
  const DeliveryListPage({
    super.key,
    required this.customers,
    required this.recorded,
    required this.onTapCustomer,
    this.query = '',
  });

  final List<Customer> customers;
  final Map<String, Delivery> recorded;
  final ValueChanged<Customer> onTapCustomer;
  final String query;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    final visible = query.trim().isEmpty
        ? customers
        : customers.where((c) {
            final q = query.toLowerCase().trim();
            return c.name.toLowerCase().contains(q) ||
                (c.nameHi?.contains(q) ?? false) ||
                c.houseNo.toLowerCase().contains(q);
          }).toList();

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gapLarge),
          child: Text(
            hindi ? 'कोई घर नहीं मिला' : 'No house found',
            style: const TextStyle(fontSize: Sizes.bodyText),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _HouseRow(
        customer: visible[i],
        delivery: recorded[visible[i].id],
        hindi: hindi,
        onTap: () => onTapCustomer(visible[i]),
      ),
    );
  }
}

/// One house in the list.
///
/// Sized and coloured so status is readable at a glance without reading any
/// word: a green tick, a red cross, or a hollow circle for not-yet-done.
class _HouseRow extends StatelessWidget {
  const _HouseRow({
    required this.customer,
    required this.delivery,
    required this.hindi,
    required this.onTap,
  });

  final Customer customer;
  final Delivery? delivery;
  final bool hindi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final d = delivery;

    final (IconData icon, Color colour, String trailing) = switch (d) {
      null => (
        Icons.radio_button_unchecked,
        scheme.outline,
        '${s.usualQty} ${Fmt.litres(customer.defaultQtyLitres)}',
      ),
      final x when x.isDelivered => (
        Icons.check_circle,
        AppTheme.confirm,
        '${Fmt.litres(x.qtyLitres)} ${s.litre}',
      ),
      _ => (Icons.cancel, AppTheme.decline, s.notTaken),
    };

    final done = d != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        // Tinted once recorded, so the eye finds the remaining houses first.
        color: done ? colour.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Sizes.gap,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(icon, color: colour, size: 34),
            const SizedBox(width: Sizes.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName(hindi: hindi),
                    style: const TextStyle(
                      fontSize: Sizes.bodyText + 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (customer.houseNo.isNotEmpty)
                    Text(
                      '${s.houseNo} ${customer.houseNo}',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              trailing,
              style: TextStyle(
                fontSize: Sizes.bodyText,
                fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                color: done ? colour : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
