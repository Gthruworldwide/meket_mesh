import '../../../core/constants/disaster_types.dart';
import '../models/equipment_item.dart';

/// قاعدة البيانات الأولية لأجهزة ومستلزمات الطوارئ، مصنّفة حسب نوع الكارثة.
///
/// تعمل أوفلاين بالكامل؛ يمكن لاحقاً توسيعها عبر تحديث حزم بيانات موقّعة
/// تُنقل عبر شبكة المش أو FM-RDS.
final List<EquipmentItem> defaultDisasterEquipment = [
  // ── الاتصالات اللاسلكية ────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_lora',
    name: 'أجهزة اتصال مش (Meshtastic / LoRa Node)',
    category: 'الاتصالات اللاسلكية',
    description: 'يسمح بتبادل الرسائل والمواقع الإحداثية بدون إنترنت لمسافة عدة كيلومترات.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.commsOutage,
      DisasterCategory.nuclear,
      DisasterCategory.earthquake,
    ],
  ),
  EquipmentItem(
    id: 'eq_hand_radio',
    name: 'أجهزة لاسلكي قريبة المدى (Walkie-Talkie)',
    category: 'الاتصالات اللاسلكية',
    description: 'قناة صوتية فورية داخل نطاق الحي أو مركز الإيواء عند انقطاع الشبكة الخلوية.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.commsOutage],
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
    applicableDisasters: [
      DisasterCategory.commsOutage,
      DisasterCategory.nuclear,
      DisasterCategory.flood,
      DisasterCategory.powerEMP,
    ],
  ),

  // ── الأخطار النووية والتلوث ────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_geiger',
    name: 'عداد جايجر الرقمي (Geiger Counter)',
    category: 'أجهزة قياس البيئة',
    description: 'يقيس مستويات الجرعة الإشعاعية الحية لحساب وقت البقاء الآمن في الملاجئ.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.nuclear],
  ),
  EquipmentItem(
    id: 'eq_cbrn_mask',
    name: 'قناع غاز كرتوشي شامل (CBRN Respirator)',
    category: 'الحماية التنفسية',
    description:
        'يعزل الغبار الإشعاعي الذري والغازات السامة والأبخرة الكيميائية.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.nuclear, DisasterCategory.volcano],
  ),
  EquipmentItem(
    id: 'eq_ki_tablets',
    name: 'أقراص يوديد البوتاسيوم (KI)',
    category: 'الحماية الإشعاعية',
    description:
        'تُؤخذ فقط عند توجيه السلطات لحماية الغدة الدرقية من اليود المشع.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.nuclear],
  ),
  EquipmentItem(
    id: 'eq_dosimeter',
    name: 'شارة قياس جرعة إشعاعية شخصية',
    category: 'أجهزة قياس البيئة',
    description: 'تسجل الجرعة التراكمية للفرد أثناء الإخلاء والاحتماء.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.nuclear],
  ),

  // ── تنقية المياه والصحة ────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_water_filter',
    name: 'فلتر مياه دقيق محمول (Portable Micro-Filter)',
    category: 'المياه والصحة',
    description: 'يزيل البكتيريا والجسيمات الدقيقة من المياه السطحية والملوثة.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.waterContamination,
      DisasterCategory.flood,
      DisasterCategory.earthquake,
    ],
  ),
  EquipmentItem(
    id: 'eq_water_tablets',
    name: 'أقراص تطهير المياه (Chlorine Dioxide Tablets)',
    category: 'المياه والصحة',
    description: 'تعقيم المياه والقضاء على الفيروسات والميكروبات قبل الشرب.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.waterContamination,
      DisasterCategory.flood,
    ],
  ),
  EquipmentItem(
    id: 'eq_water_storage',
    name: 'عبوات مياه وسبائك تخزين (20 لتر/فرد)',
    category: 'المياه والصحة',
    description: 'احتياطي مياه مسبق التعبئة يكفي 72 ساعة على الأقل لكل فرد (3 لتر شرب يومياً).',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.flood,
      DisasterCategory.earthquake,
      DisasterCategory.commsOutage,
    ],
  ),
  EquipmentItem(
    id: 'eq_meds',
    name: 'علبة أدوية مزمنة (7–14 يوماً)',
    category: 'الصحة',
    description: 'نسخ احتياطية من أدوية الضغط والسكري والقلب والأطفال، مع قائمة جرعات مكتوبة.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.flood,
      DisasterCategory.commsOutage,
      DisasterCategory.nuclear,
    ],
  ),

  // ── الغذاء والطاقة ─────────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_food_72h',
    name: 'مؤونة 72 ساعة جاهزة (2400 kcal/يوم)',
    category: 'الغذاء',
    description: 'وجبات لا تحتاج طهي ولا ماءً مضافاً، وتحتفظ بصلاحيتها لسنوات.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.flood,
      DisasterCategory.nuclear,
      DisasterCategory.volcano,
    ],
  ),
  EquipmentItem(
    id: 'eq_food_bars',
    name: 'ألواح طاقة عالية السعرات',
    category: 'الغذاء',
    description: 'وجبات سريعة خفيفة الوزن للمهمات الميدانية والإخلاء السريع.',
    priorityLevel: 3,
    applicableDisasters: [DisasterCategory.earthquake, DisasterCategory.flood],
  ),
  EquipmentItem(
    id: 'eq_stove',
    name: 'موقد تخييم ووقود آمن',
    category: 'الغذاء',
    description: 'لطعام ساخن عند انقطاع الغاز/الكهرباء — يُستخدم في مكان جيد التهوية حصراً.',
    priorityLevel: 2,
    applicableDisasters: [
      DisasterCategory.powerEMP,
      DisasterCategory.commsOutage,
      DisasterCategory.earthquake,
    ],
  ),
  EquipmentItem(
    id: 'eq_powerbank',
    name: 'بنك طاقة 20,000mAh + كوابل',
    category: 'الطاقة',
    description:
        'يشحن الهواتف وأجهزة المش 3–5 مرات؛ أساسي للحفاظ على العقد الشبكية.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.commsOutage,
      DisasterCategory.earthquake,
      DisasterCategory.powerEMP,
      DisasterCategory.flood,
    ],
  ),
  EquipmentItem(
    id: 'eq_solar_panel',
    name: 'لوح شمسي قابل للطي 20–40 واط',
    category: 'الطاقة',
    description: 'شحن مستقل يعيد ملء بنوك الطاقة يومياً عند توفر الشمس.',
    priorityLevel: 2,
    applicableDisasters: [
      DisasterCategory.commsOutage,
      DisasterCategory.powerEMP,
      DisasterCategory.earthquake,
    ],
  ),
  EquipmentItem(
    id: 'eq_hand_crank',
    name: 'شاحن يدوي/دينامو متعدد المخارج',
    category: 'الطاقة',
    description:
        'بديل ميكانيكي لا يعتمد على الشمس أو الشبكة — مناسب لحالات EMP.',
    priorityLevel: 2,
    applicableDisasters: [
      DisasterCategory.powerEMP,
      DisasterCategory.commsOutage,
    ],
  ),
  EquipmentItem(
    id: 'eq_batteries',
    name: 'بطاريات احتياطية (AA/AAA/18650)',
    category: 'الطاقة',
    description: 'تشغيل الكشافات والراديو والأجهزة الطبية الصغيرة.',
    priorityLevel: 2,
    applicableDisasters: [
      DisasterCategory.powerEMP,
      DisasterCategory.commsOutage,
      DisasterCategory.earthquake,
    ],
  ),

  // ── الإضاءة والأدوات ───────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_headlamp',
    name: 'كشاف رأس بإضاءة حمراء',
    category: 'الإضاءة والأدوات',
    description:
        'إضاءة ميدانية تحافظ على الرؤية الليلية وتحرر اليدين أثناء الإنقاذ.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.powerEMP,
      DisasterCategory.commsOutage,
    ],
  ),
  EquipmentItem(
    id: 'eq_glowsticks',
    name: 'عصي إضاءة كيميائية',
    category: 'الإضاءة والأدوات',
    description: 'إضاءة آمنة بدون نار أو بطاريات لتعليم الممرات والملاجئ.',
    priorityLevel: 3,
    applicableDisasters: [
      DisasterCategory.powerEMP,
      DisasterCategory.earthquake,
    ],
  ),
  EquipmentItem(
    id: 'eq_multitool',
    name: 'أداة متعددة الاستخدامات + كابل',
    category: 'الإضاءة والأدوات',
    description: 'قطع ولف وإصلاح سريع للأجهزة والخيام وأنظمة المياه.',
    priorityLevel: 2,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.powerEMP,
      DisasterCategory.commsOutage,
    ],
  ),
  EquipmentItem(
    id: 'eq_whistle',
    name: 'صافرة إنقاذ عالية التردد',
    category: 'الإضاءة والأدوات',
    description:
        'إشارة صوتية تُسمع من مسافة بعيدة عند الحصار تحت الأنقاض وندرة الطاقة.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.earthquake, DisasterCategory.flood],
  ),
  EquipmentItem(
    id: 'eq_duct_tape',
    name: 'شريط لاصق تكتيكي + حبال',
    category: 'الإضاءة والأدوات',
    description: 'تثبيت مؤقت، إغلاق نوافذ، وربط أحمال أثناء الإخلاء.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.earthquake, DisasterCategory.flood],
  ),
  EquipmentItem(
    id: 'eq_gas_wrench',
    name: 'مفتاح إغلاق صمام الغاز',
    category: 'الإضاءة والأدوات',
    description:
        'إغلاق الغاز فوراً بعد الزلازل لمنع الحرائق والانفجارات الثانوية.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.earthquake],
  ),
  EquipmentItem(
    id: 'eq_crowbar',
    name: 'عتلة إنقاذ (Crowbar)',
    category: 'الإضاءة والأدوات',
    description: 'فتح الأبواب المنحرفة ورفع الأنقاض الخفيفة أثناء الإنقاذ.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.earthquake],
  ),
  EquipmentItem(
    id: 'eq_signal_mirror',
    name: 'مرآة إشارة + لوحة SOS',
    category: 'الإشارات',
    description:
        'توجيه طائرات الإنقاذ والإشارة الضوئية عند تعطل كل وسائل الاتصال.',
    priorityLevel: 3,
    applicableDisasters: [
      DisasterCategory.commsOutage,
      DisasterCategory.earthquake,
    ],
  ),

  // ── الإسعافات الأولية ──────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_first_aid',
    name: 'حقيبة إسعافات أولية شاملة',
    category: 'الإسعافات الأولية',
    description: 'ضمادات، مطهرات، قفازات، مقص طبي، وأدوية أساسية لعلاج الإصابات الشائعة.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.flood,
      DisasterCategory.volcano,
      DisasterCategory.nuclear,
    ],
  ),
  EquipmentItem(
    id: 'eq_tourniquet',
    name: 'عاصبة CAT + ضمادات إسرائيلية',
    category: 'الإسعافات الأولية',
    description: 'السيطرة على النزيف الشرياني الحاد — مهارة إنقاذ الحياة الأولى في الكوارث.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.volcano,
    ],
  ),
  EquipmentItem(
    id: 'eq_n95',
    name: 'كمامات N95/P100 احتياطية',
    category: 'الحماية التنفسية',
    description:
        'حماية من الغبار والرماد البركاني والجسيمات المشعة العالقة في الهواء.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.volcano,
      DisasterCategory.nuclear,
      DisasterCategory.earthquake,
    ],
  ),
  EquipmentItem(
    id: 'eq_goggles',
    name: 'نظارات واقية محكمة',
    category: 'الحماية التنفسية',
    description: 'حماية العينين من الرماد والغبار والمواد الكيميائية.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.volcano, DisasterCategory.nuclear],
  ),

  // ── المأوى والحماية ────────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_shelter_tent',
    name: 'خيمة/مأوى طارئ',
    category: 'المأوى',
    description: 'مأوى سريع للأسر المشردة بعد انهيار المباني أو الإخلاء.',
    priorityLevel: 2,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.flood,
      DisasterCategory.volcano,
    ],
  ),
  EquipmentItem(
    id: 'eq_space_blanket',
    name: 'بطانيات حرارية (Mylar)',
    category: 'المأوى',
    description:
        'تحفظ حرارة الجسم وتمنع انخفاض الحرارة الليلي بعد فقدان المأوى.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.flood,
      DisasterCategory.volcano,
    ],
  ),
  EquipmentItem(
    id: 'eq_tarp',
    name: 'مشمع/طرابالين مقاوم للماء',
    category: 'المأوى',
    description: 'تغطية أسطح متضررة وتجميع مياه الأمطار وإقامة مأوى مؤقت.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.flood, DisasterCategory.earthquake],
  ),
  EquipmentItem(
    id: 'eq_life_vest',
    name: 'سترة نجاة (كبار وأطفال)',
    category: 'الفيضانات',
    description:
        'ضرورية عند الإخلاء المائي أو البقاء قرب مجارٍ وسدود معرضة للانهيار.',
    priorityLevel: 1,
    applicableDisasters: [DisasterCategory.flood],
  ),
  EquipmentItem(
    id: 'eq_sandbags',
    name: 'أكياس رمل/حواجز مياه',
    category: 'الفيضانات',
    description: 'حصار مداخل المنزل وتوجيه المياه بعيداً عن الملاجئ.',
    priorityLevel: 2,
    applicableDisasters: [DisasterCategory.flood],
  ),

  // ── الوثائق والنقد ─────────────────────────────────────────────────────
  EquipmentItem(
    id: 'eq_documents',
    name: 'نسخ ورقية من الوثائق + نقد فكة',
    category: 'الوثائق والنقد',
    description: 'هويات، وصفات طبية، وأرقام اتصال مطبوعة؛ النقد ضروري عند تعطل الدفع الإلكتروني.',
    priorityLevel: 1,
    applicableDisasters: [
      DisasterCategory.earthquake,
      DisasterCategory.flood,
      DisasterCategory.nuclear,
    ],
  ),
];
