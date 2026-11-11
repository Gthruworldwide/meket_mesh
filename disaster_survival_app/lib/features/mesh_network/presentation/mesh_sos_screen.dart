import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dtn_packet_handler.dart';
import '../../../core/network/mesh_manager.dart';
import '../../../core/state/app_settings.dart';
import '../../../core/widgets/red_night_toggle.dart';
import '../../../core/widgets/tactical_widgets.dart';
import '../models/mesh_link.dart';
import '../services/location_service.dart';
import '../services/mesh_outbox.dart';
import '../services/sos_draft.dart';
import '../services/sos_feed.dart';
import 'sos_message_card.dart';

/// شاشة شبكة المش والاستغاثة الأوفلاين.
///
/// تجمع ثلاث وظائف تكتيكية في مكان واحد:
///  1. مراقبة طبقة النقل (الإعلان/المسح/الجوار/التمرير).
///  2. إنشاء نداء استغاثة موقّع وإرفاق الموقع اختيارياً.
///  3. متابعة صندوق التمرير والنداءات الواردة.
class MeshSosScreen extends ConsumerStatefulWidget {
  const MeshSosScreen({super.key});

  @override
  ConsumerState<MeshSosScreen> createState() => _MeshSosScreenState();
}

class _MeshSosScreenState extends ConsumerState<MeshSosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  late final TextEditingController _callsignController;

  bool _attachLocation = true;
  bool _sending = false;
  bool _resolving = false;
  GeoFix? _lastFix;
  String? _locationError;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    _callsignController = TextEditingController(
      text: ref.read(callsignProvider),
    );
  }

  @override
  void dispose() {
    _callsignController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(meshManagerProvider);
    final messages = ref.watch(sosFeedProvider);
    final outbox = ref.watch(meshOutboxProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المش والاستغاثة'),
        actions: const [RedNightToggle(), SizedBox(width: 4)],
      ),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final readiness = MeshReadiness.evaluate(
            peerCount: manager.peerCount,
            online: manager.status == MeshStatus.online,
            simulation: manager.isSimulation,
            syncRounds: manager.syncRounds,
            relayed: manager.packetsRelayed,
            received: manager.packetsReceived,
          );
          final links = manager.peers.map(MeshNodeLink.fromPeer).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
            children: [
              _NetworkOverview(
                manager: manager,
                readiness: readiness,
                onSync: _syncNow,
              ),
              SectionHeader(
                title: 'العقد المجاورة',
                subtitle: 'تُكتشف عبر خدمة ResiliNet GATT. تُختار الأقوى إشارة لكل دورة تمرير.',
                trailing: StatusPill(
                  label: '${links.length} عقدة',
                  color: links.isEmpty ? AppColors.warning : AppColors.success,
                  compact: true,
                ),
              ),
              if (links.isEmpty)
                const TacticalCard(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: Icons.bluetooth_searching,
                    title: 'لا توجد عقد مجاورة الآن',
                    subtitle: 'أبقِ البلوتوث مفعّلاً واقترب من عقدة أخرى. في وضع المحاكاة تظهر عقد افتراضية للاستعراض.',
                  ),
                )
              else
                ...links.map(
                  (link) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PeerCard(link: link),
                  ),
                ),
              SectionHeader(
                title: 'بث نداء استغاثة',
                subtitle: 'يُوقَّع النداء بمفتاح جهازك (Ed25519) ويُحفظ في صندوق التمرير حتى تلتقطه عقدة مجاورة.',
                trailing: StatusPill(
                  label: manager.isSimulation ? 'محاكاة' : 'مش حقيقية',
                  color: manager.isSimulation
                      ? AppColors.warning
                      : AppColors.success,
                  compact: true,
                ),
              ),
              _buildComposeCard(context, theme),
              SectionHeader(
                title: 'صندوق التمرير (Store & Forward)',
                subtitle: 'حزم تنتظر عقدة مجاورة. تُمرَّر تلقائياً كل 18 ثانية عند توفر وصلة.',
                trailing: IconButton(
                  tooltip: 'تحديث صندوق التمرير',
                  onPressed: () => ref.invalidate(meshOutboxProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ),
              _OutboxCard(outbox: outbox),
              const SectionHeader(
                title: 'آخر النداءات الواردة',
                subtitle: 'كل نداء موقّع يصل عبر المش أو المحاكاة يظهر هنا.',
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              if (messages.isEmpty)
                const TacticalCard(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: Icons.health_and_safety_outlined,
                    title: 'لا توجد نداءات بعد',
                    subtitle: 'عند وصول أول نداء سيظهر هنا مع حالة التحقق من التوقيع وعدد القفزات.',
                  ),
                )
              else
                ...messages
                    .take(5)
                    .map(
                      (message) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SosMessageCard(message: message),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposeCard(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final locationReady = !_attachLocation || _lastFix != null;

    return TacticalCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _callsignController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم النداء (Callsign)',
                prefixIcon: Icon(Icons.badge_outlined, size: 18),
              ),
              validator: SosDraft.validateCallsign,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              maxLength: SosDraft.maxMessageLength,
              decoration: const InputDecoration(
                labelText: 'وصف الحالة والموقع',
                hintText: 'مثال: محتجزون في الطابق الثالث، نحتاج ماءً وإسعافاً، لا يمكننا الحركة…',
                alignLabelWithHint: true,
              ),
              validator: SosDraft.validateMessage,
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _attachLocation,
              onChanged: _sending || _resolving
                  ? null
                  : (value) => setState(() {
                      _attachLocation = value;
                      _locationError = null;
                    }),
              title: const Text(
                'إرفاق الموقع الحالي',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'يُرفق إحداثي واحد لحظة البث فقط. لا يُتتبَّع الموقع باستمرار.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
              secondary: Icon(
                _attachLocation
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
                size: 20,
                color: _attachLocation ? scheme.primary : scheme.onSurface,
              ),
            ),
            if (_attachLocation) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _lastFix == null
                          ? (_locationError ?? 'لم يُحدَّد الموقع بعد.')
                          : '${_lastFix!.formatted} · ${_lastFix!.accuracyLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _lastFix == null
                            ? (_locationError == null
                                  ? scheme.onSurface.withValues(alpha: 0.55)
                                  : AppColors.warning)
                            : AppColors.success,
                        height: 1.5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _sending || _resolving ? null : _resolveLocation,
                    icon: _resolving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(_resolving ? 'جارٍ التحديد…' : 'تحديد الآن'),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sos),
                label: Text(
                  _sending
                      ? 'جارٍ توقيع النداء وبثّه…'
                      : locationReady
                      ? 'بث نداء الاستغاثة'
                      : 'بث بدون موقع',
                ),
              ),
            ),
            if (_lastSentAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'آخر نداء أُرسل الساعة ${_clock(_lastSentAt!)} — '
                      'ما زال في صندوق التمرير حتى تلتقطه عقدة.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'تنبيه: البث لا يضمن الوصول الفوري. يعتمد الأمر على وجود عقدة '
              'في المدى ومسار تمرير متصل. استخدم النداء الصوتي أو الإشارات '
              'البصرية بالتوازي عند الإمكان.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    await ref.read(meshManagerProvider).syncNow();
    ref.invalidate(meshOutboxProvider);
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _resolving = true;
      _locationError = null;
    });
    final fix = await ref.read(meshLocationServiceProvider).currentFix();
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _lastFix = fix;
      _locationError = fix == null
          ? 'تعذّر تحديد الموقع. تأكد من تفعيل GPS ومنح صلاحية الموقع.'
          : null;
    });
  }

  Future<void> _send() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final callsign = _callsignController.text.trim();
    final message = _messageController.text.trim();
    final includeLocation = _attachLocation;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos, color: AppColors.danger),
            SizedBox(width: 8),
            Text('تأكيد بث الاستغاثة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الاسم: $callsign',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 10),
            Text(
              includeLocation
                  ? 'سيُرفق آخر موقع معروف (أو يُحاول تحديده الآن).'
                  : 'سيُبث النداء نصياً بدون إحداثيات.',
              style: Theme.of(dialogContext).textTheme.labelSmall
                  ?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 6),
            Text(
              'لا يمكن سحب النداء بعد البث؛ قد تنسخه عدة عقد أثناء التمرير.',
              style: Theme.of(dialogContext).textTheme.labelSmall
                  ?.copyWith(color: AppColors.warning, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('بث الآن'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _sending = true;
      _locationError = null;
    });

    GeoFix? fix = _lastFix;
    if (includeLocation && fix == null) {
      fix = await ref.read(meshLocationServiceProvider).currentFix();
    }
    if (!mounted) return;

    final draft = SosDraft(callsign: callsign, message: message, fix: fix);
    try {
      await ref
          .read(dtnPacketHandlerProvider)
          .sendSos(
            callsign: draft.cleanCallsign,
            message: draft.cleanMessage,
            lat: draft.hasLocation ? draft.fix!.latitude : null,
            lng: draft.hasLocation ? draft.fix!.longitude : null,
          );
      if (!mounted) return;
      ref.read(callsignProvider.notifier).set(draft.cleanCallsign);
      unawaited(ref.read(meshManagerProvider).syncNow());
      ref.invalidate(meshOutboxProvider);
      setState(() {
        _sending = false;
        _lastFix = fix;
        _lastSentAt = DateTime.now();
        _messageController.clear();
        if (includeLocation && fix == null) {
          _locationError = 'أُرسل النداء بدون موقع — تعذّر تحديد الإحداثيات.';
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            fix == null
                ? 'تم بث نداء الاستغاثة (بدون إحداثيات).'
                : 'تم بث نداء الاستغاثة مع الموقع الحالي.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text('تعذّر بث النداء: $error')),
      );
    }
  }

  static String _clock(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

// ── نظرة عامة على طبقة النقل ─────────────────────────────────────────────

class _NetworkOverview extends StatelessWidget {
  const _NetworkOverview({
    required this.manager,
    required this.readiness,
    required this.onSync,
  });

  final MeshRouter manager;
  final MeshReadiness readiness;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(manager.status, scheme);
    final readinessColor = _readinessColor(readiness.score);

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
                  'حالة شبكة المش',
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
          Row(
            children: [
              Text(
                'صحة الشبكة',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                '${readiness.score}/100 · ${readiness.grade.label}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: readinessColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: readiness.normalized,
              minHeight: 7,
              color: readinessColor,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
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
                iconColor: statusColor,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                label: manager.isAdvertising ? 'إعلان نشط' : 'الإعلان متوقف',
                color: manager.isAdvertising
                    ? AppColors.success
                    : scheme.onSurface.withValues(alpha: 0.55),
                icon: Icons.cell_tower,
                compact: true,
              ),
              StatusPill(
                label: manager.isScanning ? 'مسح نشط' : 'المسح متوقف',
                color: manager.isScanning
                    ? AppColors.success
                    : scheme.onSurface.withValues(alpha: 0.55),
                icon: Icons.bluetooth_searching,
                compact: true,
              ),
              if (manager.isSimulation)
                const StatusPill(
                  label: 'عقد افتراضية',
                  color: AppColors.warning,
                  icon: Icons.science_outlined,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: manager.transports.map((t) {
              final c = t.status == MeshStatus.online
                  ? AppColors.success
                  : t.status == MeshStatus.simulation
                  ? AppColors.warning
                  : t.status == MeshStatus.unavailable
                  ? scheme.onSurface.withValues(alpha: 0.35)
                  : AppColors.danger;
              return StatusPill(
                label: '${t.displayName} · ${t.status.label}',
                color: c,
                icon: t.id == 'ble' ? Icons.bluetooth : Icons.wifi,
                compact: true,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                manager.lastSyncAt == null
                    ? 'لم تُجرَ مزامنة بعد'
                    : 'آخر مزامنة: ${_clock(manager.lastSyncAt!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
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
              'العقد المعروضة افتراضية، والنداءات تُوقَّع وتُحفظ محلياً دون نقل حقيقي.',
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
                  onPressed: manager.isSyncing
                      ? null
                      : () => unawaited(onSync()),
                  icon: manager.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(
                    manager.isSyncing ? 'جارٍ المزامنة…' : 'مزامنة الآن',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'إعادة تشغيل طبقة البلوتوث',
                onPressed: () => unawaited(manager.restart()),
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── بطاقة عقدة مجاورة ────────────────────────────────────────────────────

class _PeerCard extends StatelessWidget {
  const _PeerCard({required this.link});

  final MeshNodeLink link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _signalColor(link.quality);

    return TacticalCard(
      child: Row(
        children: [
          _SignalBars(bars: link.signalBars, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        link.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (link.isSimulated)
                      const StatusPill(
                        label: 'محاكاة',
                        color: AppColors.warning,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  link.nodeId,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: _transportLabel(link.transportId),
                      color: _transportColor(link.transportId),
                      icon: _transportIcon(link.transportId),
                      compact: true,
                    ),
                    StatusPill(
                      label: '${link.rssi} dBm · ${link.quality.label}',
                      color: color,
                      icon: Icons.bluetooth,
                      compact: true,
                    ),
                    StatusPill(
                      label: 'شوهدت ${link.lastSeenLabel}',
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      icon: Icons.visibility_outlined,
                      compact: true,
                    ),
                    StatusPill(
                      label: link.lastSyncedAt == null
                          ? 'لم تُزامَن'
                          : 'زامنت ${link.lastSyncLabel}',
                      color: link.lastSyncedAt == null
                          ? scheme.onSurface.withValues(alpha: 0.55)
                          : AppColors.success,
                      icon: Icons.swap_horiz,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars, required this.color});

  final int bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < 4; index++) ...[
          Container(
            width: 4,
            height: 8.0 + index * 4,
            decoration: BoxDecoration(
              color: index < bars ? color : dim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (index < 3) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

// ── صندوق التمرير ────────────────────────────────────────────────────────

class _OutboxCard extends StatelessWidget {
  const _OutboxCard({required this.outbox});

  final AsyncValue<List<DtnEnvelope>> outbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return outbox.when(
      loading: () => const TacticalCard(
        child: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => TacticalCard(
        child: Text(
          'تعذّر قراءة صندوق التمرير: $error',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.warning,
            height: 1.5,
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const TacticalCard(
            child: Row(
              children: [
                Icon(Icons.inbox_outlined, color: AppColors.success),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'صندوق التمرير فارغ — كل الحزم وصلت إلى عقدة مجاورة أو انتهى عمرها.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }

        return TacticalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.outbox_outlined, color: scheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${items.length} حزمة بانتظار التمرير',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.take(6).map((envelope) {
                final isSos = envelope.isSos;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isSos ? Icons.sos : Icons.newspaper_outlined,
                        size: 16,
                        color: isSos ? AppColors.danger : scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSos
                              ? 'نداء استغاثة · ${envelope.payload['callsign'] ?? 'غير معروف'}'
                              : 'نشرة · ${envelope.payload['title'] ?? '(بدون عنوان)'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'TTL ${envelope.ttl} · ${_clock(envelope.createdAt.toLocal())}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (items.length > 6) ...[
                const SizedBox(height: 4),
                Text(
                  'و${items.length - 6} حزمة أخرى…',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
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

// ── مساعدات العرض ────────────────────────────────────────────────────────

Color _statusColor(MeshStatus status, ColorScheme scheme) {
  switch (status) {
    case MeshStatus.online:
      return AppColors.success;
    case MeshStatus.simulation:
      return AppColors.warning;
    case MeshStatus.error:
      return AppColors.danger;
    case MeshStatus.starting:
      return AppColors.accent;
    case MeshStatus.stopped:
      return scheme.onSurface.withValues(alpha: 0.5);
    case MeshStatus.unavailable:
      return scheme.onSurface.withValues(alpha: 0.35);
  }
}

Color _readinessColor(int score) {
  if (score >= 80) return AppColors.success;
  if (score >= 55) return AppColors.accent;
  if (score >= 30) return AppColors.warning;
  return AppColors.danger;
}

Color _signalColor(LinkQuality quality) {
  switch (quality) {
    case LinkQuality.excellent:
      return AppColors.success;
    case LinkQuality.good:
      return AppColors.primary;
    case LinkQuality.fair:
      return AppColors.accent;
    case LinkQuality.weak:
      return AppColors.danger;
  }
}

String _clock(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
// ── مساعدات النواقل ─────────────────────────────────────────────────────

Color _transportColor(String id) {
  switch (id) {
    case 'ble':
      return AppColors.accent; // ذهبي
    case 'wifi-direct':
      return const Color(0xFF4FC3F7); // أزرق
    default:
      return AppColors.primary;
  }
}

IconData _transportIcon(String id) {
  switch (id) {
    case 'ble':
      return Icons.bluetooth;
    case 'wifi-direct':
      return Icons.wifi;
    default:
      return Icons.hub_outlined;
  }
}

String _transportLabel(String id) {
  switch (id) {
    case 'ble':
      return 'BLE';
    case 'wifi-direct':
      return 'Wi-Fi Direct';
    default:
      return id;
  }
}
