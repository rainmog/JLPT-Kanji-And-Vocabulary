import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme_provider.dart';

class SpaceAgeStarsOverlay extends ConsumerStatefulWidget {
  const SpaceAgeStarsOverlay({super.key});

  @override
  ConsumerState<SpaceAgeStarsOverlay> createState() => _SpaceAgeStarsOverlayState();
}

class _SpaceAgeStarsOverlayState extends ConsumerState<SpaceAgeStarsOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Size _size = Size.zero;
  late final List<_Star> _stars;
  bool _spawned = false;

  static const _colors = [
    Color(0xFFffffff),
    Color(0xFF9FDBE6),
    Color(0xFFc8eef5),
    Color(0xFF6D8088),
  ];

  @override
  void initState() {
    super.initState();
    _stars = [];
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
      for (final s in _stars) s.update(dt);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpaceAge = ref.watch(themeNotifier) == AppTheme.galaxy;

    if (isSpaceAge && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!isSpaceAge && _ticker.isActive) {
      _ticker.stop();
    }

    if (!isSpaceAge) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(builder: (_, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_spawned && _size.width > 0) {
          final r = Random();
          _stars.addAll(List.generate(60, (_) => _Star.spawn(r, _size)));
          _spawned = true;
        }
        return CustomPaint(
          painter: _StarPainter(_stars, _colors),
          size: Size.infinite,
        );
      }),
    );
  }
}

class _Star {
  final double x, y, size;
  final int colorIdx;
  final double baseOpacity, amplitude, speed;
  double phase;

  _Star._({
    required this.x, required this.y, required this.size,
    required this.colorIdx, required this.baseOpacity,
    required this.amplitude, required this.speed, required this.phase,
  });

  factory _Star.spawn(Random r, Size screen) {
    final base = r.nextDouble() * 0.5 + 0.2;
    final amp = r.nextDouble() * 0.35 + 0.1;
    return _Star._(
      x: r.nextDouble() * screen.width,
      y: r.nextDouble() * screen.height,
      size: r.nextDouble() < 0.15 ? r.nextDouble() * 2 + 2 : r.nextDouble() * 1.2 + 0.6,
      colorIdx: r.nextInt(4),
      baseOpacity: (base + amp).clamp(0.1, 0.85) - amp,
      amplitude: amp,
      speed: r.nextDouble() * 5 + 3,
      phase: r.nextDouble() * 2 * pi,
    );
  }

  void update(double dt) {
    phase += speed * dt;
  }

  double get opacity => (baseOpacity + amplitude * sin(phase)).clamp(0.05, 1.0);
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final List<Color> colors;
  _StarPainter(this.stars, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      paint.color = colors[s.colorIdx].withValues(alpha: s.opacity);
      canvas.drawCircle(Offset(s.x, s.y), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => true;
}
