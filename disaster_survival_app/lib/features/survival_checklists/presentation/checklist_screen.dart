import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/disaster_types.dart';
import '../../../core/utils/local_store.dart';
import '../../../core/widgets/red_night_toggle.dart';
import '../../../core/widgets/tactical_widgets.dart';
import '../data/default_equipment.dart';
import '../models/equipment_item.dart';

/// قائمة التجهيزات الديناميكية حسب نوع الكارثة.
///
/// كل عنصر يُحفظ تأمينه في Hive، ويمكن تصفية القائمة حسب الكارثة والبحث
/// بالاسم. القائمة تعمل أوفلاين بالكامل.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  late final List<EquipmentItem> _items;
  final TextEditingController _searchController = TextEditingController();
  DisasterCategory? _category;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _items = defaultDisasterEquipment.map((item) {
      final stored = LocalStore.get<bool>(LocalStore.checklistBox, item.id);
      return item.copyWith(isAcquired: stored ?? item.isAcquired);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EquipmentItem> get _filtered {
    final query = _query.trim();
    return _items.where((item) {
      final matchesCategory = _category == null || item.appliesTo(_category!);
      final matchesQuery =
          query.isEmpty ||
          item.name.contains(query) ||
          item.description.contains(query) ||
          item.category.contains(query);
      return matchesCategory && matchesQuery;
    }).toList()..sort((a, b) {
      final priority = a.priorityLevel.compareTo(b.priorityLevel);
      if (priority != 0) return priority;
      return a.name.compareTo(b.name);
    });
  }

  int get _acquiredCount => _items.where((item) => item.isAcquired).length;

  Future<void> _toggle(EquipmentItem item, bool value) async {
    setState(() => item.isAcquired = value);
    await LocalStore.write(LocalStore.checklistBox, item.id, value);
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين القائمة'),
        content: const Text(
          'سيتم إلغاء تأشير كل التجهيزات المؤمَّنة. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalStore.clear(LocalStore.checklistBox);
    if (!mounted) return;
    setState(() {
      for (final item in _items) {
        item.isAcquired = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أُعيدت قائمة التجهيزات إلى الصفر.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filtered;
    final filteredAcquired = filtered.where((item) => item.isAcquired).length;
    final ratio = filtered.isEmpty ? 0.0 : filteredAcquired / filtered.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تجهيزات البقاء'),
        actions: [
          IconButton(
            tooltip: 'إعادة تعيين الكل',
            onPressed: _resetAll,
            icon: const Icon(Icons.restart_alt),
          ),
          const RedNightToggle(),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
        children: [
          TacticalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'جاهزية المخزون',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$_acquiredCount من ${_items.length} عنصراً مؤمَّناً',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: _items.isEmpty
                                  ? 0
                                  : _acquiredCount / _items.length,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '${_items.isEmpty ? 0 : ((_acquiredCount / _items.length) * 100).round()}٪',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن جهاز أو مستلزم…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: const Text('كل الكوارث'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                ...DisasterCategory.values.map(
                  (category) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      avatar: Text(category.emoji),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (selected) => setState(
                        () => _category = selected ? category : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: _category == null
                ? 'كل التجهيزات'
                : 'تجهيزات ${_category!.label}',
            subtitle:
                '${filtered.length} عنصراً · $filteredAcquired مؤمَّن '
                '(${(ratio * 100).round()}٪)',
          ),
          if (filtered.isEmpty)
            const TacticalCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'لا توجد نتائج',
                subtitle: 'جرّب تغيير نوع الكارثة أو كلمة البحث.',
              ),
            )
          else
            ...filtered.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EquipmentTile(
                  item: item,
                  onChanged: (value) => _toggle(item, value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({required this.item, required this.onChanged});

  final EquipmentItem item;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final priorityColor = switch (item.priorityLevel) {
      1 => AppColors.danger,
      2 => AppColors.accent,
      _ => AppColors.primaryDim,
    };

    return TacticalCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      onTap: () => onChanged(!item.isAcquired),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.isAcquired,
            onChanged: (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: item.isAcquired
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isAcquired
                              ? scheme.onSurface.withValues(alpha: 0.55)
                              : null,
                        ),
                      ),
                    ),
                    StatusPill(
                      label: item.priorityLabel,
                      color: priorityColor,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    StatusPill(
                      label: item.category,
                      color: scheme.primary,
                      compact: true,
                    ),
                    ...item.applicableDisasters
                        .take(4)
                        .map(
                          (category) => StatusPill(
                            label: category.label,
                            color: category.color,
                            compact: true,
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
