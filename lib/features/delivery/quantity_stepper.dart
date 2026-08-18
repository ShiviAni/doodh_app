import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';

/// Half-litre stepper with oversized targets.
///
/// Half a litre is the real-world granularity — customers ask for 1.5 or 2.5,
/// never 1.7 — so stepping rather than typing removes the keyboard entirely.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 0.5,
    this.min = 0.5,
    this.max = 10,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(
          icon: Icons.remove,
          semanticLabel: 'kam',
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Container(
              height: Sizes.tapTarget + 16,
              margin: const EdgeInsets.symmetric(horizontal: Sizes.gap),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Sizes.radius),
              ),
              // A three-character value like "2.5" plus the unit does not fit
              // at full size on a narrow phone once both step buttons have
              // taken their share. Scaling down beats an overflow stripe, and
              // the number stays by far the largest thing on screen.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Fmt.litres(value),
                        style: const TextStyle(
                          fontSize: Sizes.hugeNumber,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.litre,
                        style: const TextStyle(
                          fontSize: Sizes.bodyText + 4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          semanticLabel: 'zyada',
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Sizes.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(Sizes.radius),
          onTap: onPressed,
          child: SizedBox(
            width: Sizes.tapTarget,
            height: Sizes.tapTarget + 16,
            child: Icon(
              icon,
              size: 40,
              color: onPressed == null
                  ? scheme.onSecondaryContainer.withValues(alpha: 0.3)
                  : scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
