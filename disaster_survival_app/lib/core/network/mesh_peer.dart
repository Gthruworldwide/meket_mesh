/// حالة طبقة النقل في شبكة المش.
enum MeshStatus { stopped, starting, online, simulation, error, unavailable }

extension MeshStatusX on MeshStatus {
  String get label {
    switch (this) {
      case MeshStatus.stopped:
        return 'متوقفة';
      case MeshStatus.starting:
        return 'جارٍ التشغيل';
      case MeshStatus.online:
        return 'مش BLE نشطة';
      case MeshStatus.simulation:
        return 'وضع محاكاة';
      case MeshStatus.error:
        return 'تعذّر تشغيل البلوتوث';
      case MeshStatus.unavailable:
        return 'غير متاح على هذه المنصة';
    }
  }
}

/// عقدة مجاورة مكتشفة عبر أي ناقل.
class MeshPeer {
  MeshPeer({
    required this.nodeId,
    required this.remoteId,
    required this.rssi,
    required this.lastSeen,
    this.name = 'عقدة ResiliNet',
    this.transportId = 'ble',
  });

  final String nodeId;
  String remoteId;
  int rssi;
  DateTime lastSeen;
  String name;
  final String transportId;

  /// وقت آخر مزامنة ناجحة مع هذه العقدة.
  DateTime? lastSyncedAt;

  bool get isFresh =>
      DateTime.now().difference(lastSeen) < const Duration(minutes: 2);
}
