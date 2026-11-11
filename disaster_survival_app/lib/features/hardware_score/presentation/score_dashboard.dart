import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/mesh_manager.dart';
import '../../../core/widgets/red_night_toggle.dart';
import '../../../core/widgets/tactical_widgets.dart';
import '../../mesh_network/presentation/mesh_sos_screen.dart';
import '../../mesh_network/presentation/sos_message_card.dart';
import '../../mesh_network/services/sos_feed.dart';
import '../models/device_score_model.dart';
import '../services/hardware_assessor.dart';

/// لوحة جاهزية الجهاز + حالة شبكة المش + تدفق نداءات الاستغاثة.
class ScoreDashboard extends ConsumerWidget {
  const ScoreDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(deviceScoreProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('جاهزية الجهاز والمش'),
        actions: const [RedNightToggle(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(deviceScoreProvider);
          await ref.read(meshManagerProvider).syncNow();
          await ref.read(deviceScoreProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
          children: [
            scoreAsync.when(
              loading: () => const _ScoreLoading(),
              error: (error, _) => TacticalCard(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'تعذّر إكمال فحص العتاد',
                  subtitle: '$error',
                  action: FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(deviceScoreProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة الفحص'),
                  ),
                ),
              ),
              data: (score) => _ScoreHero(score: score),
            ),
            const SizedBox(height: 14),
            const _MeshPanel(),
            const SizedBox(height: 14),
            const _BreakdownPanel(),
            const SizedBox(height: 14),
            const _ChecksPanel(),
            const SizedBox(height: 14),
            const _SosPanel(),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'كل الفحوص تُنفَّذ محلياً على الجهاز — لا اتصال بأي سيرفر.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreLoading extends StatelessWidget {
  const _ScoreLoading();

  @override
  Widget build(BuildContext context) {
    return const TacticalCard(
      child: SizedBox(
        height: 190,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جارٍ فحص البلوتوث والمستشعرات والبطارية…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.score});

  final DeviceScoreModel score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = AppColors.statusColor(
      score.totalScore.toDouble(),
      redNight: scheme.primary == AppColors.redPrimary,
    );

    return TacticalCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: score.normalized,
                        strokeWidth: 9,
                        color: color,
                        backgroundColor: scheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.totalScore}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          'من 100',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الدور التكتيكي المقترح',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      score.tacticalRole,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          label: _roleLabel(score.roleCode),
                          color: color,
                          icon: Icons.military_tech,
                          compact: true,
                        ),
                        StatusPill(
                          label:
                              '${score.passedChecksCount}/${score.totalChecksCount} فحص ناجح',
                          color: scheme.primary,
                          compact: true,
                        ),
                        if (score.estimatedChecksCount > 0)
                          StatusPill(
                            label: '${score.estimatedChecksCount} تقديري',
                            color: scheme.secondary,
                            icon: Icons.help_outline,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: scheme.outline.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'آخر فحص: ${_formatTime(score.assessedAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    ProviderScope.containerOf(context)
                        .invalidate(deviceScoreProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('إعادة الفحص'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String code) {
    switch (code) {
      case 'gold':
        return 'عقدة ذهبية';
      case 'silver':
        return 'عقدة فضية';
      default:
        return 'وضع البقاء';
    }
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

class _MeshPanel extends ConsumerWidget {
  const _MeshPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(meshManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final statusColor = switch (manager.status) {
          MeshStatus.online => AppColors.success,
          MeshStatus.simulation => AppColors.warning,
          MeshStatus.error => AppColors.danger,
          MeshStatus.starting => AppColors.accent,
          MeshStatus.stopped => scheme.onSurface.withValues(alpha: 0.5),
        };

        return TacticalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'شبكة المش اللامركزية',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: manager.status.label,
                    color: statusColor,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatTile(
                    label: 'العقد المجاورة',
                    value: '${manager.peerCount}',
                    icon: Icons.devices_other,
                  ),
                  StatTile(
                    label: 'حزم مُمرَّرة',
                    value: '${manager.packetsRelayed}',
                    icon: Icons.forward_to_inbox,
                  ),
                  StatTile(
                    label: 'حزم مستلمة',
                    value: '${manager.packetsReceived}',
                    icon: Icons.download_for_offline_outlined,
                  ),
                  StatTile(
                    label: 'دورات مزامنة',
                    value: '${manager.syncRounds}',
                    icon: Icons.sync,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'معرّف العقدة: ${manager.nodeId ?? 'جارٍ التوليد…'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (manager.lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  manager.lastError!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    height: 1.5,
                  ),
                ),
              ],
              if (manager.isSimulation) ...[
                const SizedBox(height: 8),
                Text(
                  'وضع المحاكاة: لا يتوفر عتاد BLE أو لم تُمنح الصلاحيات. '
                  'العقد المعروضة افتراضية ولا تُرسل رسائل حقيقية.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          unawaited(ref.read(meshManagerProvider).syncNow()),
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('مزامنة الآن'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'إعادة تشغيل البلوتوث',
                    onPressed: () =>
                        unawaited(ref.read(meshManagerProvider).restart()),
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
              if (manager.peers.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...manager.peers
                    .take(3)
                    .map(
                      (peer) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.bluetooth, size: 14, color: statusColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${peer.name} · ${peer.nodeId}',
                                style: theme.textTheme.labelSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${peer.rssi} dBm',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownPanel extends ConsumerWidget {
  const _BreakdownPanel();

  static const Map<String, (String, int)> _meta = {
    'meshScore': ('شبكات المش', 30),
    'aiScore': ('الذكاء الاصطناعي والذاكرة', 25),
    'sensorScore': ('المستشعرات البيئية', 20),
    'batteryScore': ('إدارة الطاقة', 15),
    'storageScore': ('التخزين والتشفير', 10),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(deviceScoreProvider).value;
    if (score == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return TacticalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'تفصيل النقاط', padding: EdgeInsets.zero),
          ..._meta.entries.map((entry) {
            final value = score.breakdown[entry.key] ?? 0;
            final ratio = entry.value.$2 == 0 ? 0.0 : value / entry.value.$2;
            final color = ratio >= 0.8
                ? AppColors.success
                : ratio >= 0.4
                ? AppColors.accent
                : AppColors.danger;
            return MetricBar(
              label: entry.value.$1,
              value: value,
              max: entry.value.$2,
              color: color,
            );
          }),
          const SizedBox(height: 4),
          Text(
            'الدرجات التقديرية (NPU، RAM، Wi-Fi Direct، المساحة) مبنية على '
            'خصائص المنصة ولا تُقاس عبر واجهة نظام عامة.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecksPanel extends ConsumerWidget {
  const _ChecksPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(deviceScoreProvider).value;
    if (score == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TacticalCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.fact_check_outlined, color: scheme.primary),
        title: const Text(
          'سجل الفحوص التفصيلي',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          '${score.totalChecksCount} فحصاً — اضغط للتفاصيل',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        children: [
          for (final check in score.checks)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    check.passed ? Icons.check_circle : Icons.cancel_outlined,
                    size: 17,
                    color: check.passed
                        ? AppColors.success
                        : scheme.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                check.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${check.awardedPoints}/${check.maxPoints}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: check.passed
                                    ? AppColors.success
                                    : scheme.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (check.estimated) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.help_outline,
                                size: 12,
                                color: scheme.secondary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          check.detail,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ── تدفق نداءات الاستغاثة ────────────────────────────────────────────────

class _SosPanel extends ConsumerWidget {
  const _SosPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(sosFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'نداءات الاستغاثة الواردة',
          subtitle: 'رسائل SOS موقّعة تنتقل عبر قفزات المش حتى تصل إليك.',
          trailing: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MeshSosScreen())),
            icon: const Icon(Icons.sos, size: 18),
            label: const Text('بث SOS'),
          ),
        ),
        if (messages.isEmpty)
          const TacticalCard(
            padding: EdgeInsets.zero,
            child: EmptyState(
              icon: Icons.health_and_safety_outlined,
              title: 'لا توجد نداءات استغاثة بعد',
              subtitle: 'سيظهر هنا كل نداء يصل عبر البلوتوث أو المحاكاة، مع حالة التحقق من التوقيع.',
            ),
          )
        else
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SosMessageCard(message: message),
            ),
          ),
      ],
    );
  }
}
