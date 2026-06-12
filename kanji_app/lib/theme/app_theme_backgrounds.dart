// Animated decorative backgrounds for themed screens.
// Place as first child of a Stack (behind content):
//   Stack(children: [
//     if (needsBg) ThemedBackground(theme: theme),
//     YourContent(),
//   ]);
// Use transparentScaffold: true in buildTheme() for galaxy.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../theme_provider.dart';

/// Returns the decorative background for themes that need one.
/// Returns SizedBox.shrink() for all others.
class ThemedBackground extends StatelessWidget {
  final AppTheme theme;
  final bool animate;
  const ThemedBackground({super.key, required this.theme, this.animate = true});

  @override
  Widget build(BuildContext context) {
    return switch (theme) {
      AppTheme.galaxy => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF0C1238), Color(0xFF05060F)],
              ),
            ),
          )),
          Positioned.fill(child: _StarfieldLayer(animate: animate)),
        ]),
      AppTheme.loveLetter => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF4FA), Color(0xFFF6F9FC), Color(0xFFEDF1F6)],
                stops: [0, 0.55, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _SnowLayer(animate: animate))),
          Positioned.fill(child: IgnorePointer(child: _SparkleLayer(animate: animate))),
          Positioned.fill(child: IgnorePointer(child: _SilverTwinkleLayer(animate: animate))),
        ]),
      AppTheme.lily => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF4EA), Color(0xFFF3F7EF), Color(0xFFE8F0E6)],
                stops: [0, 0.5, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _HazeLayer(animate: animate))),
          Positioned.fill(child: IgnorePointer(child: _GentleRainLayer(animate: animate))),
        ]),
      AppTheme.totoro => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF0D8), Color(0xFFF1F3E2), Color(0xFFEEF1DE)],
                stops: [0, 0.6, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _LeavesLayer(animate: animate))),
        ]),
      AppTheme.midnightCity => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF000000), Color(0xFF1A2C38), Color(0xFF2F4550)],
                stops: [0, 0.55, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _CityLayer(animate: animate))),
        ]),
      _ => const SizedBox.shrink(),
    };
  }
}

// ── Shared ticker driver ─────────────────────────────────────────
class _Ticking extends StatefulWidget {
  final bool animate;
  final Duration period;
  final Widget Function(double t) build;
  const _Ticking({required this.animate, required this.period, required this.build});
  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);
  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (_, __) => widget.build(_c.value));
}

// ════ GALAXY — starfield with shooting star ══════════════════════
class _StarfieldLayer extends StatelessWidget {
  final bool animate;
  const _StarfieldLayer({required this.animate});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: _Ticking(
      animate: animate,
      period: const Duration(seconds: 8),
      build: (v) => CustomPaint(painter: _StarPainter(v), size: Size.infinite),
    ),
  );
}

class _Star {
  final double x, y, s, phase, hue;
  const _Star(this.x, this.y, this.s, this.phase, this.hue);
}

final List<_Star> _stars = () {
  final r = math.Random(20260529);
  return List.generate(78, (_) {
    final big = r.nextDouble() > 0.86;
    return _Star(r.nextDouble(), r.nextDouble(),
        big ? 1.8 + r.nextDouble() * 1.6 : 0.7 + r.nextDouble() * 1.3,
        r.nextDouble(), r.nextDouble());
  });
}();

class _StarPainter extends CustomPainter {
  final double t;
  const _StarPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final st in _stars) {
      final tw = 0.18 + 0.82 * (0.5 + 0.5 * math.sin((t + st.phase) * 2 * math.pi));
      final base = st.hue > 0.7
          ? const Color(0xFFBCD2FF)
          : (st.hue > 0.5 ? const Color(0xFFC8F6FF) : Colors.white);
      p.color = base.withValues(alpha: tw);
      final c = Offset(st.x * size.width, st.y * size.height);
      if (st.s > 1.8) {
        p.maskFilter = MaskFilter.blur(BlurStyle.normal, st.s * 1.2);
        canvas.drawCircle(c, st.s, p);
        p.maskFilter = null;
      }
      canvas.drawCircle(c, st.s * 0.6, p);
    }
    // shooting star
    final sp = (t * 1.0) % 1.0;
    if (sp < 0.25) {
      final prog = sp / 0.25;
      final x = -40 + prog * (size.width + 80);
      final y = size.height * 0.2 + prog * size.height * 0.45;
      final paint = Paint()
        ..shader = const LinearGradient(colors: [Colors.transparent, Color(0xFFCFE0FF)])
            .createShader(Rect.fromLTWH(x - 70, y - 30, 80, 40))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - 70, y - 30), Offset(x, y), paint);
    }
  }
  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}

// ════ TETRIS — retro grid, falling blocks, scanlines ════════════
class _RetroLayer extends StatelessWidget {
  final bool animate;
  const _RetroLayer({required this.animate});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: _Ticking(
      animate: animate,
      period: const Duration(seconds: 10),
      build: (v) => CustomPaint(painter: _RetroPainter(v), size: Size.infinite),
    ),
  );
}

const _tetro = [
  Color(0xFF00E0E0), Color(0xFFFFE14D), Color(0xFFB14DFF), Color(0xFF4DFF6A),
  Color(0xFFFF5277), Color(0xFF4D7CFF), Color(0xFFFF9E3D),
];

class _RetroPainter extends CustomPainter {
  final double t;
  const _RetroPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    // grid
    final grid = Paint()
      ..color = const Color(0xFF7896FF).withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 26.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // falling tetromino blocks
    for (int i = 0; i < 9; i++) {
      final x = ((i * 11 + 4) % 95) / 100 * size.width;
      final dur = 7 + (i % 4) * 1.6;
      final prog = ((t * 10 / dur) + i * 0.14) % 1.0;
      final y = prog * (size.height + 40) - 40;
      final sz = 14.0 + (i % 3) * 7;
      final c = _tetro[i % _tetro.length];
      final fill = Paint()..color = c.withValues(alpha: 0.16);
      final stroke = Paint()
        ..color = c.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rect = Rect.fromLTWH(x, y, sz, sz);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
    // scanlines
    final scan = Paint()..color = Colors.black.withValues(alpha: 0.16);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
  }
  @override
  bool shouldRepaint(_RetroPainter old) => old.t != t;
}

// ════ SNOW (Love Letter) — snowbound, overexposed bloom ═════════
class _SnowLayer extends StatelessWidget {
  final bool animate;
  const _SnowLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 13),
        build: (v) => CustomPaint(painter: _SnowPainter(v), size: Size.infinite),
      );
}

class _Flake { final double x, s, off, speed, sway, op; _Flake(this.x, this.s, this.off, this.speed, this.sway, this.op); }
final List<_Flake> _flakes = () {
  final r = math.Random(11);
  return List.generate(46, (_) => _Flake(
      r.nextDouble(), 3 + r.nextDouble() * 6, r.nextDouble(),
      0.6 + r.nextDouble() * 0.7, r.nextDouble() * 30 - 15, 0.4 + r.nextDouble() * 0.5));
}();

class _SnowPainter extends CustomPainter {
  final double t;
  _SnowPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final bloom = Paint()
      ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: Offset(size.width / 2, -size.height * 0.1), radius: size.width * 0.8));
    canvas.drawRect(Offset.zero & size, bloom);
    final p = Paint();
    for (final f in _flakes) {
      final prog = (t * f.speed + f.off) % 1.0;
      final x = f.x * size.width + math.sin(prog * 6.28) * f.sway;
      final y = prog * (size.height + 20) - 20;
      p.color = Colors.white.withValues(alpha: f.op);
      p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(Offset(x, y), f.s / 2, p);
    }
  }
  @override
  bool shouldRepaint(_SnowPainter old) => old.t != t;
}

// ════ SPARKLE (Love Letter) — twinkling soft stars ══════════════
class _SparkleLayer extends StatelessWidget {
  final bool animate;
  const _SparkleLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 6),
        build: (v) => CustomPaint(painter: _SparklePainter(v), size: Size.infinite),
      );
}

class _SparkleData { final double x, y, size, phase, speed; _SparkleData(this.x, this.y, this.size, this.phase, this.speed); }
final List<_SparkleData> _sparklePoints = () {
  final r = math.Random(77);
  return List.generate(22, (_) => _SparkleData(
    r.nextDouble(), r.nextDouble(),
    3.0 + r.nextDouble() * 4.0,
    r.nextDouble(),
    0.4 + r.nextDouble() * 0.6,
  ));
}();

class _SparklePainter extends CustomPainter {
  final double t;
  _SparklePainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in _sparklePoints) {
      final alpha = ((math.sin((t * s.speed + s.phase) * math.pi * 2) + 1) / 2);
      if (alpha < 0.02) continue;
      final cx = s.x * size.width;
      final cy = s.y * size.height;
      final r = s.size;
      final rd = r * 0.55;
      p.color = const Color(0xFFB8D0F0).withValues(alpha: alpha * 0.7);
      p.strokeWidth = 1.2;
      p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
      canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), p);
      canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), p);
      canvas.drawLine(Offset(cx - rd, cy - rd), Offset(cx + rd, cy + rd), p);
      canvas.drawLine(Offset(cx + rd, cy - rd), Offset(cx - rd, cy + rd), p);
    }
  }
  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

// ════ HAZE (Lily) — overexposed paddy haze, lens flares ═════════
class _HazeLayer extends StatelessWidget {
  final bool animate;
  const _HazeLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 16),
        build: (v) => CustomPaint(painter: _HazePainter(v), size: Size.infinite),
      );
}

class _HazePainter extends CustomPainter {
  final double t;
  _HazePainter(this.t);
  static const _flares = [
    [0.68, 0.22, 62.0, 0.18], [0.56, 0.37, 26.0, 0.14], [0.45, 0.50, 40.0, 0.12],
    [0.33, 0.63, 18.0, 0.10], [0.24, 0.73, 54.0, 0.10],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final bloom = Paint()
      ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.95), const Color(0x00E8F6E4)])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.05), radius: size.width * 0.7));
    canvas.drawRect(Offset.zero & size, bloom);
    for (final f in _flares) {
      final c = Offset(f[0] * size.width, f[1] * size.height);
      final ring = Paint()
        ..color = const Color(0xFFB9E8C4).withValues(alpha: f[3])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(c, f[2] / 2, ring);
      canvas.drawCircle(c, f[2] / 2,
          Paint()..color = const Color(0xFFB9E8C4).withValues(alpha: f[3] * 0.6));
    }
    final r = math.Random(50);
    final dot = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    for (int i = 0; i < 18; i++) {
      final x = r.nextDouble(), s = 2 + r.nextDouble() * 3, off = r.nextDouble(), speed = 0.4 + r.nextDouble() * 0.5;
      final prog = (t * speed + off) % 1.0;
      dot.color = Colors.white.withValues(alpha: (0.6 * (1 - (prog - 0.5).abs() * 2)).clamp(0.0, 0.6));
      canvas.drawCircle(Offset(x * size.width, size.height - prog * (size.height + 40)), s / 2, dot);
    }
  }
  @override
  bool shouldRepaint(_HazePainter old) => old.t != t;
}

// ════ LEAVES (Totoro) — warm countryside, sun shaft ═════════════
class _LeavesLayer extends StatelessWidget {
  final bool animate;
  const _LeavesLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 14),
        build: (v) => CustomPaint(painter: _LeafPainter(v), size: Size.infinite),
      );
}

class _Leaf { final double x, s, off, speed, sway, rot; final Color c; _Leaf(this.x, this.s, this.off, this.speed, this.sway, this.rot, this.c); }
final List<_Leaf> _leaves = () {
  final r = math.Random(33);
  return List.generate(16, (_) => _Leaf(
      r.nextDouble(), 8 + r.nextDouble() * 8, r.nextDouble(), 0.5 + r.nextDouble() * 0.6,
      r.nextDouble() * 40 - 20, r.nextDouble() * 6.28,
      r.nextDouble() > 0.5 ? const Color(0xFF6B9A52) : const Color(0xFF86B35E)));
}();

class _LeafPainter extends CustomPainter {
  final double t;
  _LeafPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final shaft = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0x80FFFAD2), Color(0x00FFFAD2)], stops: [0, 0.55],
      ).createShader(Rect.fromLTWH(size.width * 0.05, -size.height * 0.1, size.width * 0.55, size.height * 0.85));
    canvas.drawRect(Offset.zero & size, shaft);
    for (final l in _leaves) {
      final prog = (t * l.speed + l.off) % 1.0;
      final x = l.x * size.width + math.sin(prog * 6.28) * l.sway;
      final y = prog * (size.height + 30) - 30;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(l.rot + prog * 6.28);
      final p = Paint()..color = l.c.withValues(alpha: 0.5);
      final rect = Rect.fromCenter(center: Offset.zero, width: l.s, height: l.s * 0.62);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topRight: Radius.circular(l.s), bottomLeft: Radius.circular(l.s)),
        p,
      );
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(_LeafPainter old) => old.t != t;
}

// ════ MIDNIGHT CITY (City Pop) — moon, stars, skyline ═══════════
class _CityLayer extends StatelessWidget {
  final bool animate;
  const _CityLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 6),
        build: (v) => CustomPaint(painter: _CityPainter(v), size: Size.infinite),
      );
}

class _Bld { final double x, w, h; final int seed; _Bld(this.x, this.w, this.h, this.seed); }
final List<_Bld> _buildings = () {
  final list = <_Bld>[];
  double x = 0; int i = 0;
  while (x < 100) {
    final r = math.Random(i * 97 + 5);
    final w = 6 + r.nextDouble() * 7, h = 14 + r.nextDouble() * 30;
    list.add(_Bld(x, w, h, i));
    x += w - 1; i++;
  }
  return list;
}();
final List<List<double>> _cityStars = () {
  final r = math.Random(77);
  return List.generate(38, (_) => [r.nextDouble(), r.nextDouble() * 0.46, 0.6 + r.nextDouble() * 1.4, r.nextDouble()]);
}();

class _CityPainter extends CustomPainter {
  final double t;
  _CityPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final sp = Paint();
    for (final s in _cityStars) {
      final tw = 0.2 + 0.8 * (0.5 + 0.5 * math.sin((t + s[3]) * 6.28));
      sp.color = const Color(0xFFF4F4F9).withValues(alpha: tw * 0.7);
      canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2] * 0.6, sp);
    }
    final skyTop = size.height * 0.58;
    for (final b in _buildings) {
      final bx = b.x / 100 * size.width;
      final bw = b.w / 100 * size.width;
      final bh = b.h / 100 * (size.height - skyTop) * 2.4;
      final rect = Rect.fromLTWH(bx, size.height - bh, bw, bh);
      canvas.drawRect(rect, Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2C38), Color(0xFF0A141C)]).createShader(rect));
      final r = math.Random(b.seed * 31 + 3);
      for (int wi = 0; wi < 3; wi++) {
        final wx = rect.left + bw * (0.2 + r.nextDouble() * 0.55);
        final wy = rect.top + bh * (0.1 + r.nextDouble() * 0.7);
        canvas.drawRect(Rect.fromLTWH(wx, wy, 2.5, 2.5),
            Paint()..color = (r.nextDouble() > 0.5 ? const Color(0xFFB8DBD9) : const Color(0xFFF4F4F9)));
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.16, size.height * 0.70, 26, 9), const Radius.circular(2)),
      Paint()..color = const Color(0xFFB8DBD9).withValues(alpha: 0.80)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.74, size.height * 0.64, 18, 7), const Radius.circular(2)),
      Paint()..color = const Color(0xFFF4F4F9).withValues(alpha: 0.75)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  @override
  bool shouldRepaint(_CityPainter old) => old.t != t;
}

// ════ SILVER TWINKLE (Love Letter) — silvery pulsing dots ═══════
class _SilverTwinkleLayer extends StatelessWidget {
  final bool animate;
  const _SilverTwinkleLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 7),
        build: (v) => CustomPaint(painter: _SilverTwinklePainter(v), size: Size.infinite),
      );
}

class _SilverDot { final double x, y, size, phase, speed; _SilverDot(this.x, this.y, this.size, this.phase, this.speed); }
final List<_SilverDot> _silverDots = () {
  final r = math.Random(44);
  return List.generate(55, (_) => _SilverDot(
    r.nextDouble(), r.nextDouble(),
    1.5 + r.nextDouble() * 3.0,
    r.nextDouble(),
    0.4 + r.nextDouble() * 0.6,
  ));
}();

class _SilverTwinklePainter extends CustomPainter {
  final double t;
  _SilverTwinklePainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final d in _silverDots) {
      final alpha = ((math.sin((t * d.speed + d.phase) * math.pi * 2) + 1) / 2);
      if (alpha < 0.05) continue;
      final useGold = d.phase > 0.65;
      p.color = (useGold
          ? const Color(0xFFB8C8D8)
          : const Color(0xFFD0DCE8))
          .withValues(alpha: alpha * 0.55);
      canvas.drawCircle(Offset(d.x * size.width, d.y * size.height), d.size * 0.55, p);
    }
  }
  @override
  bool shouldRepaint(_SilverTwinklePainter old) => old.t != t;
}

// ════ GENTLE RAIN (Lily / Chou-chou Green) — soft falling streaks ═
class _GentleRainLayer extends StatelessWidget {
  final bool animate;
  const _GentleRainLayer({required this.animate});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 5),
        build: (v) => CustomPaint(painter: _GentleRainPainter(v), size: Size.infinite),
      );
}

class _RainDrop { final double x, delay, dur, len, peak; _RainDrop(this.x, this.delay, this.dur, this.len, this.peak); }
final List<_RainDrop> _rainDrops = () {
  final r = math.Random(88);
  return List.generate(35, (_) => _RainDrop(
    r.nextDouble(),
    r.nextDouble(),
    0.4 + r.nextDouble() * 0.5,
    14 + r.nextDouble() * 22,
    0.18 + r.nextDouble() * 0.18,
  ));
}();

class _GentleRainPainter extends CustomPainter {
  final double t;
  _GentleRainPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..strokeCap = StrokeCap.round..strokeWidth = 1.5;
    for (final d in _rainDrops) {
      final prog = ((t / d.dur) + d.delay) % 1.0;
      final x = d.x * size.width;
      final yTop = prog * (size.height + d.len) - d.len;
      final yBot = yTop + d.len;
      if (yTop > size.height || yBot < 0) continue;
      final fadeIn  = (prog * 20).clamp(0.0, 1.0);
      final fadeOut = (1.0 - (prog - 0.9) * 10).clamp(0.0, 1.0);
      p.shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2858D8).withValues(alpha: d.peak * fadeIn * fadeOut),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(x - 1, yTop, 2, d.len));
      canvas.drawLine(Offset(x, yTop), Offset(x, yBot), p);
    }
  }
  @override
  bool shouldRepaint(_GentleRainPainter old) => old.t != t;
}

// ════ UNUSED ANIMATIONS — available for future themes ═══════════
// _AuroraWavesLayer, _FirefliesLayer, _ParticleDustLayer, _ShootingStarsLayer
// See DEVNOTES.md "Background animations" for usage notes.

class _AuroraWavesLayer extends StatelessWidget {
  final bool animate;
  final Color primary, deep, gold;
  const _AuroraWavesLayer({required this.animate, required this.primary, required this.deep, required this.gold});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 18),
        build: (v) => CustomPaint(painter: _AuroraPainter(v, primary, deep, gold), size: Size.infinite),
      );
}

class _AuroraPainter extends CustomPainter {
  final double t; final Color primary, deep, gold;
  _AuroraPainter(this.t, this.primary, this.deep, this.gold);
  static const _bands = [
    [0.15, 0.35, 0.0, 12.0],
    [0.30, 0.30, 3.0, 15.0],
    [0.05, 0.40, 6.0, 18.0],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [primary, deep, gold];
    for (int i = 0; i < _bands.length; i++) {
      final b = _bands[i];
      final shift = math.sin((t + b[2] / 18.0) * math.pi * 2) * 0.08;
      final scaleY = 1.0 + math.sin((t + b[2] / 18.0) * math.pi * 2) * 0.075;
      final centerY = (b[0] + shift) * size.height;
      final h = b[1] * size.height * scaleY;
      final alpha = 0.30 + 0.15 * math.sin((t + b[2] / 18.0) * math.pi * 2);
      final rect = Rect.fromCenter(center: Offset(size.width / 2, centerY), width: size.width * 1.6, height: h);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [colors[i].withValues(alpha: alpha * 0.22), Colors.transparent],
          radius: 0.6,
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawOval(rect, paint);
    }
  }
  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

class _FirefliesLayer extends StatelessWidget {
  final bool animate;
  final Color gold;
  const _FirefliesLayer({required this.animate, required this.gold});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 9),
        build: (v) => CustomPaint(painter: _FireflyPainter(v, gold), size: Size.infinite),
      );
}

class _FireflyData { final double x, y, size, phase, speed, peak; _FireflyData(this.x, this.y, this.size, this.phase, this.speed, this.peak); }
final List<_FireflyData> _fireflies = () {
  final r = math.Random(55);
  return List.generate(20, (_) => _FireflyData(
    r.nextDouble(), 0.2 + r.nextDouble() * 0.7,
    3 + r.nextDouble() * 5, r.nextDouble(),
    0.4 + r.nextDouble() * 0.5,
    0.5 + r.nextDouble() * 0.4,
  ));
}();

class _FireflyPainter extends CustomPainter {
  final double t; final Color gold;
  _FireflyPainter(this.t, this.gold);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final f in _fireflies) {
      final cycle = (t * f.speed + f.phase) % 1.0;
      final alpha = (math.sin(cycle * math.pi * 2) + 1) / 2;
      if (alpha < 0.05) continue;
      final dx = math.sin(cycle * math.pi * 4) * 8;
      final dy = math.cos(cycle * math.pi * 4) * 12;
      p.color = gold.withValues(alpha: alpha * f.peak);
      canvas.drawCircle(Offset(f.x * size.width + dx, f.y * size.height + dy), f.size / 2, p);
    }
  }
  @override
  bool shouldRepaint(_FireflyPainter old) => old.t != t;
}

class _ParticleDustLayer extends StatelessWidget {
  final bool animate;
  final Color primary, gold;
  const _ParticleDustLayer({required this.animate, required this.primary, required this.gold});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 14),
        build: (v) => CustomPaint(painter: _DustPainter(v, primary, gold), size: Size.infinite),
      );
}

class _DustMote { final double x, y, size, phase, speed, dx, dy, peak; final bool useGold; _DustMote(this.x, this.y, this.size, this.phase, this.speed, this.dx, this.dy, this.peak, this.useGold); }
final List<_DustMote> _dustMotes = () {
  final r = math.Random(66);
  return List.generate(30, (_) => _DustMote(
    r.nextDouble(), r.nextDouble(), 2 + r.nextDouble() * 3.5,
    r.nextDouble(), 0.4 + r.nextDouble() * 0.5,
    -15 + r.nextDouble() * 30, -20 + r.nextDouble() * 10,
    0.35 + r.nextDouble() * 0.4, r.nextDouble() > 0.5,
  ));
}();

class _DustPainter extends CustomPainter {
  final double t; final Color primary, gold;
  _DustPainter(this.t, this.primary, this.gold);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (final m in _dustMotes) {
      final cycle = (t * m.speed + m.phase) % 1.0;
      double alpha;
      if (cycle < 0.3) alpha = cycle / 0.3;
      else if (cycle < 0.6) alpha = 1.0;
      else if (cycle < 0.8) alpha = 0.05;
      else alpha = (cycle - 0.8) / 0.2;
      if (alpha < 0.03) continue;
      final ox = m.dx * cycle;
      final oy = m.dy * cycle;
      final c = m.useGold ? gold : primary;
      p.color = c.withValues(alpha: alpha * m.peak * 0.35);
      canvas.drawCircle(Offset(m.x * size.width + ox, m.y * size.height + oy), m.size / 2, p);
    }
  }
  @override
  bool shouldRepaint(_DustPainter old) => old.t != t;
}

class _ShootingStarsLayer extends StatelessWidget {
  final bool animate;
  final Color accent;
  const _ShootingStarsLayer({required this.animate, required this.accent});
  @override
  Widget build(BuildContext context) => _Ticking(
        animate: animate, period: const Duration(seconds: 10),
        build: (v) => CustomPaint(painter: _ShootingStarPainter(v, accent), size: Size.infinite),
      );
}

class _ShootingStar { final double x, y, angle, len, delay, dur; _ShootingStar(this.x, this.y, this.angle, this.len, this.delay, this.dur); }
final List<_ShootingStar> _shootingStars = () {
  final r = math.Random(22);
  return List.generate(4, (_) => _ShootingStar(
    0.1 + r.nextDouble() * 0.6, r.nextDouble() * 0.3,
    (35 + r.nextDouble() * 20) * math.pi / 180,
    60 + r.nextDouble() * 100,
    r.nextDouble() * 8, 1.0 + r.nextDouble() * 0.8,
  ));
}();

class _ShootingStarPainter extends CustomPainter {
  final double t; final Color accent;
  _ShootingStarPainter(this.t, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _shootingStars) {
      final cycle = ((t * 10 / s.dur) + s.delay / s.dur) % (10 / s.dur);
      final prog = (cycle * s.dur / 10).clamp(0.0, 1.0);
      if (prog > 0.6) continue;
      final alpha = prog < 0.05 ? prog / 0.05 : (1.0 - prog / 0.6);
      final ox = math.cos(s.angle) * prog * s.len;
      final oy = math.sin(s.angle) * prog * s.len;
      final x0 = s.x * size.width;
      final y0 = s.y * size.height;
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, accent.withValues(alpha: alpha * 0.85)],
        ).createShader(Rect.fromPoints(Offset(x0, y0), Offset(x0 + ox, y0 + oy)))
        ..strokeWidth = 1.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x0, y0), Offset(x0 + ox, y0 + oy), paint);
      canvas.drawCircle(Offset(x0 + ox, y0 + oy), 2.5,
          Paint()..color = accent.withValues(alpha: alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }
  @override
  bool shouldRepaint(_ShootingStarPainter old) => old.t != t;
}

// ── Drop inside a Stack as first child to show themed backgrounds ──
class HomeBgLayer extends ConsumerWidget {
  const HomeBgLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifier);
    final animate = ref.watch(settingsProvider).animationsEnabled;
    return switch (theme) {
      AppTheme.galaxy => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF0C1238), Color(0xFF05060F)],
              ),
            ),
          )),
          Positioned.fill(child: _StarfieldLayer(animate: animate)),
        ]),
      AppTheme.loveLetter => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF4FA), Color(0xFFF6F9FC), Color(0xFFEDF1F6)],
                stops: [0, 0.55, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _SnowLayer(animate: animate))),
          Positioned.fill(child: IgnorePointer(child: _SparkleLayer(animate: animate))),
          Positioned.fill(child: IgnorePointer(child: _SilverTwinkleLayer(animate: animate))),
        ]),
      AppTheme.lily => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF4EA), Color(0xFFF3F7EF), Color(0xFFE8F0E6)],
                stops: [0, 0.5, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _HazeLayer(animate: animate))),
          Positioned.fill(child: IgnorePointer(child: _GentleRainLayer(animate: animate))),
        ]),
      AppTheme.totoro => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF0D8), Color(0xFFF1F3E2), Color(0xFFEEF1DE)],
                stops: [0, 0.6, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _LeavesLayer(animate: animate))),
        ]),
      AppTheme.midnightCity => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF000000), Color(0xFF1A2C38), Color(0xFF2F4550)],
                stops: [0, 0.55, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _CityLayer(animate: animate))),
        ]),
      _ => const SizedBox.shrink(),
    };
  }
}
