import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/local_store.dart';

/// حالة الوضع الأحمر التكتيكي (Red-Night Mode).
///
/// تُحفظ القيمة محلياً حتى تستعيد الواجهة نمط الرؤية الليلية بعد إعادة التشغيل.
class RedNightNotifier extends Notifier<bool> {
  @override
  bool build() =>
      LocalStore.get<bool>(LocalStore.settingsBox, 'red_night') ?? false;

  void toggle() {
    final next = !state;
    state = next;
    LocalStore.write(LocalStore.settingsBox, 'red_night', next);
  }
}

final redNightProvider = NotifierProvider<RedNightNotifier, bool>(
  RedNightNotifier.new,
);

/// اسم النداء المحلي (Callsign) المستخدم في رسائل الاستغاثة.
final callsignProvider = Provider<String>((ref) {
  return LocalStore.get<String>(LocalStore.settingsBox, 'callsign') ??
      'مستجيب محلي';
});
