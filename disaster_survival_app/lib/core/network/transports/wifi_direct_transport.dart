import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../../utils/pki_verifier.dart';
import '../mesh_peer.dart';
import 'mesh_transport.dart';

/// ناقل Wi-Fi Direct (P2P) عبر Google Nearby Connections API.
///
/// يدعم Android (و iOS جزئياً). على المنصات غير المدعومة (Windows/macOS/Web)
/// أو عند غياب عتاد Wi-Fi Direct، ينتقل الناقل إلى حالة `unavailable`
/// دون تعطيل بقية شبكة المش (BLE يبقى نشطاً).
class WifiDirectTransport implements MeshTransport {
  WifiDirectTransport({
    required this.pki,
    this.serviceId = 'com.resilienet.meket_mesh',
  });

  final PkiVerifier pki;
  final String serviceId;

  static const Strategy _strategy = Strategy.P2P_CLUSTER;

  String? _nodeId;
  MeshStatus _status = MeshStatus.stopped;
  String? _lastError;
  final Map<String, MeshPeer> _peers = {};
  final Set<String> _connected = {};

  @override
  String get id => 'wifi-direct';

  @override
  String get displayName => 'Wi-Fi Direct';

  @override
  MeshStatus get status => _status;

  @override
  String? get lastError => _lastError;

  @override
  List<MeshPeer> get peers => _peers.values.toList(growable: false);

  @override
  int get peerCount => _peers.length;

  @override
  bool get isSimulation => false;

  @override
  bool get supportsSync => false;

  @override
  bool get isAdvertising => false;

  @override
  bool get isScanning => false;

  @override
  void Function(Uint8List bytes, String fromNodeId)? onReceive;

  bool get _platformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<void> init() async {
    if (!_platformSupported) {
      _status = MeshStatus.unavailable;
      _lastError = 'Wi-Fi Direct غير مدعوم على هذه المنصة.';
      return;
    }
    try {
      final identity = await pki.ensureIdentity();
      _nodeId = identity.nodeId;
    } catch (error) {
      _lastError = 'تعذّر توليد هوية Wi-Fi Direct: $error';
      _status = MeshStatus.error;
    }
  }

  @override
  Future<void> start() async {
    if (!_platformSupported) {
      _status = MeshStatus.unavailable;
      return;
    }
    if (_nodeId == null) await init();
    if (_nodeId == null) return;

    _setStatus(MeshStatus.starting);
    _lastError = null;

    try {
      final advOk = await Nearby().startAdvertising(
        'RN:$_nodeId',
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      final discOk = await Nearby().startDiscovery(
        'RN:$_nodeId',
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: serviceId,
      );

      if (!advOk && !discOk) {
        _lastError = 'تعذّر بدء الإعلان/المسح عبر Wi-Fi Direct.';
        _setStatus(MeshStatus.error);
        return;
      }
      _setStatus(MeshStatus.online);
    } catch (error) {
      _lastError = 'فشل Wi-Fi Direct: $error';
      _setStatus(MeshStatus.error);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await Nearby().stopAdvertising();
    } catch (_) {}
    try {
      await Nearby().stopDiscovery();
    } catch (_) {}
    try {
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    _peers.clear();
    _connected.clear();
    _setStatus(MeshStatus.stopped);
  }

  @override
  Future<void> restart() async {
    await stop();
    await start();
  }

  @override
  Future<void> send(Uint8List bytes) async {
    for (final endpointId in _connected) {
      try {
        await Nearby().sendBytesPayload(endpointId, bytes);
      } catch (error) {
        _lastError = 'تعذّر إرسال Wi-Fi Direct: $error';
      }
    }
  }

  @override
  Future<void> syncNow() async {}

  void _setStatus(MeshStatus status) {
    if (_status == status) return;
    _status = status;
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    unawaited(
      Nearby()
          .acceptConnection(
            endpointId,
            onPayLoadRecieved: (endpointId, payload) {
              final bytes = payload.bytes;
              if (bytes != null && onReceive != null) {
                onReceive!(bytes, endpointId);
              }
            },
            onPayloadTransferUpdate: (endpointId, update) {},
          )
          .catchError((_) => false),
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connected.add(endpointId);
      _peers[endpointId] = MeshPeer(
        nodeId: endpointId,
        remoteId: endpointId,
        rssi: -55,
        lastSeen: DateTime.now(),
        name: 'عقدة Wi-Fi Direct',
        transportId: id,
        rssiEstimated: true,
      );
    } else {
      _connected.remove(endpointId);
      _peers.remove(endpointId);
    }
  }

  void _onDisconnected(String endpointId) {
    _connected.remove(endpointId);
    _peers.remove(endpointId);
  }

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    // الاتصال تلقائياً عند الاكتشاف (P2P_CLUSTER).
    unawaited(
      Nearby()
          .requestConnection(
            'RN:$_nodeId',
            endpointId,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
          )
          .catchError((_) => false),
    );
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    _peers.remove(endpointId);
    _connected.remove(endpointId);
  }
}
