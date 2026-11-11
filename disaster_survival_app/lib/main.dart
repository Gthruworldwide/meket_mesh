import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/network/mesh_manager.dart';
import 'core/state/app_settings.dart';
import 'core/utils/local_store.dart';
import 'features/hardware_score/presentation/score_dashboard.dart';
import 'features/medical_triage/presentation/triage_screen.dart';
import 'features/offgrid_news/presentation/news_screen.dart';
import 'features/survival_checklists/presentation/checklist_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  runApp(const ProviderScope(child: ResiliNetApp()));
}

/// تطبيق ResiliNet — يعمل أوفلاين بالكامل بواجهة عربية (RTL).
class ResiliNetApp extends ConsumerWidget {
  const ResiliNetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redNight = ref.watch(redNightProvider);
    final theme = AppColors.buildTheme(redNight: redNight);
    final ready = LocalStore.isPersistent;

    return MaterialApp(
      title: 'ResiliNet — الإنقاذ اللامركزي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeShell(storageReady: ready),
    );
  }
}

/// الهيكل الرئيسي: أربع شاشات في IndexedStack مع شريط تنقّل سفلي.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.storageReady});

  final bool storageReady;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const List<Widget> _screens = [
    ScoreDashboard(),
    ChecklistScreen(),
    NewsScreen(),
    TriageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(meshManagerProvider).init();
      if (!widget.storageReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذّر تهيئة التخزين الدائم — ستعمل الجلسة بالذاكرة فقط.',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sosCount = ref.watch(sosFeedProvider).length;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: sosCount > 0,
              label: Text('$sosCount'),
              child: const Icon(Icons.shield_outlined),
            ),
            selectedIcon: const Icon(Icons.shield),
            label: 'الجاهزية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack),
            label: 'التجهيزات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'الأنباء',
          ),
          const NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'الفرز',
          ),
        ],
      ),
    );
  }
}
