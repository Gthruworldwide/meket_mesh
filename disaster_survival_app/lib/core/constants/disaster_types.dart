import 'package:flutter/material.dart';

/// أنواع الكوارث الشاملة التي تدعمها المنظومة.
///
/// تُستخدم لتصفية التجهيزات، ووسم الأنباء، وتوجيه إرشادات الفرز الطبي.
enum DisasterCategory {
  nuclear,
  flood,
  earthquake,
  volcano,
  powerEMP,
  commsOutage,
  waterContamination,
}

extension DisasterCategoryX on DisasterCategory {
  /// الاسم العربي المعروض في الواجهة.
  String get label {
    switch (this) {
      case DisasterCategory.nuclear:
        return 'نووي / إشعاعي';
      case DisasterCategory.flood:
        return 'سيول وفيضانات';
      case DisasterCategory.earthquake:
        return 'زلازل';
      case DisasterCategory.volcano:
        return 'براكين ورماد';
      case DisasterCategory.powerEMP:
        return 'انقطاع كهرباء / EMP';
      case DisasterCategory.commsOutage:
        return 'انقطاع اتصالات';
      case DisasterCategory.waterContamination:
        return 'تلوث المياه';
    }
  }

  /// رمز تعبيري مختصر للعرض السريع.
  String get emoji {
    switch (this) {
      case DisasterCategory.nuclear:
        return '☢️';
      case DisasterCategory.flood:
        return '🌊';
      case DisasterCategory.earthquake:
        return '🏚️';
      case DisasterCategory.volcano:
        return '🌋';
      case DisasterCategory.powerEMP:
        return '⚡';
      case DisasterCategory.commsOutage:
        return '📡';
      case DisasterCategory.waterContamination:
        return '💧';
    }
  }

  /// لون تعريفي للتصنيف.
  Color get color {
    switch (this) {
      case DisasterCategory.nuclear:
        return const Color(0xFFFFB300);
      case DisasterCategory.flood:
        return const Color(0xFF29B6F6);
      case DisasterCategory.earthquake:
        return const Color(0xFFFF7043);
      case DisasterCategory.volcano:
        return const Color(0xFFE53935);
      case DisasterCategory.powerEMP:
        return const Color(0xFFAB47BC);
      case DisasterCategory.commsOutage:
        return const Color(0xFF78909C);
      case DisasterCategory.waterContamination:
        return const Color(0xFF26A69A);
    }
  }

  /// معرّف ثابت للتخزين و JSON.
  String get id => name;
}

/// إرجاع التصنيف من معرّفه المخزّن.
DisasterCategory? disasterCategoryFromId(String? id) {
  if (id == null) return null;
  for (final value in DisasterCategory.values) {
    if (value.name == id) return value;
  }
  return null;
}
