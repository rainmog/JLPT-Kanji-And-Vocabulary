import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import 'logo_widget.dart';

class StartupLogoOverlay extends ConsumerStatefulWidget {
  const StartupLogoOverlay({super.key});

  static bool _shown = false;

  @override
  ConsumerState<StartupLogoOverlay> createState() =>
      _StartupLogoOverlayState();
}

class _StartupLogoOverlayState extends ConsumerState<StartupLogoOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  bool _active = false;

  @override
  void initState() {
    super.initState();

    // Single controller: fade-in → hold → fade-out, no Future.delayed needed
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _opacity = TweenSequence<double>([
      // Gentle fade in — 900ms
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      // Hold — 2000ms
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      // Fade out — 720ms
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_ctrl);

    if (StartupLogoOverlay._shown) return;
    StartupLogoOverlay._shown = true;
    _active = true;

    _ctrl.forward().then((_) {
      if (mounted) setState(() => _active = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme so AppColors stays current after async prefs load
    final colors = ref.watch(themeColorsProvider);
    setCurrentTheme(colors);

    if (!_active) return const SizedBox.shrink();

    // Material covers the screen at full opacity immediately — only the logo
    // content fades in, preventing any flash of the underlying home screen.
    return Material(
      color: AppColors.bg,
      child: Center(
        child: AnimatedBuilder(
          animation: _opacity,
          builder: (_, __) =>
              Opacity(opacity: _opacity.value, child: const LogoWidget(size: 220)),
        ),
      ),
    );
  }
}
