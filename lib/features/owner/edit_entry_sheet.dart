import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/delivery_repository.dart';
import '../auth/auth_service.dart';
import '../delivery/quantity_stepper.dart';

/// Owner override for any day's entry.
///
/// A reason is required and stored alongside `editedBy`/`editedAt`. The point
/// is not bureaucracy — it is that a month's bill can be reconstructed later
/// and any correction explained, rather than a number silently changing.
class EditEntrySheet extends StatefulWidget {
  const EditEntrySheet({
    super.key,
    required this.customer,
    required this.dayKey,
    required this.existing,
  });

  final Customer customer;
  final String dayKey;
  final Delivery? existing;

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required String dayKey,
    required Delivery? existing,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        EditEntrySheet(customer: customer, dayKey: dayKey, existing: existing),
  );

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  late double _qty = widget.existing?.isDelivered ?? false
      ? widget.existing!.qtyLitres
      : widget.customer.defaultQtyLitres;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _save(DeliveryStatus status) {
    final email = sl<AuthService>().currentEmail ?? '';
    // Only flag it as an edit when something was already there; the owner
    // filling a blank house is an original entry, not a correction.
    final isCorrection = widget.existing != null;

    sl<DeliveryRepository>().record(
      dayKey: widget.dayKey,
      customerId: widget.customer.id,
      qtyLitres: _qty,
      status: status,
      recordedBy: widget.existing?.recordedBy ?? email,
      editedBy: isCorrection ? email : null,
      editReason: isCorrection
          ? (_reason.text.trim().isEmpty ? '—' : _reason.text.trim())
          : null,
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
            widget.customer.displayName(hindi: hindi),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: Sizes.bodyText + 4,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            Fmt.dayLabel(DateKeys.parseDay(widget.dayKey)),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Sizes.gapLarge),

          QuantityStepper(
            value: _qty,
            onChanged: (v) => setState(() => _qty = v),
          ),

          if (widget.existing != null) ...[
            const SizedBox(height: Sizes.gap),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: s.editReason,
                prefixIcon: const Icon(Icons.edit_note),
              ),
            ),
          ],

          const SizedBox(height: Sizes.gapLarge),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.confirm,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle),
            label: Text('${s.delivered}  ${Fmt.litres(_qty)} ${s.litre}'),
            onPressed: () => _save(DeliveryStatus.delivered),
          ),
          const SizedBox(height: Sizes.gap),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.decline,
              side: const BorderSide(color: AppTheme.decline, width: 2),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(s.notTaken),
            onPressed: () => _save(DeliveryStatus.skipped),
          ),
        ],
      ),
    );
  }
}
