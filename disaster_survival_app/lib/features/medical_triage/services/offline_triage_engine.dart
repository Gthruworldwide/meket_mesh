/// محرك الفرز الطبي والإسعافات الأولية — يعمل أوفلاين بالكامل.
///
/// يعتمد على خوارزمية START (Simple Triage and Rapid Treatment) المستخدمة
/// ميدانياً في الكوارث، إضافة إلى حاسبات احتياج البقاء (مياه/سعرات) وأدلة
/// إسعاف أولي مكتوبة بلغة خطوات قابلة للتنفيذ.
library;

/// تصنيفات الفرز (START).
enum TriageCategory { immediate, delayed, minor, expectant }

extension TriageCategoryX on TriageCategory {
  String get label {
    switch (this) {
      case TriageCategory.immediate:
        return 'أحمر — تدخل فوري';
      case TriageCategory.delayed:
        return 'أصفر — تأجيل مؤقت';
      case TriageCategory.minor:
        return 'أخضر — إصابات بسيطة';
      case TriageCategory.expectant:
        return 'أسود — رعاية تلطيفية';
    }
  }

  String get shortLabel {
    switch (this) {
      case TriageCategory.immediate:
        return 'فوري';
      case TriageCategory.delayed:
        return 'مؤجل';
      case TriageCategory.minor:
        return 'بسيط';
      case TriageCategory.expectant:
        return 'متوقع الوفاة';
    }
  }

  /// لون تقريبي للعرض (ARGB) — مستقل عن Flutter داخل المحرك.
  int get colorValue {
    switch (this) {
      case TriageCategory.immediate:
        return 0xFFFF5C5C;
      case TriageCategory.delayed:
        return 0xFFFFC94D;
      case TriageCategory.minor:
        return 0xFF4CD964;
      case TriageCategory.expectant:
        return 0xFF9E9E9E;
    }
  }
}

/// مدخلات فحص START (كل حقل قابل لأن يكون غير معروف أثناء تقدّم المعالج).
class TriageInput {
  bool? severeBleeding;
  bool? canWalk;
  bool? isBreathing;
  bool? normalRespiration;
  bool? normalPerfusion;
  bool? obeysCommands;

  TriageInput({
    this.severeBleeding,
    this.canWalk,
    this.isBreathing,
    this.normalRespiration,
    this.normalPerfusion,
    this.obeysCommands,
  });
}

/// نتيجة الفرز مع خطوات العمل الفورية.
class TriageResult {
  final TriageCategory category;
  final String rationale;
  final List<String> instructions;

  const TriageResult({
    required this.category,
    required this.rationale,
    required this.instructions,
  });
}

/// احتياجات البقاء المحسوبة.
class SurvivalNeeds {
  final int persons;
  final int children;
  final int days;
  final double drinkingWaterLiters;
  final double hygieneWaterLiters;
  final double totalWaterLiters;
  final int waterContainers5L;
  final int purificationTablets;
  final int caloriesKcal;
  final double dryFoodKg;

  const SurvivalNeeds({
    required this.persons,
    required this.children,
    required this.days,
    required this.drinkingWaterLiters,
    required this.hygieneWaterLiters,
    required this.totalWaterLiters,
    required this.waterContainers5L,
    required this.purificationTablets,
    required this.caloriesKcal,
    required this.dryFoodKg,
  });
}

/// دليل إسعاف أولي بخطوات مرتبة.
class FirstAidGuide {
  final String id;
  final String title;
  final String summary;
  final List<String> steps;

  const FirstAidGuide({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
  });
}

class OfflineTriageEngine {
  OfflineTriageEngine._();

  /// تطبيق شجرة قرار START.
  ///
  /// يعيد `null` إذا كانت المعطيات غير كافية بعد للبت في التصنيف، ما يسمح
  /// للمعالج التفاعلي بمواصلة الأسئلة.
  static TriageResult? evaluate(TriageInput input) {
    // 1) نزيف لا يمكن السيطرة عليه → فوري.
    if (input.severeBleeding == true) {
      return _result(
        TriageCategory.immediate,
        'نزيف حاد غير مسيطر عليه — أولوية قصوى قبل أي إجراء آخر.',
      );
    }

    // 2) قادر على المشي → بسيط (Walking wounded).
    if (input.canWalk == true) {
      return _result(
        TriageCategory.minor,
        'المصاب يمشي بنفسه — لا يحتاج موارد حرجة الآن.',
      );
    }
    if (input.canWalk == null) return null;

    // 3) لا يتنفس بعد فتح مجرى الهواء → رعاية تلطيفية.
    if (input.isBreathing == false) {
      return _result(
        TriageCategory.expectant,
        'توقف تنفس بعد فتح مجرى الهواء — فرص النجاة منعدمة مع الموارد المتاحة.',
      );
    }
    if (input.isBreathing == null) return null;

    // 4) معدل تنفس غير طبيعي (>30 أو <10) → فوري.
    if (input.normalRespiration == false) {
      return _result(
        TriageCategory.immediate,
        'خلل في معدل التنفس خارج النطاق الآمن (10–30 نفس/دقيقة).',
      );
    }
    if (input.normalRespiration == null) return null;

    // 5) خلل في التروية (امتلاء شعيرات > ثانيتين) → فوري.
    if (input.normalPerfusion == false) {
      return _result(
        TriageCategory.immediate,
        'ضعف التروية الدموية — احتمال صدمة نزفية أو هبوط دوراني.',
      );
    }
    if (input.normalPerfusion == null) return null;

    // 6) لا يطيع الأوامر → فوري.
    if (input.obeysCommands == false) {
      return _result(
        TriageCategory.immediate,
        'تغير مستوى الوعي — احتمال إصابة دماغية أو نقص أكسجين.',
      );
    }
    if (input.obeysCommands == null) return null;

    // 7) اجتاز كل الفحوص → مؤجل.
    return _result(
      TriageCategory.delayed,
      'مصاب غير قادر على المشي لكنه مستقر تنفسياً ودورانياً.',
    );
  }

  static TriageResult _result(TriageCategory category, String rationale) {
    return TriageResult(
      category: category,
      rationale: rationale,
      instructions: _instructions[category] ?? const [],
    );
  }

  static const Map<TriageCategory, List<String>> _instructions = {
    TriageCategory.immediate: [
      'أوقف النزيف فوراً: ضغط مباشر قوي، ثم عاصبة فوق الجرح إن لزم.',
      'أمن مجرى الهواء وضع المصاب في وضعية الاستلقاء مع رفع القدمين.',
      'انقل المصاب إلى نقطة التجميع الحمراء بأسرع مسار آمن.',
      'راقب التنفس والوعي كل دقيقة وسجّل أي تدهور.',
    ],
    TriageCategory.delayed: [
      'ثبّت الكسور وجرّح الجروح وضمّدها.',
      'قدّم الماء والمسكنات المتوفرة إن لم يكن هناك موانع.',
      'أعد الفرز كل 15 دقيقة أو عند أي تغير في الحالة.',
    ],
    TriageCategory.minor: [
      'وجّه المصاب إلى منطقة الانتظار الخضراء.',
      'اطلب منه مساعدة الآخرين القادرين على الحركة إن أمكن.',
      'أعد التقييم فوراً إذا ظهر نزيف أو صعوبة تنفس.',
    ],
    TriageCategory.expectant: [
      'قدّم الرعاية التلطيفية: مسكنات، تدفئة، وطمأنة.',
      'غطِّ المصاب واحفظ كرامته وخصوصيته.',
      'أعد التقييم إذا توفرت موارد بشرية أو طبية إضافية.',
    ],
  };

  /// حساب احتياجات البقاء (مياه/سعرات/عبوات/أقراص تطهير).
  static SurvivalNeeds computeSurvivalNeeds({
    required int persons,
    int children = 0,
    required int days,
  }) {
    final safePersons = persons < 1 ? 1 : persons;
    final safeChildren = children.clamp(0, safePersons);
    final adults = safePersons - safeChildren;
    final safeDays = days < 1 ? 1 : days;

    // 3 لتر شرب للبالغ، 1.5 لتر للطفل، + 2 لتر نظافة للفرد يومياً.
    final drinking = (adults * 3.0 + safeChildren * 1.5) * safeDays;
    final hygiene = safePersons * 2.0 * safeDays;
    final total = drinking + hygiene;

    final calories = (adults * 2000 + safeChildren * 1400) * safeDays;

    return SurvivalNeeds(
      persons: safePersons,
      children: safeChildren,
      days: safeDays,
      drinkingWaterLiters: drinking,
      hygieneWaterLiters: hygiene,
      totalWaterLiters: total,
      waterContainers5L: (total / 5).ceil(),
      purificationTablets: (drinking / 2).ceil(),
      caloriesKcal: calories,
      dryFoodKg: calories / 3500,
    );
  }

  /// أدلة الإسعاف الأولي الجاهزة أوفلاين.
  static const List<FirstAidGuide> firstAidGuides = [
    FirstAidGuide(
      id: 'bleeding',
      title: 'السيطرة على النزيف الحاد',
      summary: 'كل دقيقة نزيف = فقدان دم حرج. الضغط ثم العاصبة.',
      steps: [
        'ارتدِ قفازات إن توفرت، واضغط مباشرة بقوة على الجرح بقطعة قماش نظيفة.',
        'لا ترفع الضغط للفحص — استمر 5–10 دقائق متواصلة على الأقل.',
        'إن استمر النزيف، ضع عاصبة (CAT) على 5–7 سم فوق الجرح وشدّها حتى يتوقف.',
        'دوّن وقت تركيب العاصبة على جلد المصاب؛ لا تفكها ميدانياً.',
        'راقب علامات الصدمة: شحوب، تعرّق، تسارع نبض، وهن.',
      ],
    ),
    FirstAidGuide(
      id: 'burns',
      title: 'الحروق',
      summary: 'تبريد فوري بالماء، وعدم فتح الفقاعات.',
      steps: [
        'ابعد المصاب عن مصدر الحرق واخلع الملابس غير الملتصقة بالجلد.',
        'برّد المنطقة بماء جارٍ فاتر 15–20 دقيقة (لا ثلج مباشر).',
        'غطِّ الحرق بضماد نظيف غير لاصق أو قطعة قماش مبللة معقمة.',
        'لا تفتح الفقاعات ولا تضع معاجين أو زيوتاً.',
        'اطلب إخلاءً عاجلاً لحروق الوجه أو اليدين أو المفاصل أو أكبر من راحة اليد.',
      ],
    ),
    FirstAidGuide(
      id: 'fracture',
      title: 'الكسور والالتواءات',
      summary: 'تثبيت كما هو، لا إعادة محاولة تعديل.',
      steps: [
        'لا تحاول «تعديل» العظم البارز — ثبّت الطرف في وضعه الحالي.',
        'استخدم جبيرة (خشب/كرتون مقوّى) تمتد للمفصلين أعلى وأسفل الإصابة.',
        'اربط بأربطة غير محكمة تسمح بمرور الدم، وافحص الأصابع (لون/حرارة/إحساس).',
        'ضع ثلجاً ملفوفاً بالقماش لمدة 15 دقيقة كل ساعة لتخفيف التورم.',
        'اطلب إخلاءً لأي كسر مفتوح أو تشوه واضح أو فقدان إحساس.',
      ],
    ),
    FirstAidGuide(
      id: 'hypothermia',
      title: 'انخفاض حرارة الجسم',
      summary: 'تدفئة تدريجية وتجنب الحركة العنيفة.',
      steps: [
        'انقل المصاب إلى مكان جاف محمي من الريح، واخلع الملابس المبللة.',
        'غلّفه ببطانيات جافة/حرارية مع تغطية الرأس والرقبة.',
        'أعطِ مشروبات دافئة غير كحولية إذا كان واعياً ويستطيع البلع.',
        'تجنّب فرك الأطراف بقوة أو غمر مفاجئ في ماء ساخن.',
        'اطلب إخلاءً عند فقدان الوعي أو بطء شديد في النبض.',
      ],
    ),
    FirstAidGuide(
      id: 'heatstroke',
      title: 'ضربة الشمس والإجهاد الحراري',
      summary: 'تبريد سريع — كل دقيقة تأخير ترفع الوفيات.',
      steps: [
        'انقل المصاب إلى ظل/مكان بارد واخلع الملابس الزائدة.',
        'بلّل الجسم بالماء وراوح بالهواء لتسريع التبريد.',
        'ضع كمادات باردة على الرقبة والإبطين وأعلى الفخذين.',
        'أعطِ ماءً بارداً بجرعات صغيرة إذا كان واعياً.',
        'لا تعطِ ماءً لمن فقد الوعي؛ اطلب إخلاءً عاجلاً.',
      ],
    ),
    FirstAidGuide(
      id: 'radiation',
      title: 'التعرض للإشعاع / الغبار النووي',
      summary: 'إزالة التلوث السطحي أولاً، ثم الاحتماء.',
      steps: [
        'لا تلمس وجهك؛ ضع كمامة مبللة أو قماشاً على الأنف والفم.',
        'اخلع الملابس الخارجية في منطقة معزولة وضعها في كيس محكم.',
        'استحم بماء فاتر وصابون (بدون فرك قوي) 10–15 دقيقة.',
        'احتمِ في غرفة داخلية بلا نوافذ، وأغلق التهوية والأبواب.',
        'تناول أقراص يوديد البوتاسيوم فقط بتوجيه رسمي، وابتعد عن الطعام المكشوف.',
      ],
    ),
    FirstAidGuide(
      id: 'drowning',
      title: 'الغرق وإنعاش القلب الرئوي',
      summary: 'ابدأ الضغطات فوراً — لا تنتظر سيارة الإسعاف.',
      steps: [
        'أخرج المصاب من الماء بأمان دون تعريض نفسك للغرق.',
        'افحص الاستجابة والتنفس لمدة لا تزيد عن 10 ثوانٍ.',
        'إن لم يتنفس: 30 ضغطة صدرية (عمق 5–6 سم، وتيرة 100–120/دقيقة) + نفسان إنقاذيان.',
        'استمر بالدورات 30:2 حتى وصول المساعدة أو استعادة التنفس.',
        'إن استعاد التنفس: ضعه في وضعية الإفاقة الجانبية وغطِّه.',
      ],
    ),
    FirstAidGuide(
      id: 'shock',
      title: 'الصدمة (هبوط دوراني)',
      summary: 'تعرّف مبكر: شحوب + تعرّق + تسارع نبض + ارتباك.',
      steps: [
        'أضجع المصاب وارفع ساقيه 20–30 سم إن لم توجد إصابة في الحوض/الفخذ.',
        'أوقف أي نزيف ظاهر فوراً.',
        'حافظ على دفء المصاب ببطانية، ولا تعطِه طعاماً أو شراباً.',
        'راقب الوعي والتنفس كل دقيقتين.',
        'انقل عاجلاً إلى نقطة الفرز الحمراء.',
      ],
    ),
  ];
}
