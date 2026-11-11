/// نتيجة فحص واحدة ضمن مقياس جاهزية الجهاز.
class DeviceCheck {
  final String id;
  final String label;

  /// النقاط القصوى الممكنة لهذا الفحص.
  final int maxPoints;

  /// النقاط الممنوحة فعلياً.
  final int awardedPoints;

  /// هل النتيجة تقديرية (لا توجد واجهة نظام عامة للفحص الدقيق)؟
  final bool estimated;

  /// شرح مختصر للنتيجة.
  final String detail;

  const DeviceCheck({
    required this.id,
    required this.label,
    required this.maxPoints,
    required this.awardedPoints,
    required this.estimated,
    required this.detail,
  });

  bool get passed => awardedPoints > 0;

  double get ratio => maxPoints <= 0 ? 0 : awardedPoints / maxPoints;
}

/// نموذج نتيجة مقياس جاهزية الجهاز (من 100).
class DeviceScoreModel {
  final int totalScore;

  /// الدور التكتيكي المقترح للجهاز.
  final String tacticalRole;

  /// معرّف الدور: gold / silver / basic.
  final String roleCode;

  /// تفصيل النقاط لكل محور.
  final Map<String, int> breakdown;

  /// تفاصيل كل فحص على حدة.
  final List<DeviceCheck> checks;

  final DateTime assessedAt;

  const DeviceScoreModel({
    required this.totalScore,
    required this.tacticalRole,
    required this.roleCode,
    required this.breakdown,
    required this.checks,
    required this.assessedAt,
  });

  double get normalized => totalScore / 100;

  int get estimatedChecksCount => checks.where((c) => c.estimated).length;

  int get passedChecksCount => checks.where((c) => c.passed).length;

  int get totalChecksCount => checks.length;
}
