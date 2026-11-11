/// إحداثي جغرافي محلي يُرفق بنداء الاستغاثة (اختياري).
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  bool get isValid => latitude.abs() <= 90 && longitude.abs() <= 180;

  String get formatted =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  String get accuracyLabel => accuracyMeters == null
      ? 'دقة غير معروفة'
      : 'دقة ±${accuracyMeters!.round()} م';
}

/// مسودة نداء استغاثة قبل التوقيع والبث.
///
/// التحقق هنا نقي وقابل للاختبار ولا يعتمد على أي واجهة أو عتاد.
class SosDraft {
  const SosDraft({required this.callsign, required this.message, this.fix});

  static const int minMessageLength = 5;
  static const int maxMessageLength = 480;
  static const int maxCallsignLength = 32;

  final String callsign;
  final String message;
  final GeoFix? fix;

  String get cleanCallsign => callsign.trim();

  String get cleanMessage => message.trim();

  bool get hasLocation => fix != null && fix!.isValid;

  static String? validateCallsign(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'أدخل اسم النداء';
    if (text.length > maxCallsignLength) return 'اسم النداء أطول من 32 حرفاً';
    return null;
  }

  static String? validateMessage(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < minMessageLength) {
      return 'اكتب وصفاً واضحاً (5 أحرف على الأقل)';
    }
    if (text.length > maxMessageLength) {
      return 'الوصف يتجاوز $maxMessageLength حرفاً';
    }
    return null;
  }

  bool get isValid =>
      validateCallsign(cleanCallsign) == null &&
      validateMessage(cleanMessage) == null;

  /// الحمولة التي تُوقَّع وتُرسل داخل حزمة DTN من نوع `sos`.
  Map<String, dynamic> toPayload() => {
    'callsign': cleanCallsign,
    'message': cleanMessage,
    if (hasLocation) 'lat': fix!.latitude,
    if (hasLocation) 'lng': fix!.longitude,
  };
}
