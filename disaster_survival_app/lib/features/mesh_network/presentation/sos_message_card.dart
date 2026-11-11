import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dtn_packet_handler.dart';
import '../../../core/widgets/tactical_widgets.dart';

/// بطاقة عرض نداء استغاثة واحد، مشتركة بين لوحة الجاهزية وشاشة المش.
class SosMessageCard extends StatelessWidget {
  const SosMessageCard({super.key, required this.message});

  final SosMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TacticalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sos, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.callsign,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: message.verified ? 'موقّع' : 'غير موثّق',
                color: message.verified ? AppColors.success : AppColors.warning,
                icon: message.verified ? Icons.verified : Icons.gpp_maybe,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.message,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            '${message.timeAgo} · ${message.hops} قفزة · '
            '${message.originNodeId}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          if (message.lat != null && message.lng != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: scheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${message.lat!.toStringAsFixed(4)}, '
                  '${message.lng!.toStringAsFixed(4)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
