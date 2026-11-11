/// مستوى خطورة الخبر التكتيكي.
enum NewsSeverity { info, advisory, critical }

extension NewsSeverityX on NewsSeverity {
  String get label {
    switch (this) {
      case NewsSeverity.info:
        return 'معلومات';
      case NewsSeverity.advisory:
        return 'تنبيه';
      case NewsSeverity.critical:
        return 'خطر حرج';
    }
  }

  /// وزن للترتيب عند الدمج بين مصادر متعددة.
  int get weight {
    switch (this) {
      case NewsSeverity.info:
        return 1;
      case NewsSeverity.advisory:
        return 2;
      case NewsSeverity.critical:
        return 3;
    }
  }
}

NewsSeverity newsSeverityFromId(String? id) {
  for (final value in NewsSeverity.values) {
    if (value.name == id) return value;
  }
  return NewsSeverity.info;
}

/// حزمة خبر تكتيكي أوفلاين.
///
/// تنتقل عبر شبكة المش (DTN) أو تُستقبل من راديو FM-RDS، وتُرفَق بتوقيع
/// رقمي (Ed25519) للتحقق من المصدر دون إنترنت.
class NewsBulletin {
  final String id;
  final String title;
  final String body;
  final NewsSeverity severity;

  /// مصدر الخبر: «مش / DTN»، «FM-RDS (محاكاة)» ... إلخ.
  final String source;

  /// معرّف العقدة الناشرة (Node ID).
  final String originNodeId;

  final DateTime timestamp;

  /// عدد القفزات التي قطعها الخبر عبر المش.
  final int hops;

  /// توقيع المصدر (Base64).
  final String? signature;

  /// مفتاح المصدر العام (Base64) للتحقق.
  final String? signerKey;

  /// هل التوقيع صحيح؟
  final bool verified;

  /// هل المفتاح العام موجود في قائمة الثقة المحلية؟
  final bool trusted;

  const NewsBulletin({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.source,
    required this.originNodeId,
    required this.timestamp,
    this.hops = 0,
    this.signature,
    this.signerKey,
    this.verified = false,
    this.trusted = false,
  });

  /// صياغة عربية لعمر الخبر.
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  /// بيانات الخبر القابلة للنقل (بدون حقول التحقق المحلية).
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'severity': severity.name,
    'source': source,
    'originNodeId': originNodeId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'hops': hops,
    'signature': signature,
    'signerKey': signerKey,
  };

  factory NewsBulletin.fromJson(Map<String, dynamic> json) {
    return NewsBulletin(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      severity: newsSeverityFromId(json['severity'] as String?),
      source: json['source'] as String? ?? 'غير معروف',
      originNodeId: json['originNodeId'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      hops: json['hops'] as int? ?? 0,
      signature: json['signature'] as String?,
      signerKey: json['signerKey'] as String?,
      verified: json['verified'] as bool? ?? false,
      trusted: json['trusted'] as bool? ?? false,
    );
  }
}
