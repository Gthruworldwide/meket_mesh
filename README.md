# ResiliNet / Meket Mesh — منظومة الإنقاذ والتنبيه اللامركزي في الكوارث

> **المستودع:** `Gthruworldwide/meket_mesh`  
> **الاسم البرمجي:** `disaster_survival_app` (حزمة `com.resilienet.disaster_survival_app`)  
> **الواجهة:** عربية (RTL) — **الثيم:** ليلي تكتيكي + Red-Night Mode  
> **الترخيص:** MIT

تطبيق Flutter يعمل **أوفلاين بالكامل** (بدون إنترنت/5G/Wi-Fi/Radio) لبناء شبكة مش لامركزية عبر Bluetooth LE،
مع بث نداءات الاستغاثة (SOS) والأنباء (DTN / Store-and-Forward)، والتحقق الرقمي أوفلاين (Ed25519 PKI)،
وفحص جاهزية عتاد الجهاز، وقوائم تجهيزات حسب نوع الكارثة، وفرز طبي ميداني (START).

## الميزات (5 محركات)

| # | المحرك | الحالة |
|---|---|---|
| 1 | **جاهزية الجهاز** — 5 محاور / 100 نقطة + دور تكتيكي (Gold Mesh Hub / Silver Relay Node / Basic Survival) | ✅ فحوص حقيقية + تقديرات موسومة |
| 2 | **قوائم التجهيزات** — ~40 عنصرًا مصنّفاً حسب 7 أنواع كوارث، بحث/تصفية/حفظ في Hive | ✅ |
| 3 | **أنباء أوفلاين** — دمج DTN مع FM-RDS (محاكاة بروتوكول RDS)، نشر محلي موقّع | ✅ |
| 4 | **الفرز الطبي** — شجرة START + حاسبة مياه/سعرات + 8 أدلة إسعاف | ✅ |
| 5 | **شبكة المش + SOS** — إعلان خدمة ResiliNet عبر GATT، مسح، مزامنة دورية، إطارات ≤ 140 B، توقيع، منع تكرار، TTL (72 h)، صندوق وارد/صادر، بث SOS مع موقع اختياري | ✅ حقيقي مع بديل محاكاة |

## البنية

```text
meket_mesh/
├── disaster_survival_app/          # تطبيق Flutter الرئيسي
│   ├── lib/
│   │   ├── core/                   # network, state, utils, widgets
│   │   └── features/               # hardware_score, mesh_network,
│   │                                # offgrid_news, survival_checklists,
│   │                                # medical_triage
│   ├── test/widget_test.dart       # 17 اختباراً
│   ├── android/                    # minSdk 21, compileSdk 37
│   └── README.md                   # وثائق تفصيلية + 4 أقسام
├── docs/                           # PROJECT_SPEC.md, TECH_REFERENCES.md
└── LICENSE                         # MIT
```

## تشغيل المشروع

```bash
cd disaster_survival_app
flutter pub get
flutter run                 # Android / iOS (محاكاة)
flutter analyze             # يجب أن يكون نظيفاً
flutter test               # 17/17
flutter build apk --debug   # ~208 MB (4 ABIs) — استخدم --split-per-abi لتقليل الحجم
```

### متطلبات
- Flutter `3.47.7` / Dart `3.13.5`
- Android SDK (compileSdk 37 — permission_handler 13)
- `flutter_blue_plus 2.3.15` (License.nonprofit — للاستخدام التجاري يلزم ترخيص مدفوع)

## الوثائق

- **[disaster_survival_app/README.md](disaster_survival_app/README.md)** — ميزات منفّذة، شاشات، بنية، كيف تعمل الشبكة، مقياس الجاهزية، ترخيص BLE.
- **[disaster_survival_app/docs/PROJECT_SPEC.md](disaster_survival_app/docs/PROJECT_SPEC.md)** — وثيقة هندسية ومواصفات البناء.
- **[disaster_survival_app/docs/TECH_REFERENCES.md](disaster_survival_app/docs/TECH_REFERENCES.md)** — مراجع تقنية.

## ملاحظات أمنية

- **بذرة Ed25519** مخزّنة حالياً في Hive غير مشفّر (`identityBox`). قبل الإنتاج: نقلها إلى `flutter_secure_storage` / Keystore / Keychain.
- **Bluetooth** (UUID خدمة `6c4f2a10-9b3e-4d6a-8f21-7d5e3c1b0a9f`) مع `manufacturerId 0xFFFF` — بديل المحاكاة متاح عند غياب العتاد/الصلاحيات.
- **Wi-Fi Direct** غير منفّذ (BLE فقط حالياً). **FM-RDS/SDR حقيقي** يتطلب دونجل + قناة أصلية (المحاكاة جاهزة).

## المساهمة

المستودع مفتوح (MIT). PRs مرحب بها — التزم بـ `flutter analyze` نظيف و `flutter test` أخضر قبل أي طلب دمج.

---

Built by **Gthruworldwide** · `nader.adel7777@gmail.com`
