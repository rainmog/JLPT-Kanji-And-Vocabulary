import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../theme_provider.dart';

class SakuraPetalsOverlay extends ConsumerStatefulWidget {
  const SakuraPetalsOverlay({super.key});

  @override
  ConsumerState<SakuraPetalsOverlay> createState() => _SakuraPetalsOverlayState();
}

class _SakuraPetalsOverlayState extends ConsumerState<SakuraPetalsOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Size _size = const Size(400, 800);
  final _random = Random();
  late final List<_Petal> _petals;

  static const _colors = [
    Color(0xFFD4778F),  // warm rose — visible on cream
    Color(0xFFE8899A),  // sakura pink
    Color(0xFFB85A72),  // deep sakura
    Color(0xFFEDADB8),  // soft blush
  ];

  @override
  void initState() {
    super.initState();
    _petals = List.generate(14, (_) => _Petal.spawn(_random, _size, scattered: true));
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
      for (final p in _petals) p.update(dt, _size, _random);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSakura = ref.watch(themeNotifier) == AppTheme.sakura;
    final animate = ref.watch(settingsProvider).animationsEnabled;
    final active = isSakura && animate;

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
          painter: _PetalPainter(_petals, _colors),
          size: Size.infinite,
        );
      }),
    );
  }
}

class _Petal {
  double x, y, vy, driftAmp, driftPhase, driftSpeed, rotation, rotSpeed, size, opacity;
  int colorIdx;

  _Petal._({
    required this.x, required this.y, required this.vy,
    required this.driftAmp, required this.driftPhase, required this.driftSpeed,
    required this.rotation, required this.rotSpeed, required this.size,
    required this.opacity, required this.colorIdx,
  });

  factory _Petal.spawn(Random r, Size screen, {bool scattered = false}) => _Petal._(
    x: r.nextDouble() * screen.width,
    y: scattered ? r.nextDouble() * screen.height : -(r.nextDouble() * 80 + 10),
    vy: r.nextDouble() * 55 + 25,
    driftAmp: r.nextDouble() * 28 + 8,
    driftPhase: r.nextDouble() * 2 * pi,
    driftSpeed: r.nextDouble() * 1.2 + 0.4,
    rotation: r.nextDouble() * 2 * pi,
    rotSpeed: (r.nextDouble() - 0.5) * 2.5,
    size: r.nextDouble() * 7 + 5,
    opacity: r.nextDouble() * 0.45 + 0.3,
    colorIdx: r.nextInt(4),
  );

  void update(double dt, Size screen, Random r) {
    y += vy * dt;
    driftPhase += driftSpeed * dt;
    x += driftAmp * cos(driftPhase) * dt;
    rotation += rotSpeed * dt;
    if (y > screen.height + 20) {
      final next = _Petal.spawn(r, screen);
      x = next.x; y = next.y; vy = next.vy;
      driftAmp = next.driftAmp; driftPhase = next.driftPhase; driftSpeed = next.driftSpeed;
      rotation = next.rotation; rotSpeed = next.rotSpeed;
      size = next.size; opacity = next.opacity; colorIdx = next.colorIdx;
    }
  }
}

class _PetalPainter extends CustomPainter {
  final List<_Petal> petals;
  final List<Color> colors;
  _PetalPainter(this.petals, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in petals) {
      paint.color = colors[p.colorIdx].withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: p.size * 1.7, height: p.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => true;
}
