import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import 'quantity_stepper.dart';

/// One house, full screen.
///
/// Everything here is built for a user who is not fully literate: the photo
/// identifies the house before the name does, the quantity is pre-filled so a
/// normal day is a single tap, and every colour is paired with an icon and a
/// word so the meaning never rests on colour alone.
class DeliveryCard extends StatefulWidget {
  const DeliveryCard({
    super.key,
    required this.customer,
    required this.existing,
    required this.onRecord,
  });

  final Customer customer;
  final Delivery? existing;
  final void Function(double qtyLitres, DeliveryStatus status) onRecord;

  @override
  State<DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<DeliveryCard> {
  late double _qty = _initialQty();

  double _initialQty() {
    final prior = widget.existing;
    // Re-opening an already-recorded house shows what was actually recorded,
    // so a correction starts from the real value rather than the default.
    if (prior != null && prior.isDelivered) return prior.qtyLitres;
    return widget.customer.defaultQtyLitres;
  }

  @override
  void didUpdateWidget(DeliveryCard old) {
    super.didUpdateWidget(old);
    // The card is reused as the round advances; reset for the new house.
    if (old.customer.id != widget.customer.id ||
        old.existing?.qtyLitres != widget.existing?.qtyLitres) {
      _qty = _initialQty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final c = widget.customer;
    final prior = widget.existing;

    // The photo is the first thing to give up space. Both action buttons must
    // stay above the fold on a small phone — "not taken" is used every day, and
    // a button that needs a scroll to reach is a button that gets skipped.
    return LayoutBuilder(
      builder: (context, constraints) {
        final photoSize = (constraints.maxHeight * 0.24)
            .clamp(96.0, 180.0)
            .toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Sizes.gapLarge,
            Sizes.gap,
            Sizes.gapLarge,
            Sizes.gapLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HousePhoto(
                photoUrl: c.photoUrl,
                name: c.displayName(hindi: hindi),
                size: photoSize,
              ),
              const SizedBox(height: Sizes.gap),

              Text(
                c.displayName(hindi: hindi),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: Sizes.titleText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (c.houseNo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${s.houseNo} ${c.houseNo}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Sizes.bodyText,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

              const SizedBox(height: 4),
              Text(
                '${s.usualQty}: ${Fmt.litres(c.defaultQtyLitres)} ${s.litre}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Sizes.bodyText - 2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              if (prior != null) ...[
                const SizedBox(height: Sizes.gap),
                _AlreadyRecordedBanner(delivery: prior),
              ],

              const SizedBox(height: Sizes.gapLarge),
              QuantityStepper(
                value: _qty,
                onChanged: (v) => setState(() => _qty = v),
              ),

              const SizedBox(height: Sizes.gapLarge),
              SizedBox(
                height: Sizes.primaryButton,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.confirm,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle, size: 40),
                  label: Text(
                    '${s.delivered}  ${Fmt.litres(_qty)} ${s.litre}',
                    style: const TextStyle(
                      fontSize: Sizes.bodyText + 6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () =>
                      widget.onRecord(_qty, DeliveryStatus.delivered),
                ),
              ),

              const SizedBox(height: Sizes.gap),
              SizedBox(
                height: Sizes.tapTarget,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.decline,
                    side: const BorderSide(color: AppTheme.decline, width: 2),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 30),
                  label: Text(s.notTaken),
                  onPressed: () => widget.onRecord(0, DeliveryStatus.skipped),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Falls back to a large initial when no photo has been uploaded, so the layout
/// never collapses and there is still something non-textual to recognise.
class _HousePhoto extends StatelessWidget {
  const _HousePhoto({
    required this.photoUrl,
    required this.name,
    required this.size,
  });

  final String? photoUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Sizes.radius),
        child: SizedBox(
          width: size,
          height: size,
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _Initial(name: name, scheme: scheme, size: size),
                )
              : _Initial(name: name, scheme: scheme, size: size),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({
    required this.name,
    required this.scheme,
    required this.size,
  });

  final String name;
  final ColorScheme scheme;
  final double size;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: scheme.primaryContainer,
    child: Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: scheme.onPrimaryContainer,
        ),
      ),
    ),
  );
}

/// Shown when he revisits a house he already marked, so he can see what is
/// recorded before changing it.
class _AlreadyRecordedBanner extends StatelessWidget {
  const _AlreadyRecordedBanner({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final delivered = delivery.isDelivered;
    final color = delivered ? AppTheme.confirm : AppTheme.decline;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.gap,
        vertical: Sizes.gap - 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Sizes.radius),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            delivered ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              delivered
                  ? '${s.delivered}: ${Fmt.litres(delivery.qtyLitres)} ${s.litre}'
                  : s.notTaken,
              style: TextStyle(
                fontSize: Sizes.bodyText,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
