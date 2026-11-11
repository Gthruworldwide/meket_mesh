import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_bulletin.dart';

/// مستمع أنباء أوفلاين عبر موجات FM-RDS / راديو معرف بالبرمجيات (SDR).
///
/// الواقع الميداني: استقبال RDS الحقيقي يتطلب:
///   * شريحة FM مدمجة تدعم RDS (معظم الهواتف لا توفر واجهة عامة لها)، أو
///   * دونجل SDR (مثل RTL-SDR) متصلاً عبر USB-OTG + قناة أصلية (Native).
///
/// ما تنفذه هذه الخدمة الآن:
///   * بروتوكول تجميع/تفكيك رسائل RDS (RadioText 4 أحرف/مجموعة) جاهز للاختبار.
///   * محاكاة بث دوري للتحقق من مسار العرض والتحقق (PKI) داخل التطبيق.
///   * واجهة `isSdrAttached()` لاكتشاف العتاد مستقبلاً.
class RdsSdrListener {
  RdsSdrListener({this.simulationInterval = const Duration(seconds: 22)});

  final Duration simulationInterval;

  final StreamController<NewsBulletin> _controller =
      StreamController<NewsBulletin>.broadcast();

  Timer? _timer;
  int _cursor = 0;
  bool _running = false;

  /// تدفق الأخبار المستقبلة من الراديو.
  Stream<NewsBulletin> get bulletins => _controller.stream;

  bool get isRunning => _running;

  /// بدء الاستماع (وضع المحاكاة افتراضياً حتى توفر قناة SDR الأصلية).
  void start() {
    if (_running) return;
    _running = true;
    // أول نشرة بعد 4 ثوانٍ لتمكين المستخدم من رؤية التحديث، ثم بوتيرة ثابتة.
    Timer(const Duration(seconds: 4), _emitNext);
    _timer = Timer.periodic(simulationInterval, (_) => _emitNext());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void _emitNext() {
    if (!_running) return;
    final sample = _simulatedBulletins[_cursor % _simulatedBulletins.length];
    _cursor++;
    _controller.add(
      NewsBulletin(
        id: 'rds-${DateTime.now().microsecondsSinceEpoch}',
        title: sample.$1,
        body: sample.$2,
        severity: sample.$3,
        source: 'FM-RDS (محاكاة)',
        originNodeId: 'RDS-SIM-${(_cursor).toString().padLeft(3, '0')}',
        timestamp: DateTime.now(),
      ),
    );
  }

  /// هل يوجد دونجل SDR متصل؟ (يتطلب قناة أصلية — غير مدعوم بعد).
  Future<bool> isSdrAttached() async => false;

  // ── بروتوكول RDS المصغر ───────────────────────────────────────────────
  //
  // في RDS الحقيقي يحمل RadioText مجموعات من 4 أحرف (2 حرف/مجموعة فعلياً
  // عبر مجموعات 2A/2B) وتُعاد بتكرار. هنا نجزّئ أي نص إلى مقاطع 4 أحرف
  // لتوضيح إعادة التجميع والتحقق من السلامة، مع ترويسة رقم إصدار.

  /// تقسيم نص إلى مقاطع RDS رباعية الأحرف.
  static List<String> encodeRadioText(String text) {
    final frames = <String>[];
    for (var i = 0; i < text.length; i += 4) {
      frames.add(
        text.substring(i, (i + 4 > text.length) ? text.length : i + 4),
      );
    }
    return frames;
  }

  /// إعادة تجميع المقاطع إلى النص الأصلي.
  static String decodeRadioText(List<String> frames) => frames.join();

  /// تغليف خبر داخل حمولة RDS نصية قابلة للبث.
  static String encodeBulletin(NewsBulletin bulletin) {
    return 'RN1|${base64Encode(utf8.encode(jsonEncode(bulletin.toJson())))}';
  }

  /// محاولة فك حزمة RDS مستلمة إلى خبر.
  static NewsBulletin? decodeBulletin(String radiotext) {
    if (!radiotext.startsWith('RN1|')) return null;
    try {
      final raw = utf8.decode(base64Decode(radiotext.substring(4)));
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return NewsBulletin.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── نماذج أنباء المحاكاة (تغطي أنواع كوارث متعددة) ────────────────────
  static const List<(String, String, NewsSeverity)> _simulatedBulletins = [
    (
      'تحذير سيول — وادي النمل',
      'ارتفاع منسوب المياه 3 أمتار خلال 30 دقيقة. انتقلوا فوراً إلى الطوابق العليا أو المرتفعات، ولا تعبروا الممرات المائية.',
      NewsSeverity.critical,
    ),
    (
      'نقطة توزيع مياه — مسجد الرحمة',
      'توزيع مياه شرب من الساعة 8 إلى 11 صباحاً. احضروا عبوات نظيفة، حصة الفرد 5 لترات يومياً.',
      NewsSeverity.advisory,
    ),
    (
      'فتح ممر إغاثي — الطريق الشرقي',
      'الممر الشرقي مفتوح أمام المشاة فقط. المركبات تُحوَّل عبر الطريق الزراعي بعد التأكد من سلامته.',
      NewsSeverity.info,
    ),
    (
      'تحذير إشعاعي — محيط المفاعل',
      'سحابة غبار مشع تتجه شمالاً بسرعة 12 كم/س. أغلقوا النوافذ، أطفئوا التهوية، واحتموا في الغرف الداخلية.',
      NewsSeverity.critical,
    ),
    (
      'مركز إيواء — المدرسة الثانوية',
      'يستقبل المركز 200 شخص، تتوفر بطانيات ومياه. الأولوية للحوامل والأطفال وكبار السن.',
      NewsSeverity.advisory,
    ),
    (
      'شبكة مش نشطة — 12 عقدة',
      'أُعيد تشغيل عقدة التمرير المركزية. يمكن إرسال رسائل SOS عبر المش لمسافة 4 كم حتى الآن.',
      NewsSeverity.info,
    ),
    (
      'هزة ارتدادية — إخلاء المباني المتصدعة',
      'هزة بقوة 5.1 على مقياس ريختر قبل دقائق. أخلوا المباني المتشققة وتجنبوا الواجهات الزجاجية.',
      NewsSeverity.critical,
    ),
    (
      'نقص أدوية — نداء تبرع',
      'مركز الفرز يحتاج فصيلة O- وأدوية ضغط. راجعوا نقطة التبرع في العيادة الميدانية.',
      NewsSeverity.advisory,
    ),
  ];
}

final rdsListenerProvider = Provider<RdsSdrListener>((ref) {
  final listener = RdsSdrListener();
  listener.start();
  ref.onDispose(listener.dispose);
  return listener;
});

/// تدفق أنباء FM-RDS كوسيط Riverpod.
final rdsBulletinsProvider = StreamProvider<NewsBulletin>((ref) {
  return ref.watch(rdsListenerProvider).bulletins;
});
