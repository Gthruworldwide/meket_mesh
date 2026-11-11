# ResiliNet — منظومة الإنقاذ اللامركزي في الكوارث

تطبيق Flutter يعمل **أوفلاين بالكامل** لبناء شبكة مش لامركزية عبر البلوتوث،
وبث نداءات الاستغاثة والأنباء بحزم DTN (Store-and-Forward)، مع التحقق الرقمي
أوفلاين، وفحص جاهزية العتاد، وقوائم تجهيزات حسب نوع الكارثة، وفرز طبي ميداني.

> **الاسم البرمجي:** `disaster_survival_app` — **المنظومة:** ResiliNet
> **الواجهة:** عربية RTL — **الثيم:** ليلي تكتيكي + Red-Night Mode

---

## 1. الميزات المنفّذة

| الميزة | الوصف | الحالة |
|---|---|---|
| شبكة مش BLE | إعلان خدمة ResiliNet عبر GATT + مسح + اتصال ومزامنة دورية | ✅ حقيقي مع بديل محاكاة |
| حزم DTN | توقيع Ed25519، منع تكرار، TTL، انتهاء 72 ساعة، صندوق وارد/صادر | ✅ |
| PKI أوفلاين | هوية Ed25519 تُولَّد محلياً، Node ID = SHA-256 للمفتاح العام | ✅ |
| مقياس الجاهزية | 5 محاور / 100 نقطة + دور تكتيكي (Gold / Silver / Basic) | ✅ فحوص حقيقية + تقديرات موسومة |
| قوائم التجهيزات | ~40 عنصراً مصنّفاً حسب 7 أنواع كوارث، بحث وتصفية وحفظ محلي | ✅ |
| أنباء أوفلاين | دمج DTN مع FM-RDS (محاكاة بروتوكول RDS)، نشر محلي موقّع | ✅ |
| الفرز الطبي | شجرة START تفاعلية + حاسبة مياه/سعرات + 8 أدلة إسعاف | ✅ |
| نداءات SOS | إنشاء وبث وتوقيع مع إحداثيات اختيارية، عرض الوارد والتحقق | ✅ |
| Red-Night Mode | ثيم أحمر كامل يحافظ على تكيّف العين في الظلام | ✅ |
| Wi-Fi Direct | غير منفّذ (BLE فقط حالياً) | ⏳ |
| FM-RDS / SDR حقيقي | يتطلب عتاد دونجل + قناة أصلية | ⏳ (محاكاة جاهزة) |

---

## 2. الشاشات

1. **الجاهزية** — سكور دائري، الدور التكتيكي، تفصيل النقاط، سجل الفحوص،
   حالة شبكة المش والعقد المجاورة، بث SOS، وتدفق نداءات الاستغاثة.
2. **التجهيزات** — تصفية حسب الكارثة، بحث، تأشير المكتسبات، وحفظ فوري في Hive.
3. **الأنباء** — تدفق موحّد من المش و FM-RDS، تصفية بالخطورة، شارات التحقق
   والتوقيع، ونشر نشرة محلية موقّعة.
4. **الفرز** — فرز START خطوة بخطوة، حاسبة احتياجات البقاء، وأدلة الإسعاف.

---

## 3. البنية

```text
lib/
├── main.dart                          # ProviderScope + RTL + شريط التنقل
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # الثيم الليلي + Red-Night
│   │   └── disaster_types.dart        # 7 أنواع كوارث
│   ├── network/
│   │   ├── mesh_manager.dart          # BLE advertise/scan/sync + إطارات + محاكاة
│   │   └── dtn_packet_handler.dart    # مغلّف DTN + توقيع + صناديق Hive
│   ├── state/app_settings.dart        # Red-Night + Callsign
│   ├── utils/
│   │   ├── local_store.dart           # Hive + بديل في الذاكرة
│   │   └── pki_verifier.dart          # Ed25519 + قائمة الثقة
│   └── widgets/                       # بطاقات وشارات وأزرار مشتركة
├── features/
│   ├── hardware_score/
│   │   ├── models/device_score_model.dart
│   │   ├── services/hardware_assessor.dart
│   │   └── presentation/score_dashboard.dart
│   ├── survival_checklists/
│   │   ├── models/equipment_item.dart
│   │   ├── data/default_equipment.dart
│   │   └── presentation/checklist_screen.dart
│   ├── offgrid_news/
│   │   ├── models/news_bulletin.dart
│   │   ├── services/rds_sdr_listener.dart
│   │   └── presentation/news_screen.dart
│   └── medical_triage/
│       ├── services/offline_triage_engine.dart
│       └── presentation/triage_screen.dart
```

---

## 4. كيف تعمل شبكة المش؟

```text
[جهاز A]                                   [جهاز B]
  │ 1. Advertise: service UUID + "RN:<nodeId>"  │
  │ ──────────────────────────────────────────▶ │
  │                                    2. Scan by service UUID
  │ ◀────────────────────────────────────────── │
  │                                    3. connect (License.nonprofit)
  │                                    4. discoverServices()
  │ ◀──── 5. write DTN frames to RX characteristic ──── │
  │ 6. reassemble → verify signature → dedupe → inbox
  │ 7. queue forwarded envelope (TTL-1, hops+1)
  │ 8. next 18s sync round picks the strongest fresh peer
```

- **الإطارات:** كل كتابة GATT تحمل `[R, N, seq, total, …chunk]` بحمولة 140 بايت
  (≤ 160 بايت إجمالاً) وتُعاد تجميعها مع مهلة 40 ثانية.
- **منع التكرار:** كل `msgId` يُسجَّل في `dtn_seen` قبل التسليم.
- **التمرير:** الحزم المقبولة تُخزَّن في `dtn_outbox` وتُبثّ للعقد الأخرى.
- **الصلاحية:** TTL افتراضي 7 قفزات، وعمر أقصى 72 ساعة.
- **الاكتشاف الذاتي:** معرّف العقدة في بيانات المُصنّع يُستخدم لتجاهل الجهاز نفسه.

### لماذا لا تُرسل الحزم إلا عند وجود عقدة؟
BLE لا يسمح ببث حزم تطبيقية عشوائية؛ لذلك يُعاد استخدام اتصال GATT قصير
(connect → write → disconnect) عند كل دورة مزامنة. هذا هو نمط
Store-and-Forward الفعلي على الهواتف دون تعديل النظام.

---

## 5. التوقيع والتحقق (PKI)

- كل جهاز يولّد زوج مفاتيح **Ed25519** عند أول تشغيل.
- يُخزَّن البذرة (Seed) في Hive باسم `pki_identity`.
- `Node ID = أول 16 حرفاً hex من SHA-256(Public Key)`.
- التوقيع يغطي تمثيلاً قانونياً (Canonical JSON) للمعرّف والنوع والمصدر
  والوقت والحمولة **فقط**؛ لذلك يمكن لكل عقدة تعديل `hops` و`ttl` دون كسر التوقيع.
- قائمة الثقة المحلية (`pki_trust`) تسمح بترقية مصدر إلى «موثوق» بعد تحقق يدوي.
- **تحذير أمني:** البذرة مخزّنة حالياً في Hive غير مشفّر. قبل الإنتاج يجب نقلها
  إلى `flutter_secure_storage` / Android Keystore / Secure Enclave.

---

## 6. مقياس الجاهزية (100 نقطة)

| المحور | الحد الأقصى | كيف يُقاس |
|---|---|---|
| شبكات المش | 30 | إعلان BLE حقيقي (15)، Wi-Fi Direct تقديري (10)، FM-RDS = 0 |
| الذكاء الاصطناعي والذاكرة | 25 | NPU تقديري (15)، RAM تقديري من عدد الأنوية (حتى 10) |
| المستشعرات | 20 | بارومتر (8) + GPS/بوصلة (7) + مقياس تسارع (5) — قراءات فعلية |
| الطاقة | 15 | مستوى البطارية (حتى 10) + وضع التوفير (5) |
| التخزين والتشفير | 10 | مساحة تقديرية (5) + مخزن مفاتيح عتادي (5) |

**الأدوار:** ≥ 85 = `Gold Mesh Hub` — ≥ 60 = `Silver Relay Node` — أقل = `Basic Survival Mode`.

كل فحص يحمل وسم `estimated` إذا لم تكن هناك واجهة نظام عامة لقياسه، ويظهر
ذلك في الواجهة بأيقونة `؟`.

---

## 7. التشغيل

```bash
# المتطلبات: Flutter 3.47+ / Dart 3.13+
cd disaster_survival_app
flutter pub get
flutter run
```

بناء APK:

```bash
flutter build apk --debug
# أو
flutter build apk --release
```

### ملاحظات بناء Android

- `compileSdk = 37` لأن `permission_handler 13` يتطلب API 37.
- `kotlin.incremental=false` في `android/gradle.properties` لتفادي انهيار
  كاش Kotlin عندما يكون Pub Cache على قرص C والمشروع على قرص D (بيئة Windows).
- `minSdk` الافتراضي من Flutter (21+). يفضّل رفعه إلى 23+ لاستقرار BLE.

### صلاحيات Android المضافة

`BLUETOOTH_SCAN` + `BLUETOOTH_ADVERTISE` + `BLUETOOTH_CONNECT` (Android 12+)،
و`BLUETOOTH`/`BLUETOOTH_ADMIN` (≤ 11)، و`ACCESS_FINE_LOCATION` للمسح
وإرفاق إحداثيات SOS. الجهاز يمكنه العمل بدون BLE (محاكاة).

### صلاحيات iOS

`NSBluetoothAlwaysUsageDescription`، `NSBluetoothPeripheralUsageDescription`،
`NSLocationWhenInUseUsageDescription`، وخلفية `bluetooth-central` /
`bluetooth-peripheral`.

> على iOS لا يمكن وضع بيانات المُصنّع في الإعلان؛ يعتمد التطبيق على اسم
> `ResiliNet` وخدمة UUID لاكتشاف العقد، ويستخرج معرّف العقدة من `remoteId`
> عند غياب بيانات المُصنّع.

---

## 8. وضع المحاكاة

إذا لم يتوفر عتاد BLE أو رُفضت الصلاحيات:

- تظهر حالتان: `FM-RDS (محاكاة)` + عقدتان افتراضيتان.
- لا تُولَّد رسائل وهمية في صندوق الوارد ولا تُوقَّع حزم مزيفة.
- زر «إعادة تشغيل البلوتوث» يعيد المحاولة الحقيقية.
- بث FM-RDS يبدأ بعد 4 ثوانٍ ثم كل 22 ثانية بنشرات عربية نموذجية.

---

## 9. الاختبارات

```bash
flutter analyze   # لا توجد ملاحظات
flutter test      # 11 اختباراً ناجحاً
```

تغطي الاختبارات: شجرة START، حاسبة البقاء، بروتوكول RDS، قانونية توقيع DTN،
وحفظ نماذج التجهيزات.

---

## 10. الحزم الأساسية ولماذا

| الحزمة | الاستخدام |
|---|---|
| `flutter_riverpod` | إدارة الحالة (Notifier / FutureProvider / StreamProvider) |
| `hive` + `hive_flutter` | تخزين محلي سريع للصناديق والهوية والإعدادات |
| `flutter_blue_plus` | دور Central: المسح والاتصال والكتابة |
| `flutter_ble_peripheral` | دور Peripheral: الإعلان + خادم GATT |
| `cryptography` | Ed25519 + SHA-256 |
| `sensors_plus` | التسارع/الجيروسكوب/المغناطيسية/البارومتر |
| `geolocator` | خدمة الموقع وإحداثيات SOS |
| `battery_plus` | مستوى الشحن ووضع التوفير |
| `permission_handler` | طلب صلاحيات البلوتوث والموقع |
| `flutter_localizations` | تعريب Material وتفعيل RTL |

> **ترخيص مهم:** `flutter_blue_plus` يتطلب اختيار ترخيص عند الاتصال
> (`License.nonprofit` أو `License.commercial`). هذا المشروع يستخدم
> `License.nonprofit`؛ الاستخدام التجاري يحتاج ترخيصاً مناسباً.

---

## 11. القيود وخطة التطوير

1. **تشفير الحمولة:** التوقيع يثبت المصدر لكنه لا يخفي المحتوى. يُقترح
   X25519 + AES-GCM لاحقاً للرسائل الخاصة.
2. **مخزن مفاتيح آمن:** نقل بذرة Ed25519 من Hive إلى Keystore/Secure Enclave.
3. **Wi-Fi Direct:** إضافة قناة أصلية Android للـ P2P عالي النطاق.
4. **SDR حقيقي:** RTL-SDR عبر USB-OTG + قناة أصلية لفك RDS.
5. **المساحة وRAM وNPU:** إضافة `device_info_plus`/قنوات أصلية لقياسها بدقة.
6. **مزامنة متقدمة:** فهارس موجزة (Bloom filter) لتفادي إعادة إرسال ما يعرفه الطرف الآخر.
7. **الخلفية:** خدمة أمامية دائمة لمزامنة المش عند إغلاق التطبيق.
8. **نموذج محلي:** دمج نموذج لغوي مصغّر للفرز والإرشاد (راجع `docs/TECH_REFERENCES.md`).

---

## 12. الوثائق

- [`docs/PROJECT_SPEC.md`](docs/PROJECT_SPEC.md) — المواصفة العربية الأصلية.
- [`docs/TECH_REFERENCES.md`](docs/TECH_REFERENCES.md) — المستودعات المرجعية
  وكيف أثّرت في اختيارات المشروع.
