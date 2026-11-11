import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dtn_packet_handler.dart';
import '../../../core/network/mesh_manager.dart';
import '../../../core/utils/local_store.dart';
import '../../../core/widgets/red_night_toggle.dart';
import '../../../core/widgets/tactical_widgets.dart';
import '../models/news_bulletin.dart';
import '../services/rds_sdr_listener.dart';

/// دمج أنباء المش (DTN) وأنباء FM-RDS في تدفق واحد مرتب حسب الخطورة والزمن.
class NewsFeedNotifier extends Notifier<List<NewsBulletin>> {
  static const int _maxItems = 60;

  @override
  List<NewsBulletin> build() {
    ref.listen(meshNewsProvider, (previous, next) {
      final bulletin = next.value;
      if (bulletin != null) _merge(bulletin);
    });
    ref.listen(rdsBulletinsProvider, (previous, next) {
      final bulletin = next.value;
      if (bulletin != null) _merge(bulletin);
    });
    return _seedFromStore();
  }

  void _merge(NewsBulletin bulletin) {
    if (bulletin.id.isEmpty) return;
    final next = <NewsBulletin>[
      bulletin,
      ...state.where((existing) => existing.id != bulletin.id),
    ];
    next.sort((a, b) {
      final severity = b.severity.weight.compareTo(a.severity.weight);
      if (severity != 0) return severity;
      return b.timestamp.compareTo(a.timestamp);
    });
    state = next.take(_maxItems).toList(growable: false);
  }

  List<NewsBulletin> _seedFromStore() {
    final bulletins = <NewsBulletin>[];
    for (final raw in LocalStore.values(LocalStore.dtnInbox)) {
      if (raw is! String) continue;
      try {
        final envelope = DtnEnvelope.decode(raw);
        if (envelope.type != DtnType.news) continue;
        bulletins.add(
          NewsBulletin(
            id: envelope.msgId,
            title: envelope.payload['title'] as String? ?? '(بدون عنوان)',
            body: envelope.payload['body'] as String? ?? '',
            severity: newsSeverityFromId(
              envelope.payload['severity'] as String?,
            ),
            source: 'مش / DTN (محفوظ)',
            originNodeId: envelope.originNodeId,
            timestamp: envelope.createdAt.toLocal(),
            hops: envelope.hops,
            signature: envelope.signature,
            signerKey: envelope.signerKey,
            verified: envelope.verified,
          ),
        );
      } catch (_) {}
    }
    bulletins.sort((a, b) {
      final severity = b.severity.weight.compareTo(a.severity.weight);
      if (severity != 0) return severity;
      return b.timestamp.compareTo(a.timestamp);
    });
    return bulletins.take(_maxItems).toList(growable: false);
  }
}

final newsFeedProvider = NotifierProvider<NewsFeedNotifier, List<NewsBulletin>>(
  NewsFeedNotifier.new,
);

/// شاشة الأنباء التكتيكية أوفلاين.
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  NewsSeverity? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.watch(meshManagerProvider);
    final all = ref.watch(newsFeedProvider);
    final bulletins = _filter == null
        ? all
        : all.where((bulletin) => bulletin.severity == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أنباء أوفلاين'),
        actions: [
          IconButton(
            tooltip: 'نشر نشرة محلية',
            onPressed: () => _openPublishDialog(context),
            icon: const Icon(Icons.campaign_outlined),
          ),
          const RedNightToggle(),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
        children: [
          TacticalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.podcasts, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مصادر الأنباء',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusPill(
                      label: '${all.length} نشرة',
                      color: scheme.primary,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تُدمج النشرات الواردة من شبكة المش (DTN) مع بث FM-RDS. '
                  'كل نشرة قابلة للتحقق بتوقيع Ed25519، ويمكن إعادة تمريرها '
                  'تلقائياً إلى العقد المجاورة.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: manager.isSimulation
                          ? 'FM-RDS (محاكاة)'
                          : 'FM-RDS + SDR',
                      color: AppColors.accent,
                      icon: Icons.radio,
                      compact: true,
                    ),
                    StatusPill(
                      label: 'مش BLE · ${manager.peerCount} عقدة',
                      color: AppColors.success,
                      icon: Icons.hub_outlined,
                      compact: true,
                    ),
                    const StatusPill(
                      label: 'توقيع PKI أوفلاين',
                      color: AppColors.primary,
                      icon: Icons.verified_user_outlined,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: const Text('الكل'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                ...NewsSeverity.values.map(
                  (severity) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(severity.label),
                      selected: _filter == severity,
                      onSelected: (selected) =>
                          setState(() => _filter = selected ? severity : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: _filter == null ? 'آخر الأنباء' : 'أنباء ${_filter!.label}',
            subtitle:
                'مرتبة حسب الخطورة ثم الأحدث. اسحب للأسفل للتحديث من المصادر.',
          ),
          if (bulletins.isEmpty)
            const TacticalCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                icon: Icons.newspaper_outlined,
                title: 'لا توجد نشرات بعد',
                subtitle: 'قد يستغرق أول بث FM-RDS بضع ثوانٍ. يمكنك أيضاً نشر نشرة محلية موقّعة.',
              ),
            )
          else
            ...bulletins.map(
              (bulletin) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BulletinCard(bulletin: bulletin),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openPublishDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var severity = NewsSeverity.advisory;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('نشر نشرة محلية موقّعة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                    validator: (value) =>
                        (value == null || value.trim().length < 3)
                        ? 'أدخل عنواناً واضحاً'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'نص النشرة',
                      hintText: 'مثال: نقطة توزيع مياه في المدرسة الثانوية من 8 إلى 11 صباحاً.',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 10)
                        ? 'اكتب نصاً لا يقل عن 10 أحرف'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<NewsSeverity>(
                    initialValue: severity,
                    decoration: const InputDecoration(
                      labelText: 'مستوى الخطورة',
                    ),
                    items: NewsSeverity.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => severity = value ?? severity),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ستُوقَّع النشرة بمفتاح جهازك، تُحفظ في صندوق الصادر، '
                    'وتُمرَّر عبر المش عند توفر عقدة مجاورة.',
                    style: Theme.of(dialogContext).textTheme.labelSmall
                        ?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('نشر'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      titleController.dispose();
      bodyController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final body = bodyController.text.trim();
    titleController.dispose();
    bodyController.dispose();

    try {
      await ref
          .read(dtnPacketHandlerProvider)
          .publishBulletin(title: title, body: body, severity: severity);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('نُشرت النشرة ووُقّعت وأُضيفت إلى صندوق التمرير.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('تعذّر نشر النشرة: $error')),
      );
    }
  }
}

class _BulletinCard extends StatelessWidget {
  const _BulletinCard({required this.bulletin});

  final NewsBulletin bulletin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final severityColor = switch (bulletin.severity) {
      NewsSeverity.critical => AppColors.danger,
      NewsSeverity.advisory => AppColors.accent,
      NewsSeverity.info => AppColors.success,
    };
    final verification = bulletin.trusted
        ? ('موثوق', AppColors.success, Icons.verified_user)
        : bulletin.verified
        ? ('توقيع صالح', scheme.primary, Icons.verified)
        : ('غير موثّق', AppColors.warning, Icons.gpp_maybe);

    return TacticalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        bulletin.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      label: bulletin.severity.label,
                      color: severityColor,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  bulletin.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.7,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: verification.$1,
                      color: verification.$2,
                      icon: verification.$3,
                      compact: true,
                    ),
                    StatusPill(
                      label: bulletin.source,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      icon: Icons.source,
                      compact: true,
                    ),
                    if (bulletin.hops > 0)
                      StatusPill(
                        label: '${bulletin.hops} قفزة',
                        color: scheme.primary,
                        icon: Icons.route,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${bulletin.timeAgo} · ${bulletin.originNodeId}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
