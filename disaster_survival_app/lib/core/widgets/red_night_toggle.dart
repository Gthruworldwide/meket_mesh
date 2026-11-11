import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_settings.dart';

/// زر تبديل الوضع الأحمر التكتيكي (Red-Night Mode).
class RedNightToggle extends ConsumerWidget {
  const RedNightToggle({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redNight = ref.watch(redNightProvider);
    final scheme = Theme.of(context).colorScheme;

    final button = IconButton(
      tooltip: redNight
          ? 'إيقاف الوضع الأحمر (رؤية ليلية)'
          : 'تفعيل الوضع الأحمر (حفظ تكيّف العين)',
      onPressed: ref.read(redNightProvider.notifier).toggle,
      icon: Icon(
        redNight ? Icons.visibility : Icons.nightlight_round,
        color: redNight ? scheme.primary : scheme.onSurface,
      ),
    );

    if (!showLabel) return button;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          Text(
            redNight ? 'وضع أحمر' : 'وضع ليلي',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: redNight ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
