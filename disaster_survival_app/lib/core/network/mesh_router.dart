import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dtn_packet_handler.dart';
import 'mesh_manager.dart';
import 'transports/ble_transport.dart';
import 'transports/mesh_transport.dart';
import 'transports/wifi_direct_transport.dart';

/// موجّه شبكة المش: يجمع عدة نواقل (BLE، Wi-Fi Direct، …) في طبقة نقل واحدة
/// لـ DTN والواجهة، مع تمرير (Store-and-Forward) مشترك ومنع تكرار موحّد.
class MeshRouter extends ChangeNotifier {
  MeshRouter({required this.dtn, List<MeshTransport>? transports}) {
    _transports = transports ?? _defaultTransports();
    for (final t in _transports) {
      t.onReceive = (bytes, from) => unawaited(_handleIncoming(bytes));
    }
  }

  final DtnPacketHandler dtn;
  late final List<MeshTransport> _transports;

  List<MeshTransport> _defaultTransports() {
    final bleManager = MeshManager(dtn);
    return [
      BleTransport(bleManager),
      WifiDirectTransport(pki: dtn.pki),
    ];
  }

  MeshStatus _status = MeshStatus.stopped;
  bool _initialized = false;
  bool _disposed = false;
  String? _lastError;
  String? _nodeId;
  DateTime? _lastSyncAt;
  int _packetsRelayed = 0;
  int _packetsReceived = 0;
  int _syncRounds = 0;
  bool _syncing = false;

  // ── خصائص عامة (متوافقة مع MeshManager) ──────────────────────────────

  MeshStatus get status => _status;
  String? get lastError => _lastError;
  String? get nodeId => _nodeId;
  bool get isAdvertising => _transports.any((t) => t.isAdvertising);
  bool get isScanning => _transports.any((t) => t.isScanning);
  bool get isSyncing => _syncing;
  bool get isSimulation => _transports.isNotEmpty && _transports.every((t) => t.isSimulation);
  DateTime? get lastSyncAt => _lastSyncAt;
  int get packetsRelayed => _packetsRelayed;
  int get packetsReceived => _packetsReceived;
  int get syncRounds => _syncRounds;

  /// عقد مجاورة (اتحاد جميع النواقل، إزالة التكرار حسب nodeId).
  List<MeshPeer> get peers {
    final seen = <String>{};
    final result = <MeshPeer>[];
    for (final t in _transports) {
      for (final p in t.peers) {
        if (seen.add(p.nodeId)) result.add(p);
      }
    }
    result.sort((a, b) => b.rssi.compareTo(a.rssi));
    return result;
  }

  int get peerCount => peers.length;

  List<MeshTransport> get transports => List.unmodifiable(_transports);

  // ── دورة الحياة ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await start();
  }

  Future<void> start() async {
    if (_disposed) return;
    _setStatus(MeshStatus.starting);
    _lastError = null;

    try {
      final identity = await dtn.pki.ensureIdentity();
      _nodeId = identity.nodeId;
    } catch (error) {
      _lastError = 'تعذّر توليد هوية العقدة: $error';
    }

    if (_nodeId == null) {
      _setStatus(MeshStatus.error);
      return;
    }

    for (final t in _transports) {
      try {
        await t.init();
        await t.start();
      } catch (error) {
        _lastError = '${t.displayName}: $error';
      }
    }

    final anyOnline = _transports.any((t) => t.status == MeshStatus.online);
    final anySim = _transports.any((t) => t.status == MeshStatus.simulation);
    if (anyOnline) {
      _setStatus(MeshStatus.online);
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 18), (_) => unawaited(syncNow()));
    } else if (anySim) {
      _setStatus(MeshStatus.simulation);
    } else {
      _setStatus(MeshStatus.error);
    }
  }

  Timer? _syncTimer;

  Future<void> stop() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    for (final t in _transports) {
      try {
        await t.stop();
      } catch (_) {}
    }
    _setStatus(MeshStatus.stopped);
  }

  Future<void> restart() async {
    await stop();
    _initialized = false;
    await init();
  }

  // ── إرسال/استقبال ──────────────────────────────────────────────────────

  Future<void> broadcastEnvelope(DtnEnvelope envelope) async {
    await dtn.queueForRelay(envelope);
    await dtn.acceptEnvelope(envelope);
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_disposed || _syncing) return;
    if (_status == MeshStatus.stopped || _status == MeshStatus.error) return;

    _syncing = true;
    _notify();
    try {
      for (final t in _transports) {
        if (!t.supportsSync) continue;
        try {
          await t.syncNow();
        } catch (_) {}
      }
      // تمرير صندوق الصادر عبر كل ناقل (Wi-Fi Direct يرسل bytes مباشرة).
      final outbox = await dtn.outboxEnvelopes();
      for (final envelope in outbox) {
        final payload = Uint8List.fromList(envelope.encode().codeUnits);
        for (final t in _transports) {
          if (t.id == 'ble') continue;
          try {
            await t.send(payload);
          } catch (_) {}
        }
        _packetsRelayed++;
      }
      _lastSyncAt = DateTime.now();
      _syncRounds++;
      _lastError = null;
    } catch (error) {
      _lastError = 'تعذّرت مزامنة المش: $error';
    } finally {
      _syncing = false;
      _notify();
    }
  }

  Future<void> _handleIncoming(Uint8List bytes) async {
    try {
      final text = String.fromCharCodes(bytes);
      final envelope = DtnEnvelope.decode(text);
      final accepted = await dtn.acceptEnvelope(envelope);
      _packetsReceived++;
      if (accepted && !envelope.isExpired && envelope.ttl > 1) {
        await dtn.queueForRelay(envelope.forwarded());
      }
      _notify();
    } catch (_) {
      // حمولة تالفة أو غير معروفة — يُهمل بصمت.
    }
  }

  void _setStatus(MeshStatus status) {
    if (_status == status) {
      _notify();
      return;
    }
    _status = status;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    for (final t in _transports) {
      try {
        t.onReceive = null;
        unawaited(t.stop());
      } catch (_) {}
    }
    super.dispose();
  }
}

/// مزوّد موجّه المش. يربط معالج DTN بطبقة النقل تلقائياً.
final meshManagerProvider = Provider<MeshRouter>((ref) {
  final handler = ref.watch(dtnPacketHandlerProvider);
  final router = MeshRouter(dtn: handler);
  handler.attachBroadcast(router.broadcastEnvelope);
  ref.onDispose(router.dispose);
  return router;
});

