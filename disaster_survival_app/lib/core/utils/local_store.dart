import 'package:hive_flutter/hive_flutter.dart';

/// طبقة التخزين المحلي الموحّدة (Hive) مع بديل في الذاكرة.
///
/// كل بيانات التطبيق تبقى على الجهاز: الهوية التشفيرية، قائمة التجهيزات،
/// صندوق وارد/صادر حزم DTN، ورسائل الأنباء. عند تعذّر تهيئة Hive
/// (بيئات اختبار أو منصات غير مدعومة) يتحول التخزين إلى الذاكرة تلقائياً
/// حتى لا تتعطل بقية المنظومة.
class LocalStore {
  LocalStore._();

  /// أسماء صناديق التخزين المستخدمة في التطبيق.
  static const String settingsBox = 'settings';
  static const String checklistBox = 'checklist';
  static const String identityBox = 'pki_identity';
  static const String trustBox = 'pki_trust';
  static const String dtnOutbox = 'dtn_outbox';
  static const String dtnInbox = 'dtn_inbox';
  static const String dtnSeen = 'dtn_seen';

  static const List<String> _boxes = [
    settingsBox,
    checklistBox,
    identityBox,
    trustBox,
    dtnOutbox,
    dtnInbox,
    dtnSeen,
  ];

  static bool _hiveReady = false;
  static final Map<String, Map<dynamic, dynamic>> _memory = {};

  /// هل تمت تهيئة Hive بنجاح؟
  static bool get isPersistent => _hiveReady;

  /// تهيئة التخزين وفتح كل الصناديق. تُستدعى مرة واحدة في `main`.
  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      for (final name in _boxes) {
        await Hive.openBox<dynamic>(name);
      }
      _hiveReady = true;
    } catch (_) {
      _hiveReady = false;
      for (final name in _boxes) {
        _memory.putIfAbsent(name, () => <dynamic, dynamic>{});
      }
    }
  }

  static Box<dynamic>? _box(String name) {
    if (_hiveReady && Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return null;
  }

  /// قراءة قيمة بشكل متزامن (مهم لبناء الواجهات مباشرة).
  static dynamic read(String box, dynamic key) {
    final hiveBox = _box(box);
    if (hiveBox != null) return hiveBox.get(key);
    return _memory[box]?[key];
  }

  /// قراءة بقيمة من نوع محدد.
  static T? get<T>(String boxScreen, dynamic key) {
    final value = read(boxScreen, key);
    return value is T ? value : null;
  }

  /// كتابة قيمة.
  static Future<void> write(String box, dynamic key, dynamic value) async {
    final hiveBox = _box(box);
    if (hiveBox != null) {
      await hiveBox.put(key, value);
      return;
    }
    _memory.putIfAbsent(box, () => <dynamic, dynamic>{})[key] = value;
  }

  /// حذف مفتاح.
  static Future<void> remove(String box, dynamic key) async {
    final hiveBox = _box(box);
    if (hiveBox != null) {
      await hiveBox.delete(key);
      return;
    }
    _memory[box]?.remove(key);
  }

  /// حذف كل محتوى صندوق.
  static Future<void> clear(String box) async {
    final hiveBox = _box(box);
    if (hiveBox != null) {
      await hiveBox.clear();
      return;
    }
    _memory[box]?.clear();
  }

  /// جميع القيم في صندوق معين.
  static Iterable<dynamic> values(String box) => entries(box).values;

  /// جميع المفاتيح في صندوق معين.
  static Iterable<dynamic> keys(String box) => entries(box).keys;

  /// خريطة (مفتاح → قيمة) لصندوق معين.
  static Map<dynamic, dynamic> entries(String box) {
    final hiveBox = _box(box);
    if (hiveBox != null) return hiveBox.toMap();
    final mem = _memory[box];
    return mem == null ? <dynamic, dynamic>{} : Map<dynamic, dynamic>.of(mem);
  }

  /// هل المفتاح موجود؟
  static bool exists(String box, dynamic key) => entries(box).containsKey(key);
}
