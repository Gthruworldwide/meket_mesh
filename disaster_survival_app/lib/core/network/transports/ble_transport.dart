import 'dart:typed_data';

import '../mesh_manager.dart';
import 'mesh_transport.dart';

/// ناقل BLE — يغلّف [MeshManager] (التي تحتوي منطق الإعلان/المسح/الإطارات).
class BleTransport implements MeshTransport {
  BleTransport(this._manager);

  final MeshManager _manager;

  @override
  String get id => 'ble';

  @override
  String get displayName => 'Bluetooth LE';

  @override
  MeshStatus get status => _manager.status;

  @override
  String? get lastError => _manager.lastError;

  @override
  List<MeshPeer> get peers => _manager.peers;

  @override
  int get peerCount => _manager.peerCount;

  @override
  bool get isSimulation => _manager.isSimulation;

  @override
  bool get supportsSync => true;

  @override
  Future<void> init() => _manager.init();

  @override
  Future<void> start() => _manager.start();

  @override
  Future<void> stop() => _manager.stop();

  @override
  Future<void> restart() => _manager.restart();

  @override
  Future<void> send(Uint8List bytes) async {
    // BLE يرسل عبر صندوق الصادر (DTN) — لا إرسال مباشر.
  }

  @override
  Future<void> syncNow() => _manager.syncNow();

  @override
  bool get isAdvertising => _manager.isAdvertising;

  @override
  bool get isScanning => _manager.isScanning;

  @override
  void Function(Uint8List bytes, String fromNodeId)? onReceive;
}
