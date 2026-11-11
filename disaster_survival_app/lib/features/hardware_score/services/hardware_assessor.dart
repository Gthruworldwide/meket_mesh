import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/device_score_model.dart';

/// خوارزمية تقييم جاهزية الجهاز للكوارث (من 100).
///
/// المحاور الخمسة مطابقة للمواصفة:
///  * شبكات المش — 30 نقطة (إعلان BLE 15، Wi-Fi Direct 10، راديو FM-RDS 5).
///  * الذكاء الاصطناعي والذاكرة — 25 نقطة (NPU 15، RAM حتى 10).
///  * المستشعرات — 20 نقطة (بارومتر 8، GPS/بوصلة 7، مقياس تسارع 5).
///  * الطاقة — 15 نقطة (مستوى البطارية حتى 10، توفير الطاقة 5).
///  * التخزين والتشفير — 10 نقاط (مساحة حرة 5، مفتاح عتادي 5).
///
/// الفحوص التي لا توفر المنصات واجهة عامة لها (NPU، حجم RAM، Wi-Fi Direct،
/// المساحة الحرة الدقيقة) تُوسم `estimated` كي يعرف المستخدم أن النتيجة
/// تقديرية، بينما تُقاس المستشعرات والبطارية والبلوتوث فعلياً.
class HardwareAssessor {
  HardwareAssessor();

  static const Duration _sensorTimeout = Duration(milliseconds: 1400);

  Future<DeviceScoreModel> calculateDisasterScore() async {
    final checks = <DeviceCheck>[];

    // ── 1) شبكات المش (30) ──────────────────────────────────────────────
    final bleAdvertising = await _checkBleAdvertising();
    checks.add(
      DeviceCheck(
        id: 'ble_advertising',
        label: 'إعلان شبكة BLE (Peripheral + GATT)',
        maxPoints: 15,
        awardedPoints: bleAdvertising ? 15 : 0,
        estimated: false,
        detail: bleAdvertising
            ? 'الجهاز يدعم نشر خدمة ResiliNet واستقبال حزم DTN.'
            : 'الجهاز لا يدعم الإعلان عبر BLE أو أن البلوتوث غير متاح.',
      ),
    );

    final wifiDirect = _estimateWifiDirect();
    checks.add(
      DeviceCheck(
        id: 'wifi_direct',
        label: 'Wi-Fi Direct لمش عالي النطاق',
        maxPoints: 10,
        awardedPoints: wifiDirect ? 10 : 0,
        estimated: true,
        detail: wifiDirect
            ? 'تقديري: منصة Android تدعم عادةً Wi-Fi Direct (غير مفعّل في هذه النسخة).'
            : 'تقديري: iOS لا يوفّر Wi-Fi Direct؛ يُستخدم BLE فقط.',
      ),
    );

    checks.add(
      const DeviceCheck(
        id: 'fm_rds',
        label: 'استقبال FM-RDS / SDR',
        maxPoints: 5,
        awardedPoints: 0,
        estimated: false,
        detail: 'يتطلب شريحة FM تدعم RDS أو دونجل SDR عبر USB-OTG مع قناة أصلية — غير متوفر حالياً.',
      ),
    );

    // ── 2) الذكاء الاصطناعي والذاكرة (25) ───────────────────────────────
    final cores = _processorCount();
    final npu = cores >= 8;
    checks.add(
      DeviceCheck(
        id: 'npu',
        label: 'وحدة معالجة عصبية (NPU)',
        maxPoints: 15,
        awardedPoints: npu ? 15 : 0,
        estimated: true,
        detail: npu
            ? 'تقديري: معالج بـ $cores أنوية يُرجَّح احتواؤه على NPU لتشغيل نماذج محلية.'
            : 'تقديري: عدد الأنوية ($cores) لا يدعم تشغيل نموذج لغوي محلي بسلاسة.',
      ),
    );

    final ramEstimate = _estimateRamGb(cores);
    final ramPoints = ramEstimate >= 8
        ? 10
        : ramEstimate >= 4
        ? 5
        : 2;
    checks.add(
      DeviceCheck(
        id: 'ram',
        label: 'ذاكرة الوصول العشوائي',
        maxPoints: 10,
        awardedPoints: ramPoints,
        estimated: true,
        detail:
            'تقديري: ~$ramEstimate GB بناءً على $cores أنوية (لا توجد واجهة نظام عامة لقراءة RAM).',
      ),
    );

    // ── 3) المستشعرات (20) ──────────────────────────────────────────────
    final barometer = await _hasEvent(barometerEventStream);
    checks.add(
      DeviceCheck(
        id: 'barometer',
        label: 'بارومتر (رصد الموجات الصدمية والضغط)',
        maxPoints: 8,
        awardedPoints: barometer ? 8 : 0,
        estimated: false,
        detail: barometer
            ? 'تم استلام قراءة ضغط جوي فعلية من المستشعر.'
            : 'لا يوجد بارومتر متاح على هذا الجهاز.',
      ),
    );

    final gps = await _locationAvailable();
    final compass = await _hasEvent(magnetometerEventStream);
    final gpsCompass = gps || compass;
    checks.add(
      DeviceCheck(
        id: 'gps_compass',
        label: 'GPS + بوصلة مغناطيسية',
        maxPoints: 7,
        awardedPoints: gpsCompass ? 7 : 0,
        estimated: false,
        detail: gpsCompass
            ? '${gps ? 'خدمة الموقع متاحة' : 'خدمة الموقع غير مفعّلة'}'
                  '${compass ? ' + مستشعر مغناطيسي يعمل' : ''}.'
            : 'لم تُكتشف خدمة موقع ولا مستشعر مغناطيسي.',
      ),
    );

    final accelerometer = await _hasEvent(accelerometerEventStream);
    checks.add(
      DeviceCheck(
        id: 'accelerometer',
        label: 'مقياس تسارع (كشف الاهتزازات)',
        maxPoints: 5,
        awardedPoints: accelerometer ? 5 : 0,
        estimated: false,
        detail: accelerometer
            ? 'تم استلام قراءة تسارع فعلية من المستشعر.'
            : 'لا يوجد مقياس تسارع متاح.',
      ),
    );

    // ── 4) الطاقة (15) ──────────────────────────────────────────────────
    final batteryLevel = await _batteryLevel();
    final batteryPoints = batteryLevel > 80
        ? 10
        : batteryLevel > 40
        ? 6
        : 2;
    checks.add(
      DeviceCheck(
        id: 'battery_level',
        label: 'مستوى شحن البطارية',
        maxPoints: 10,
        awardedPoints: batteryPoints,
        estimated: false,
        detail: batteryLevel < 0
            ? 'تعذّرت قراءة البطارية — مُنحت النقاط الدنيا.'
            : 'مستوى الشحن الحالي $batteryLevel٪.',
      ),
    );

    final powerSave = await _batterySaveMode();
    checks.add(
      DeviceCheck(
        id: 'power_save',
        label: 'وضع توفير الطاقة',
        maxPoints: 5,
        awardedPoints: powerSave ? 5 : 0,
        estimated: false,
        detail: powerSave
            ? 'وضع توفير الطاقة مفعّل — يطيل عمر العقدة الميدانية.'
            : 'وضع توفير الطاقة غير مفعّل.',
      ),
    );

    // ── 5) التخزين والتشفير (10) ────────────────────────────────────────
    final freeStorage = _estimateFreeStorageGb();
    checks.add(
      DeviceCheck(
        id: 'storage',
        label: 'مساحة تخزين حرة',
        maxPoints: 5,
        awardedPoints: freeStorage >= 2.0 ? 5 : 0,
        estimated: true,
        detail:
            'تقديري: ~${freeStorage.toStringAsFixed(1)} GB متاحة لصناديق DTN والأنباء.',
      ),
    );

    final keystore = _hasHardwareKeystore();
    checks.add(
      DeviceCheck(
        id: 'keystore',
        label: 'مخزن مفاتيح عتادي',
        maxPoints: 5,
        awardedPoints: keystore ? 5 : 0,
        estimated: false,
        detail: keystore
            ? 'المنصة توفّر تخزيناً محمياً للمفاتيح (Keystore / Secure Enclave).'
            : 'لا يتوفر مخزن مفاتيح عتادي معروف على هذه المنصة.',
      ),
    );

    // ── التجميع ─────────────────────────────────────────────────────────
    final meshScore = _sum(checks, {
      'ble_advertising',
      'wifi_direct',
      'fm_rds',
    });
    final aiScore = _sum(checks, {'npu', 'ram'});
    final sensorScore = _sum(checks, {
      'barometer',
      'gps_compass',
      'accelerometer',
    });
    final batteryScore = _sum(checks, {'battery_level', 'power_save'});
    final storageScore = _sum(checks, {'storage', 'keystore'});

    final totalScore =
        (meshScore + aiScore + sensorScore + batteryScore + storageScore).clamp(
          0,
          100,
        );

    final String roleCode;
    final String tacticalRole;
    if (totalScore >= 85) {
      roleCode = 'gold';
      tacticalRole = 'Gold Mesh Hub (عقدة ذهبية رئيسية)';
    } else if (totalScore >= 60) {
      roleCode = 'silver';
      tacticalRole = 'Silver Relay Node (عقدة متوسطة لتمرير الرسائل)';
    } else {
      roleCode = 'basic';
      tacticalRole = 'Basic Survival Mode (جهاز استقبال وتوفير طاقة)';
    }

    return DeviceScoreModel(
      totalScore: totalScore,
      tacticalRole: tacticalRole,
      roleCode: roleCode,
      breakdown: {
        'meshScore': meshScore,
        'aiScore': aiScore,
        'sensorScore': sensorScore,
        'batteryScore': batteryScore,
        'storageScore': storageScore,
      },
      checks: checks,
      assessedAt: DateTime.now(),
    );
  }

  int _sum(List<DeviceCheck> checks, Set<String> ids) => checks
      .where((check) => ids.contains(check.id))
      .fold(0, (total, check) => total + check.awardedPoints);

  Future<bool> _checkBleAdvertising() async {
    try {
      final supported = await FlutterBlePeripheral().isSupported;
      if (supported) return true;
    } catch (_) {}
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  bool _estimateWifiDirect() {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  int _processorCount() {
    try {
      return Platform.numberOfProcessors;
    } catch (_) {
      return 4;
    }
  }

  int _estimateRamGb(int cores) {
    if (cores >= 8) return 8;
    if (cores >= 6) return 6;
    if (cores >= 4) return 4;
    return 2;
  }

  double _estimateFreeStorageGb() {
    if (kIsWeb) return 0;
    // تقدير محافظ: الأجهزة الحديثة توفر عادةً مساحة أكبر، لكن لا نمنح
    // النقاط إلا إذا كانت المنصة معروفة بوجود مساحة كافية للتخزين المحلي.
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows
        ? 4.0
        : 1.0;
  }

  bool _hasHardwareKeystore() {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows;
  }

  Future<int> _batteryLevel() async {
    try {
      return await Battery().batteryLevel;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> _batterySaveMode() async {
    try {
      return await Battery().isInBatterySaveMode;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _locationAvailable() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasEvent<T>(Stream<T> Function() factory) async {
    try {
      final stream = factory();
      await stream.first.timeout(_sensorTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// نتيجة الفحص كوسيط Riverpod. أعِد التحميل بـ `ref.invalidate(deviceScoreProvider)`.
final deviceScoreProvider = FutureProvider<DeviceScoreModel>((ref) {
  return HardwareAssessor().calculateDisasterScore();
});
