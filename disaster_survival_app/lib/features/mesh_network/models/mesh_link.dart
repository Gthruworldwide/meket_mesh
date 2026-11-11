import '../../../core/network/mesh_manager.dart';

/// جودة وصلة البلوتوث مع عقدة مجاورة، مشتقة من شدة الإشارة (RSSI).
enum LinkQuality {
  excellent,
  good,
  fair,
  weak;

  /// تصنيف RSSI إلى أربع درجات عملية (لا خطية مطلوبة للعرض التكتيكي).
  static LinkQuality fromRssi(int rssi) {
    if (rssi >= -60) return LinkQuality.excellent;
    if (rssi >= -72) return LinkQuality.good;
    if (rssi >= -85) return LinkQuality.fair;
    return LinkQuality.weak;
  }

  String get label {
    switch (this) {
      case LinkQuality.excellent:
        return 'ممتازة';
      case LinkQuality.good:
        return 'جيدة';
      case LinkQuality.fair:
        return 'متوسطة';
      case LinkQuality.weak:
        return 'ضعيفة';
    }
  }
}

/// عرض تكتيكي لعقدة مجاورة مكتشفة عبر المش.
class MeshNodeLink {
  const MeshNodeLink({
    required this.nodeId,
    required this.name,
    required this.remoteId,
    required this.rssi,
    required this.lastSeen,
    this.lastSyncedAt,
    this.transportId = 'ble',
    this.rssiEstimated = false,
  });

  factory MeshNodeLink.fromPeer(MeshPeer peer) => MeshNodeLink(
    nodeId: peer.nodeId,
    name: peer.name,
    remoteId: peer.remoteId,
    rssi: peer.rssi,
    lastSeen: peer.lastSeen,
    lastSyncedAt: peer.lastSyncedAt,
    transportId: peer.transportId,
    rssiEstimated: peer.rssiEstimated,
  );

  final String nodeId;
  final String name;
  final String remoteId;
  final int rssi;
  final DateTime lastSeen;
  final DateTime? lastSyncedAt;
  final String transportId;
  final bool rssiEstimated;

  LinkQuality get quality => LinkQuality.fromRssi(rssi);

  /// عدد الأعمدة المضاءة من أصل أربعة.
  int get signalBars => 4 - quality.index;

  bool get isSimulated => nodeId.startsWith('SIM-');

  bool get isFresh =>
      DateTime.now().difference(lastSeen) < const Duration(minutes: 2);

  String get lastSeenLabel => _relative(lastSeen);

  String get lastSyncLabel =>
      lastSyncedAt == null ? 'لم تُزامَن بعد' : _relative(lastSyncedAt!);

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} ي';
  }
}

/// تقدير تكتيكي لدرجة صحة شبكة المش من 100.
enum MeshGrade {
  robust,
  healthy,
  limited,
  critical;

  String get label {
    switch (this) {
      case MeshGrade.robust:
        return 'شبكة قوية';
      case MeshGrade.healthy:
        return 'شبكة جيدة';
      case MeshGrade.limited:
        return 'شبكة محدودة';
      case MeshGrade.critical:
        return 'شبكة حرجة';
    }
  }
}

/// حساب درجة صحة الشبكة اعتماداً على الحالة والجوار ونشاط التمرير.
///
/// الدرجة تفاضلية فقط ولا تعني ضمان وصول؛ كل حزمة DTN تبقى قابلة للتمرير
/// حتى ينتهي عمرها (TTL) بغض النظر عن هذه الدرجة.
class MeshReadiness {
  const MeshReadiness({
    required this.score,
    required this.grade,
    required this.peerPoints,
    required this.linkPoints,
    required this.syncPoints,
    required this.trafficPoints,
  });

  factory MeshReadiness.evaluate({
    required int peerCount,
    required bool online,
    required bool simulation,
    required int syncRounds,
    required int relayed,
    required int received,
  }) {
    final peerPoints = peerCount.clamp(0, 4) * 10;
    final linkPoints = online
        ? 20
        : simulation
        ? 12
        : 0;
    final syncPoints = syncRounds.clamp(0, 5) * 4;
    final trafficPoints = (relayed + received).clamp(0, 10) * 2;
    final score = (peerPoints + linkPoints + syncPoints + trafficPoints).clamp(
      0,
      100,
    );

    final grade = score >= 80
        ? MeshGrade.robust
        : score >= 55
        ? MeshGrade.healthy
        : score >= 30
        ? MeshGrade.limited
        : MeshGrade.critical;

    return MeshReadiness(
      score: score,
      grade: grade,
      peerPoints: peerPoints,
      linkPoints: linkPoints,
      syncPoints: syncPoints,
      trafficPoints: trafficPoints,
    );
  }

  final int score;
  final MeshGrade grade;
  final int peerPoints;
  final int linkPoints;
  final int syncPoints;
  final int trafficPoints;

  double get normalized => score / 100;
}
