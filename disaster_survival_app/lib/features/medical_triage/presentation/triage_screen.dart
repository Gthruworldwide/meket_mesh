import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/red_night_toggle.dart';
import '../../../core/widgets/tactical_widgets.dart';
import '../services/offline_triage_engine.dart';

/// شاشة الفرز الطبي التفاعلي + حاسبة احتياجات البقاء + أدلة الإسعاف.
class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key});

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends ConsumerState<TriageScreen> {
  TriageInput _input = TriageInput();
  TriageResult? _result;
  int _step = 0;

  int _persons = 1;
  int _children = 0;
  int _days = 3;

  static final List<_Question> _questions = [
    _Question(
      prompt: 'هل يوجد نزيف حاد لا يمكن السيطرة عليه؟',
      hint: 'نزيف نابض أو غزير لا يتوقف بالضغط المباشر.',
      apply: (input, value) => input.severeBleeding = value,
      yesLabel: 'نعم، نزيف غزير',
      noLabel: 'لا، النزيف مسيطر عليه',
    ),
    _Question(
      prompt: 'هل يستطيع المصاب المشي بنفسه؟',
      hint: 'اطلب منه الوقوف والمشي خطوتين إن كان واعياً.',
      apply: (input, value) => input.canWalk = value,
      yesLabel: 'نعم، يمشي',
      noLabel: 'لا، غير قادر',
    ),
    _Question(
      prompt: 'بعد فتح مجرى الهواء: هل يتنفس المصاب؟',
      hint: 'راقب حركة الصدر لمدة 10 ثوانٍ كحد أقصى.',
      apply: (input, value) => input.isBreathing = value,
      yesLabel: 'نعم، يتنفس',
      noLabel: 'لا، متوقف',
    ),
    _Question(
      prompt: 'هل معدل التنفس طبيعي (10–30 نفساً/دقيقة)؟',
      hint: 'عُدّ الأنفاس لمدة 15 ثانية واضرب في 4.',
      apply: (input, value) => input.normalRespiration = value,
      yesLabel: 'نعم، ضمن النطاق',
      noLabel: 'لا، سريع أو بطيء',
    ),
    _Question(
      prompt: 'هل التروية الدموية طبيعية؟',
      hint: 'اضغط على الظفر أو راحة اليد: يجب أن يعود اللون خلال ثانيتين.',
      apply: (input, value) => input.normalPerfusion = value,
      yesLabel: 'نعم، يعود اللون سريعاً',
      noLabel: 'لا، بطيء أو شاحب',
    ),
    _Question(
      prompt: 'هل يطيع المصاب الأوامر البسيطة؟',
      hint: 'مثال: «اضغط يدي». تغيّر الوعي إشارة خطر.',
      apply: (input, value) => input.obeysCommands = value,
      yesLabel: 'نعم، واعٍ',
      noLabel: 'لا، مشوّش أو فاقد الوعي',
    ),
  ];

  void _answer(bool value) {
    if (_step >= _questions.length) return;
    final question = _questions[_step];
    question.apply(_input, value);
    final result = OfflineTriageEngine.evaluate(_input);
    setState(() {
      if (result != null) {
        _result = result;
        _step = _questions.length;
      } else {
        _step++;
      }
    });
  }

  void _resetTriage() {
    setState(() {
      _input = TriageInput();
      _result = null;
      _step = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needs = OfflineTriageEngine.computeSurvivalNeeds(
      persons: _persons,
      children: _children,
      days: _days,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('الفرز الطبي والبقاء'),
        actions: const [RedNightToggle(), SizedBox(width: 4)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
        children: [
          TacticalCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أداة فرز ميدانية تعمل أوفلاين وفق خوارزمية START. '
                    'لا تغني عن الطبيب، لكنها ترتب الأولويات عندما تنقطع '
                    'الاتصالات والإسعاف.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      height: 1.6,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'فرز المصاب (START)',
            subtitle: 'ستة أسئلة قصيرة تحدد لون الأولوية وخطوات العمل الفورية.',
          ),
          TacticalCard(child: _buildTriage(context)),
          const SectionHeader(
            title: 'حاسبة احتياجات البقاء',
            subtitle: 'المياه والسعرات المطلوبة للأسرة أو مجموعة الإيواء.',
          ),
          TacticalCard(
            child: Column(
              children: [
                _StepperRow(
                  label: 'عدد الأشخاص',
                  value: _persons,
                  min: 1,
                  max: 50,
                  onChanged: (value) => setState(() {
                    _persons = value;
                    if (_children > _persons) _children = _persons;
                  }),
                ),
                const SizedBox(height: 6),
                _StepperRow(
                  label: 'عدد الأطفال',
                  value: _children,
                  min: 0,
                  max: _persons,
                  onChanged: (value) => setState(() => _children = value),
                ),
                const SizedBox(height: 6),
                _StepperRow(
                  label: 'عدد الأيام',
                  value: _days,
                  min: 1,
                  max: 30,
                  onChanged: (value) => setState(() => _days = value),
                ),
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _NeedCell(
                        icon: Icons.water_drop_outlined,
                        label: 'إجمالي المياه',
                        value:
                            '${needs.totalWaterLiters.toStringAsFixed(1)} لتر',
                        detail:
                            'شرب ${needs.drinkingWaterLiters.toStringAsFixed(1)} · '
                            'نظافة ${needs.hygieneWaterLiters.toStringAsFixed(1)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NeedCell(
                        icon: Icons.local_drink_outlined,
                        label: 'عبوات 5 لتر',
                        value: '${needs.waterContainers5L} عبوة',
                        detail: '${needs.purificationTablets} قرص تطهير',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _NeedCell(
                        icon: Icons.local_fire_department_outlined,
                        label: 'السعرات اليومية',
                        value: '${needs.caloriesKcal} kcal',
                        detail: 'لكل فترة $_days يوم',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NeedCell(
                        icon: Icons.rice_bowl_outlined,
                        label: 'طعام جاف',
                        value: '${needs.dryFoodKg.toStringAsFixed(1)} كغ',
                        detail: 'بمعدل 3500 kcal/كغ',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'أدلة الإسعاف الأولي',
            subtitle: 'خطوات مرتبة من الذاكرة الميدانية — تعمل بدون إنترنت.',
          ),
          ...OfflineTriageEngine.firstAidGuides.map(
            (guide) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TacticalCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(
                    _guideIcon(guide.id),
                    color: scheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    guide.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    guide.summary,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      height: 1.4,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    for (var index = 0; index < guide.steps.length; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsetsDirectional.only(
                                top: 1,
                                end: 8,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                guide.steps[index],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'الفرز يعتمد على قاعدة START الميدانية — راجع المصاب دورياً.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriage(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _result;

    if (result != null) {
      final color = Color(result.category.colorValue);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  result.category == TriageCategory.immediate
                      ? Icons.priority_high
                      : result.category == TriageCategory.minor
                      ? Icons.directions_walk
                      : result.category == TriageCategory.delayed
                      ? Icons.schedule
                      : Icons.spa_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.category.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'التصنيف: ${result.category.shortLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.rationale,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
          ...result.instructions.map(
            (instruction) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_left, size: 16, color: color),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      instruction,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetTriage,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('حالة جديدة'),
            ),
          ),
        ],
      );
    }

    if (_step >= _questions.length) {
      return Column(
        children: [
          const Text('أكملت جميع الأسئلة.'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _resetTriage,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة البدء'),
          ),
        ],
      );
    }

    final question = _questions[_step];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: _step / _questions.length,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_step + 1} / ${_questions.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          question.prompt,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          question.hint,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => _answer(true),
                child: Text(question.yesLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => _answer(false),
                child: Text(question.noLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _resetTriage,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('إعادة البدء'),
          ),
        ),
      ],
    );
  }

  IconData _guideIcon(String id) {
    switch (id) {
      case 'bleeding':
        return Icons.bloodtype_outlined;
      case 'burns':
        return Icons.local_fire_department_outlined;
      case 'fracture':
        return Icons.healing;
      case 'hypothermia':
        return Icons.ac_unit;
      case 'heatstroke':
        return Icons.wb_sunny_outlined;
      case 'radiation':
        return Icons.warning_amber_rounded;
      case 'drowning':
        return Icons.pool;
      default:
        return Icons.favorite_border;
    }
  }
}

class _Question {
  const _Question({
    required this.prompt,
    required this.hint,
    required this.apply,
    required this.yesLabel,
    required this.noLabel,
  });

  final String prompt;
  final String hint;
  final void Function(TriageInput input, bool value) apply;
  final String yesLabel;
  final String noLabel;
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 44,
          child: Center(
            child: Text(
              '$value',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}

class _NeedCell extends StatelessWidget {
  const _NeedCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
