import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../theme_provider.dart';

class SnowOverlay extends ConsumerStatefulWidget {
  const SnowOverlay({super.key});

  @override
  ConsumerState<SnowOverlay> createState() => _SnowOverlayState();
}

class _SnowOverlayState extends ConsumerState<SnowOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Size _size = const Size(400, 800);
  final _random = Random();
  late final List<_Flake> _flakes;

  // Neon-tinted palette to match Midnight City vibe
  static const _colors = [
    Color(0xFFFFFFFF), // white
    Color(0xFF9BE7FF), // cyan glow
    Color(0xFFCBB4FF), // purple glow
    Color(0xFFE0D8FF), // soft lavender
  ];

  @override
  void initState() {
    super.initState();
    _flakes = List.generate(28, (_) => _Flake.spawn(_random, _size, scattered: true));
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;
    setState(() {
      for (final f in _flakes) f.update(dt, _size, _random);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMidnight = ref.watch(themeNotifier) == AppTheme.midnightCity;
    final animate = ref.watch(settingsProvider).animationsEnabled;
    final active = isMidnight && animate;

    if (active && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }

    if (!active) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(builder: (_, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          painter: _FlakePainter(_flakes, _colors),
          size: Size.infinite,
        );
      }),
    );
  }
}

class _Flake {
  double x, y, vy, driftAmp, driftPhase, driftSpeed, size, opacity;
  int colorIdx;

  _Flake._({
    required this.x, required this.y, required this.vy,
    required this.driftAmp, required this.driftPhase, required this.driftSpeed,
    required this.size, required this.opacity, required this.colorIdx,
  });

  factory _Flake.spawn(Random r, Size screen, {bool scattered = false}) => _Flake._(
    x: r.nextDouble() * screen.width,
    y: scattered ? r.nextDouble() * screen.height : -(r.nextDouble() * 60 + 5),
    vy: r.nextDouble() * 70 + 40,
    driftAmp: r.nextDouble() * 14 + 3,
    driftPhase: r.nextDouble() * 2 * pi,
    driftSpeed: r.nextDouble() * 1.0 + 0.3,
    size: r.nextDouble() * 2.8 + 1.2,
    opacity: r.nextDouble() * 0.30 + 0.12,
    colorIdx: r.nextInt(4),
  );

  void update(double dt, Size screen, Random r) {
    y += vy * dt;
    driftPhase += driftSpeed * dt;
    x += driftAmp * cos(driftPhase) * dt;
    if (y > screen.height + 10) {
      final next = _Flake.spawn(r, screen);
      x = next.x; y = next.y; vy = next.vy;
      driftAmp = next.driftAmp; driftPhase = next.driftPhase; driftSpeed = next.driftSpeed;
      size = next.size; opacity = next.opacity; colorIdx = next.colorIdx;
    }
  }
}

class _FlakePainter extends CustomPainter {
  final List<_Flake> flakes;
  final List<Color> colors;
  _FlakePainter(this.flakes, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    for (final f in flakes) {
      paint.color = colors[f.colorIdx].withValues(alpha: f.opacity);
      canvas.drawCircle(Offset(f.x, f.y), f.size, paint);
    }
  }

  @override
  bool shouldRepaint(_FlakePainter old) => true;
}
