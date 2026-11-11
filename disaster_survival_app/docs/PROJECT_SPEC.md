# وثيقة المشروع الهندسية ودليل البناء الموجه لـ OpenCode (AI Agent Prompt Specs)
**اسم المشروع المستهدف:** ResiliNet / منظومة الإنقاذ والتنبيه اللامركزي في حالات الكوارث الشاملة.
**إطار العمل (Framework):** Flutter (Dart) - Cross-Platform (Android & iOS).
**بيئة التطوير والتنفيذ:** OpenCode (AI Development Orchestrator) + Android Studio (SDK, Native Tools & Emulators).

---

## 1. الرؤية الفنية والوظائف الحيوية (Core Capabilities)

1. **العمل التام بدون شبكة (Offline-First Approach):**
   * الاعتماد الكامل على العمليات المحلية دون الحاجة لاتصال بسيرفر مركزي أو إنترنت أثناء الكارثة.
2. **شبكة المش المتشابكة اللامركزية (BLE & Wi-Fi Direct Mesh Network):**
   * نقل نداءات الاستغاثة (SOS)، التنبيهات، والأنباء عبر قفزات الإشارة (Hops) بين الهواتف القريبة.
3. **تداول الأنباء والتحقق الرقمي أوفلاين (Anti-Misinformation Off-Grid News):**
   * استقبال الأنباء عبر إشارات FM-RDS / SDR وتقنية التمرير والتخزين (DTN / Store-and-Forward) مع التحقق من الهوية عبر التوقيع الرقمي (PKI).
4. **مقياس جاهزية وكفاءة الجهاز (Device Disaster Readiness Score - 100 Points):**
   * خوارزمية تفحص عتاد الهاتف ومستشعراته لتحديد دوره التكتيكي (Master Node, Relay Node, or Power-Saver Receiver).
5. **مساعد البناء والفرز الطبي التفاعلي (Offline AI Triage & Survival Assistant):**
   * نماذج لغوية مصغرة ومحرك قواعد يشتغل أوفلاين لتقديم إرشادات البقاء والإسعاف الفوري وحساب السعرات والمياه.
6. **قائمة المشتريات والتجهيزات الديناميكية حسب الكارثة (Dynamic Survival Checklist):**
   * قاعدة بيانات أوفلاين تضم أجهزة الطوارئ ومستلزمات البقاء وتصنيفها حسب الكارثة المحددة (نووي، سيول، زلازل، براكين، انقطاع كهرباء/EMP).

---

## 2. شجيرة الملفات والهيكلية الهندسية (Project File Tree)

```text
lib/
├── main.dart                          # نقطة الانطلاق الرئيسية وتثبيت الخدمات
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # الألوان (يدعم الوضع الأحمر التكتيكي Red-Night Mode)
│   │   └── disaster_types.dart        # تعريف أنواع الكوارث والأخطار
│   ├── network/
│   │   ├── mesh_manager.dart          # إدارة البلوتوث وWi-Fi Direct للمش
│   │   └── dtn_packet_handler.dart    # حزم بيانات التمرير والتخزين والتشفير
│   └── utils/
│       └── pki_verifier.dart          # التوقيع الرقمي للتحقق من المصداقية أوفلاين
├── features/
│   ├── hardware_score/
│   │   ├── models/
│   │   │   └── device_score_model.dart# نموذج بيانات سكور الجهاز
│   │   ├── services/
│   │   │   └── hardware_assessor.dart # خوارزمية تقييم العتاد والمستشعرات (Score 100)
│   │   └── presentation/
│   │       └── score_dashboard.dart   # شاشة عرض جاهزية الهاتف ودوره التكتيكي
│   ├── survival_checklists/
│   │   ├── models/
│   │   │   └── equipment_item.dart    # نموذج الأجهزة والمشتريات
│   │   ├── data/
│   │   │   └── default_equipment.dart # قاعدة البيانات الأولية لأجهزة الطوارئ
│   │   └── presentation/
│   │       └── checklist_screen.dart  # واجهة تصفية المشتريات حسب الكارثة
│   ├── offgrid_news/
│   │   ├── models/
│   │   │   └── news_bulletin.dart     # حزمة الخبر التكتيكي
│   │   └── services/
│   │       └── rds_sdr_listener.dart  # استقبال البيانات عبر موجات FM-RDS / SDR
│   └── medical_triage/
│       └── services/
│           └── offline_triage_engine.dart # محرك الفرز الطبي والإسعافات أوفلاين
```

---

## 3. الشفرات البرمجية الأساسية (Core Code Implementations)

### أ. نموذج وقاعدة بيانات المعدات والتجهيزات (`lib/features/survival_checklists/models/equipment_item.dart`)

```dart
import 'package:flutter/foundation.dart';

enum DisasterCategory {
  nuclear,
  flood,
  earthquake,
  volcano,
  powerEMP,
  commsOutage,
  waterContamination,
}

class EquipmentItem {
  final String id;
  final String name;
  final String category;
  final String description;
  final int priorityLevel; // 1: حرج جداً (72 ساعة), 2: مهم, 3: استدامة
  final List<DisasterCategory> applicableDisasters;
  bool isAcquired;

  EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priorityLevel,
    required this.applicableDisasters,
    this.isAcquired = false,
  });
}
```

### ب. قاعدة بيانات الأجهزة التكتيكية المسبقة (`lib/features/survival_checklists/data/default_equipment.dart`)

```dart
import '../models/equipment_item.dart';

final List<EquipmentItem> defaultDisasterEquipment = [
  // اتصالات وطاقة
  EquipmentItem(
    id: 'eq_lora',
    name: 'أجهزة اتصال مش (Meshtastic / LoRa Node)',
    category: 'الاتصالات اللاسلكية',
    description: 'يسمح بنقل الرسائل والمواقع الإحداثية بدون شبكة إنترنت لمسافة عدة كيلومترات.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.commsOutage, DisasterCategory.nuclear, DisasterCategory.earthquake],
  ),
  EquipmentItem(
    id: 'eq_faraday',
    name: 'حقائب/صناديق فاراداي (Faraday Bags)',
    category: 'حماية الإلكترونيات',
    description: 'تحمي الأجهزة الإلكترونية وعداد الإشعاع من الاحتراق جراء النبضات الكهرومغناطيسية (EMP).',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.powerEMP, DisasterCategory.nuclear],
  ),
  EquipmentItem(
    id: 'eq_sw_radio',
    name: 'راديو طوارئ هندل/شمسي (Hand-Crank SW/FM Radio)',
    category: 'استقبال الأنباء',
    description: 'يستقبل الموجات القصيرة الدولية والأنباء المدمجة في موجات FM-RDS بدون إنترنت.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.commsOutage, DisasterCategory.nuclear, DisasterCategory.flood, DisasterCategory.powerEMP],
  ),

  // الأخطار النووية والتلوث
  EquipmentItem(
    id: 'eq_geiger',
    name: 'عداد جايجر الرقمي (Geiger Counter)',
    category: 'أجهزة قياس البيئة',
    description: 'يقيس مستويات الجرعة الإشعاعية الحية لحساب وقت البقاء في الملاجئ.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.nuclear],
  ),
  EquipmentItem(
    id: 'eq_cbrn_mask',
    name: 'قناع غاز كرتوشي شامل (CBRN Respirator)',
    category: 'الحماية التنفسية',
    description: 'يعزل الغبار الإشعاعي الذري والغازات السامة والأبخرة الكيميائية.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.nuclear, DisasterCategory.volcano],
  ),

  // تنقية المياه والمؤن
  EquipmentItem(
    id: 'eq_water_filter',
    name: 'فلتر مياه دقيق محمول (Portable Micro-Filter)',
    category: 'المياه والصحة',
    description: 'يزيل البكتيريا والجسيمات الدقيقة من المياه السطحية والملوثة.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.waterContamination, DisasterCategory.flood, DisasterCategory.earthquake],
  ),
  EquipmentItem(
    id: 'eq_water_tablets',
    name: 'أقراص تطهير المياه (Chlorine Dioxide Tablets)',
    category: 'المياه والصحة',
    description: 'تعقيم المياه والقضاء على الفيروسات والميكروبات قبل الشرب.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.waterContamination, DisasterCategory.flood],
  ),
];
```

### ج. خوارزمية حساب جاهزية الهاتف - Score 100 (`lib/features/hardware_score/services/hardware_assessor.dart`)

```dart
import 'dart:async';
import 'package:flutter/services.dart';

class HardwareAssessor {
  /// تحسب سكور جاهزية الجهاز الكلية من 100 درجة بناءً على المستشعرات والعتاد أوفلاين
  Future<Map<String, dynamic>> calculateDisasterScore() async {
    int meshScore = 0;     // Max 30
    int aiScore = 0;       // Max 25
    int sensorScore = 0;   // Max 20
    int batteryScore = 0;  // Max 15
    int storageScore = 0;  // Max 10

    // 1. فحص إمكانيات شبكات المش (Max 30)
    bool hasBleAdvertising = await _checkBleAdvertisingSupport();
    bool hasWifiDirect = await _checkWifiDirectSupport();
    bool hasRadioSupport = await _checkFmRdsSupport();

    if (hasBleAdvertising) meshScore += 15;
    if (hasWifiDirect) meshScore += 10;
    if (hasRadioSupport) meshScore += 5;

    // 2. فحص قدرات الذكاء الاصطناعي والذاكرة (Max 25)
    int ramSizeGB = await _getDeviceRamGB();
    bool hasNpu = await _checkNpuSupport();

    if (hasNpu) aiScore += 15;
    if (ramSizeGB >= 8) {
      aiScore += 10;
    } else if (ramSizeGB >= 4) {
      aiScore += 5;
    } else {
      aiScore += 2;
    }

    // 3. فحص المستشعرات البيئية (Max 20)
    bool hasBarometer = await _checkSensorAvailability('barometer');
    bool hasGpsCompass = await _checkSensorAvailability('location_compass');
    bool hasAccelerometer = await _checkSensorAvailability('accelerometer');

    if (hasBarometer) sensorScore += 8; // ورصد الموجات الصدمية
    if (hasGpsCompass) sensorScore += 7;
    if (hasAccelerometer) sensorScore += 5;

    // 4. فحص إدارة الطاقة وصحة البطارية (Max 15)
    int batteryLevel = await _getBatteryLevel();
    bool supportsUltraPowerSave = await _checkPowerSaveSupport();

    if (batteryLevel > 80) {
      batteryScore += 10;
    } else if (batteryLevel > 40) {
      batteryScore += 6;
    } else {
      batteryScore += 2;
    }
    if (supportsUltraPowerSave) batteryScore += 5;

    // 5. فحص التخزين المتاح والتشفير (Max 10)
    double freeStorageGB = await _getFreeStorageGB();
    bool hasHardwareKeystore = await _checkHardwareKeystore();

    if (freeStorageGB >= 2.0) storageScore += 5;
    if (hasHardwareKeystore) storageScore += 5;

    int totalScore = meshScore + aiScore + sensorScore + batteryScore + storageScore;

    // تحديد الدور التكتيكي للجهاز
    String tacticalRole;
    if (totalScore >= 85) {
      tacticalRole = 'Gold Mesh Hub (عقدة ذهبية رئيسية)';
    } else if (totalScore >= 60) {
      tacticalRole = 'Silver Relay Node (عقدة متوسطة لتمرير الرسائل)';
    } else {
      tacticalRole = 'Basic Survival Mode (جهاز استقبال وتوفير طاقة)';
    }

    return {
      'totalScore': totalScore,
      'tacticalRole': tacticalRole,
      'breakdown': {
        'meshScore': meshScore,
        'aiScore': aiScore,
        'sensorScore': sensorScore,
        'batteryScore': batteryScore,
        'storageScore': storageScore,
      }
    };
  }

  // ميثودات وهمية تحاكي استدعاء الـ Native Plugins من النظام
  Future<bool> _checkBleAdvertisingSupport() async => true;
  Future<bool> _checkWifiDirectSupport() async => true;
  Future<bool> _checkFmRdsSupport() async => false;
  Future<int> _getDeviceRamGB() async => 8;
  Future<bool> _checkNpuSupport() async => true;
  Future<bool> _checkSensorAvailability(String type) async => true;
  Future<int> _getBatteryLevel() async => 90;
  Future<bool> _checkPowerSaveSupport() async => true;
  Future<double> _getFreeStorageGB() async => 12.5;
  Future<bool> _checkHardwareKeystore() async => true;
}
```

---

## 4. تعليمات وأوامر المباشرة لـ OpenCode (Execution Script)

للبدء فوراً داخل OpenCode، يُنفذ التتابع التالي:

1. **إنشاء مشروع Flutter:**
   ```bash
   flutter create --org com.resilienet disaster_survival_app
   cd disaster_survival_app
   ```
2. **إضافة الحزم الأساسية في `pubspec.yaml`:**
   * `flutter_riverpod` (لإدارة الحالة والتطوير السريع).
   * `hive` & `hive_flutter` (لقواعد البيانات السريعة والمشفرة أوفلاين).
   * `flutter_blue_plus` (لربط تقنيات البلوتوث وتفاعل شبكة المش).
   * `sensors_plus` & `geolocator` (للحصول على قراءات المستشعرات والبارومتر).
3. **التوجيه المباشر لـ OpenCode Agent:**
   > "قم بقراءة ملف `disaster_app_architecture_and_spec.md` وابدأ بتنفيذ الهيكلية البرمجية بداخل مجلد `lib/` وفقاً لشجيرة الملفات المحددة، واكتمال كود خوارزمية فحص العتاد وقاعدة بيانات التجهيزات أوفلاين."