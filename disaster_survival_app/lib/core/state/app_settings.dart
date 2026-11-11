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
///
/// يُحفظ محلياً ويُحدَّث عند تغييره من نموذج بث الاستغاثة.
class CallsignNotifier extends Notifier<String> {
  @override
  String build() =>
      LocalStore.get<String>(LocalStore.settingsBox, 'callsign') ??
      'مستجيب محلي';

  void set(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == state) return;
    state = trimmed;
    LocalStore.write(LocalStore.settingsBox, 'callsign', trimmed);
  }
}

final callsignProvider = NotifierProvider<CallsignNotifier, String>(
  CallsignNotifier.new,
);
