import 'dart:typed_data';

import '../mesh_peer.dart';

/// واجهة ناقل (Transport) لشبكة المش.
///
/// كل ناقل (BLE، Wi-Fi Direct، …) يُنفّذ هذه الواجهة، وتجمع `MeshRouter`
/// عدة نواقل في طبقة نقل واحدة للـ DTN والواجهة.
abstract class MeshTransport {
  /// معرّف فريد للناقل (مثلاً 'ble', 'wifi-direct').
  String get id;

  /// اسم عرض للناقل (للواجهة).
  String get displayName;

  MeshStatus get status;
  String? get lastError;
  List<MeshPeer> get peers;
  int get peerCount;
  bool get isSimulation;

  Future<void> init();
  Future<void> start();
  Future<void> stop();
  Future<void> restart();

  /// إرسال حمولة (bytes) إلى كل الأقران المتصلين.
  Future<void> send(Uint8List bytes);

  /// هل يُعلِن هذا الناقل (advertising)؟
  bool get isAdvertising => false;

  /// هل يمسح هذا الناقل (scanning)؟
  bool get isScanning => false;

  /// استدعاء عند استقبال حمولة من أقران.
  void Function(Uint8List bytes, String fromNodeId)? onReceive;

  /// هل يدعم هذا الناقل المزامنة (syncNow)؟
  bool get supportsSync => false;

  Future<void> syncNow() async {}
}
