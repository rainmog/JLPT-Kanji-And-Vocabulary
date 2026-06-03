import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme.dart';
import 'theme_provider.dart';
import 'screens/home_screen.dart';
import 'widgets/startup_logo_overlay.dart';
import 'screens/onboarding_welcome_screen.dart';
import 'services/onboarding_service.dart';
import 'services/settings_service.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await SoundService.init();
  runApp(const ProviderScope(child: KanjiApp()));
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();
  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  bool? _onboardingComplete;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final checkFuture = OnboardingService.isOnboardingComplete();
    final delayFuture = Future.delayed(const Duration(milliseconds: 2400));
    final done = await checkFuture;
    if (!mounted) return;
    setState(() => _onboardingComplete = done);
    await delayFuture;
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return Stack(children: [
        Container(color: AppColors.bg),
        const StartupLogoOverlay(),
      ]);
    }
    if (_onboardingComplete == false) {
      return const OnboardingWelcomeScreen();
    }
    return Stack(children: [
      const HomeScreen(),
      const StartupLogoOverlay(),
    ]);
  }
}

class KanjiApp extends ConsumerWidget {
  const KanjiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColors = ref.watch(themeColorsProvider);
    final settings = ref.watch(settingsProvider);
    setCurrentTheme(themeColors);
    setCurrentFonts(settings.englishFont, settings.japaneseFont);
    return MaterialApp(
      title: 'JLPT Kanji & Vocabulary',
      theme: buildTheme(themeColors),
      home: const _AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}
