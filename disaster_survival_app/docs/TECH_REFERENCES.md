# المستودعات المرجعية التقنية

هذا المستند يوثّق المستودعات العشرة التي زُوّدنا بها كـ **مراجع تقنية** أثناء
تصميم ResiliNet، وكيف أثّرت (أو لم تؤثّر) في قرارات المشروع.

> **ملاحظة مهمة:** لم يُضمَّن أي من هذه المستودعات كاعتماد برمجي (Dependency)
> في `pubspec.yaml`. المشروع Flutter/Dart بالكامل، وهذه المستودعات استُخدمت
> للاطلاع على الأنماط المعمارية، وأدوات بناء المحتوى، واتجاهات التشغيل المحلي
> للنماذج اللغوية. كل اعتماد فعلي مذكور في `README.md` مع سببه.

---

## 1. الجدول المرجعي

| # | المستودع | الرابط | الترخيص | ما استفدناه منه |
|---|---|---|---|---|
| 1 | `public-apis/public-apis` | https://github.com/public-apis/public-apis | MIT | مرجع لتصنيف مصادر البيانات العامة (طقس، إغاثة، خرائط). استُخدم عند تصميم نموذج `NewsBulletin` وحقول المصدر/الخطورة، ولفهم أي البيانات يمكن حزمها أوفلاين بدل الاعتماد على API حي. |
| 2 | `punkpeye/awesome-mcp-servers` | https://github.com/punkpeye/awesome-mcp-servers | MIT | مرجع لخادم MCP محتمل يربط ResiliNet بأدوات خارجية عند توفر اتصال. لم يُنفَّذ؛ لكنه شكّل واجهة `attachBroadcast` وفصل طبقة النقل عن منطق DTN ليسهل ربط قنوات أخرى مستقبلاً. |
| 3 | `nexu-io/open-design` | https://github.com/nexu-io/open-design | Apache-2.0 | مثال على تطبيق **Local-first** يدعم OpenCode عبر MCP. أكّد قرار: كل البيانات محلية، والهوية والتوقيع على الجهاز، والمزامنة اختيارية. |
| 4 | `Shubhamsaboo/awesome-llm-apps` | https://github.com/Shubhamsaboo/awesome-llm-apps | Apache-2.0 | أنماط بناء مساعدين يعملون محلياً (RAG، أدوات، ذاكرة). استُخدم في تصميم محرك الفرز كـ **قواعد حتمية** الآن، مع واجهة `OfflineTriageEngine.evaluate` القابلة لإضافة نموذج لغوي لاحقاً. |
| 5 | `sindresorhus/awesome` | https://github.com/sindresorhus/awesome | CC0-1.0 | منهجية تنظيم القوائم والتصنيفات. طُبّقت في `default_equipment.dart` (7 تصنيفات كوارث، 3 مستويات أولوية) وفي تنظيم وثائق `docs/`. |
| 6 | `D4Vinci/Scrapling` | https://github.com/D4Vinci/Scrapling | BSD-3-Clause | أداة استخراج بيانات مرنة. مرجع لطريقة **بناء** قاعدة التجهيزات والأدلة الطبية من مصادر موثوقة وقت التطوير، ثم حزمها أوفلاين. لا تعمل داخل التطبيق. |
| 7 | `ripienaar/free-for-dev` | https://github.com/ripienaar/free-for-dev | MIT | مرجع لخدمات مجانية أثناء التطوير (CI، استضافة، مراقبة). ذكّرنا بتجنّب أي اعتماد على خدمة سحابية في وقت التشغيل، لأن التطبيق يجب أن يعمل بعد انقطاعها. |
| 8 | `ollama/ollama` | https://github.com/ollama/ollama | MIT | نموذج تشغيل LLM محلي على الحاسوب. ألهم فكرة «مساعد بقاء محلي»؛ لكن Ollama لا يعمل على الهاتف، لذا اقتصر التنفيذ الحالي على محرك قواعد خفيف، مع توثيق خيار llama.cpp/GGUF كخطوة تالية. |
| 9 | `langflow-ai/langflow` | https://github.com/langflow-ai/langflow | MIT | أداة بناء تدفقات مرئية. استُخدمت مفاهيمها في رسم شجرة START قبل تحويلها إلى `if/else` صريحة في `offline_triage_engine.dart` (سهولة المراجعة الطبية والاختبار). |
| 10 | `All-Hands-AI/OpenHands` | https://github.com/All-Hands-AI/OpenHands | MIT | مرجع لسير عمل الوكلاء البرمجيين وتقسيم المهام. أثّر في تنظيم هذا التسليم: طبقات مستقلة (core/network, features/*/services, presentation) قابلة للاختبار منفصلة. |

---

## 2. كيف تحوّلت المراجع إلى قرارات هندسية

| القرار في ResiliNet | المرجع/السبب |
|---|---|
| **Offline-first بالكامل** — لا سيرفر، لا حساب، لا API حي | open-design + free-for-dev |
| **فصل النقل عن منطق الرسائل** (`attachBroadcast`) | awesome-mcp-servers + OpenHands (واجهات قابلة للاستبدال) |
| **توقيع Ed25519 أوفلاين بدل PKI مركزي** | open-design (Local-first) + متطلبات المواصفة |
| **محرك فرز قواعدي قابل للاختبار** بدل LLM في النسخة الأولى | awesome-llm-apps + langflow (نماذج قابلة للتحقق) |
| **قاعدة تجهيزات مصنّفة ومحزومة** | awesome + Scrapling (بناء المحتوى) |
| **عدم ربط التطبيق بأي خدمة سحابية** | free-for-dev |
| **خارطة طريق LLM محلي** | ollama + awesome-llm-apps |

---

## 3. ما لم نتبنَّه صراحةً

- **MCP runtime:** لا يوجد خادم MCP داخل التطبيق. أضفناه كخطة مستقبلية فقط،
  لأن MCP يفترض مضيفاً/عميلاً يعمل عادة على حاسوب وليس هاتفاً معزولاً.
- **Scrapling / Langflow / Ollama:** أدوات تطوير على الحاسوب، لا كود يُشحن
  مع APK. الاعتماد عليها وقت التشغيل يناقض شرط العمل بلا إنترنت.
- **Wi-Fi Direct:** رغم وروده في المواصفة، نُفِّذ BLE فقط. إضافة Wi-Fi Direct
  تتطلب قناة أصلية Android وإدارة مجموعة P2P، وتُركت كعمل مستقبلي موثّق.
- **FM-RDS حقيقي:** بروتوكول التجميع والتفكيك جاهز ومختبَر، لكن العتاد
  (شريحة RDS أو دونجل SDR) غير متاح في بيئة التطوير.

---

## 4. مراجع الحزم الفعلية

هذه هي المراجع التي اعتمد عليها الكود فعلياً (وليست مستودعات GitHub):

| الحزمة | لماذا |
|---|---|
| `flutter_riverpod` 3.x | حالة تفاعلية بلا `setState` منتشر، وStreamProvider لتيارات DTN/RDS |
| `hive` / `hive_flutter` | تخزين مفتاح/قيمة سريع ومتوافق مع كل المنصات بلا SQL |
| `flutter_blue_plus` | الدور Central في BLE (مسح/اتصال/كتابة) مع دعم Windows أيضاً |
| `flutter_ble_peripheral` | الدور Peripheral + خادم GATT (إعلان حقيقي، لا محاكاة فقط) |
| `cryptography` | Ed25519 وSHA-256 في Dart خالص |
| `sensors_plus` | تدفقات المستشعرات مع مهلة اكتشاف |
| `geolocator` | خدمة الموقع وإحداثيات SOS |
| `battery_plus` | مستوى البطارية ووضع التوفير |
| `permission_handler` | طلب صلاحيات Android 12+ وiOS |
| `flutter_localizations` | تعريب Material وRTL |

---

## 5. بيئة التطوير

- **Flutter 3.47.7 / Dart 3.13.5**
- **OpenCode** — وكيل التطوير الذي نفّذ هذا المشروع.
- **Android SDK 37** (مطلوب من `permission_handler 13`) + Build Tools 36.
- اختبار البناء: `flutter analyze` نظيف، `flutter test` 11/11،
  و`flutter build apk --debug` ينتج APK ناجحاً.

---

## 6. إخلاء مسؤولية

هذه المستودعات مذكورة كمراجع تعليمية/هندسية. أسماءها وتراخيصها مملوكة
لأصحابها. قبل إعادة استخدام أي كود منها، راجع ملف الترخيص في كل مستودع.
كذلك فإن إرشادات الفرز الطبي في هذا التطبيق **لا تغني عن الرعاية الطبية
المهنية**، ويجب مراجعتها من جهة طبية قبل أي نشر ميداني.
