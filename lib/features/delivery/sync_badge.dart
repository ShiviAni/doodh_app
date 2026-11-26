import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/delivery_repository.dart';
import 'bloc/sync_cubit.dart';

/// Shows whether anything is still waiting to reach the server.
///
/// Phrased as reassurance rather than as an error: losing signal mid-round is
/// normal and nothing is at risk, so a red failure state here would train the
/// delivery person to stop and worry when he should keep walking.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return BlocProvider(
      create: (_) =>
          SyncCubit(deliveries: sl<DeliveryRepository>(), dayKey: dayKey),
      child: BlocBuilder<SyncCubit, int>(
        builder: (context, pending) {
          final synced = pending == 0;
          final color = synced ? AppTheme.confirm : AppTheme.pending;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.gap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                  color: color,
                  size: 26,
                ),
                const SizedBox(width: 6),
                Text(
                  synced ? s.allSynced : s.pendingSync(pending),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
