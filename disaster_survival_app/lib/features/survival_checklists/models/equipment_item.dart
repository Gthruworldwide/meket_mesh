import '../../../core/constants/disaster_types.dart';

/// نموذج عنصر تجهيز/مشتريات في قائمة الاستعداد للكوارث.
class EquipmentItem {
  final String id;
  final String name;
  final String category;
  final String description;

  /// 1: حرج جداً (72 ساعة), 2: مهم, 3: استدامة.
  final int priorityLevel;

  /// الكوارث التي يكون فيها هذا العنصر ضرورياً.
  final List<DisasterCategory> applicableDisasters;

  /// هل تم تأمين العنصر؟ (تُحفظ الحالة محلياً في Hive).
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

  EquipmentItem copyWith({bool? isAcquired}) {
    return EquipmentItem(
      id: id,
      name: name,
      category: category,
      description: description,
      priorityLevel: priorityLevel,
      applicableDisasters: applicableDisasters,
      isAcquired: isAcquired ?? this.isAcquired,
    );
  }

  String get priorityLabel {
    switch (priorityLevel) {
      case 1:
        return 'حرج 72 ساعة';
      case 2:
        return 'مهم';
      default:
        return 'استدامة';
    }
  }

  bool appliesTo(DisasterCategory category) =>
      applicableDisasters.contains(category);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'priorityLevel': priorityLevel,
    'applicableDisasters': applicableDisasters
        .map((e) => e.id)
        .toList(growable: false),
    'isAcquired': isAcquired,
  };

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    final rawDisasters = (json['applicableDisasters'] as List<dynamic>? ?? []);
    final disasters = <DisasterCategory>[];
    for (final raw in rawDisasters) {
      final category = disasterCategoryFromId(raw as String?);
      if (category != null) disasters.add(category);
    }
    return EquipmentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      priorityLevel: json['priorityLevel'] as int? ?? 2,
      applicableDisasters: disasters,
      isAcquired: json['isAcquired'] as bool? ?? false,
    );
  }
}
