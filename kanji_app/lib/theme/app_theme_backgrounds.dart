// Animated decorative backgrounds for themed screens.
// Place as first child of a Stack (behind content):
//   Stack(children: [
//     if (needsBg) ThemedBackground(theme: theme),
//     YourContent(),
//   ]);
// Use transparentScaffold: true in buildTheme() for galaxy/tetris.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      AppTheme.tetris => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF11142B), Color(0xFF0A0C1C)],
              ),
            ),
          )),
          Positioned.fill(child: _RetroLayer(animate: animate)),
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
                colors: [Color(0xFF070627), Color(0xFF160A3A), Color(0xFF2A1150)],
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
      p.color = Colors.white.withValues(alpha: alpha * 0.7);
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
    final moonC = Offset(size.width * 0.82, size.height * 0.12);
    canvas.drawCircle(moonC, 32,
        Paint()..color = const Color(0xFFB4A0FF).withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawCircle(moonC, 32,
        Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Color(0xFFFDF6FF), Color(0xFFCDBFF0)])
            .createShader(Rect.fromCircle(center: moonC, radius: 32)));
    final sp = Paint();
    for (final s in _cityStars) {
      final tw = 0.2 + 0.8 * (0.5 + 0.5 * math.sin((t + s[3]) * 6.28));
      sp.color = Colors.white.withValues(alpha: tw);
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
            colors: [Color(0xFF120A2E), Color(0xFF0A0620)]).createShader(rect));
      final r = math.Random(b.seed * 31 + 3);
      for (int wi = 0; wi < 3; wi++) {
        final wx = rect.left + bw * (0.2 + r.nextDouble() * 0.55);
        final wy = rect.top + bh * (0.1 + r.nextDouble() * 0.7);
        canvas.drawRect(Rect.fromLTWH(wx, wy, 2.5, 2.5),
            Paint()..color = (r.nextDouble() > 0.5 ? const Color(0xFF35E0FF) : const Color(0xFFFFD66B)));
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.16, size.height * 0.70, 26, 9), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFF5ED6).withValues(alpha: 0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.74, size.height * 0.64, 18, 7), const Radius.circular(2)),
      Paint()..color = const Color(0xFF35E0FF).withValues(alpha: 0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  @override
  bool shouldRepaint(_CityPainter old) => old.t != t;
}

// ── Drop inside a Stack as first child to show themed backgrounds ──
class HomeBgLayer extends ConsumerWidget {
  const HomeBgLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifier);
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
          Positioned.fill(child: _StarfieldLayer(animate: true)),
        ]),
      AppTheme.tetris => Stack(children: [
          const Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF11142B), Color(0xFF0A0C1C)],
              ),
            ),
          )),
          Positioned.fill(child: _RetroLayer(animate: true)),
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
          const Positioned.fill(child: IgnorePointer(child: _SnowLayer(animate: true))),
          const Positioned.fill(child: IgnorePointer(child: _SparkleLayer(animate: true))),
        ]),
      AppTheme.lily => const Stack(children: [
          Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF4EA), Color(0xFFF3F7EF), Color(0xFFE8F0E6)],
                stops: [0, 0.5, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _HazeLayer(animate: true))),
        ]),
      AppTheme.totoro => const Stack(children: [
          Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF0D8), Color(0xFFF1F3E2), Color(0xFFEEF1DE)],
                stops: [0, 0.6, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _LeavesLayer(animate: true))),
        ]),
      AppTheme.midnightCity => const Stack(children: [
          Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF070627), Color(0xFF160A3A), Color(0xFF2A1150)],
                stops: [0, 0.55, 1],
              ),
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: _CityLayer(animate: true))),
        ]),
      _ => const SizedBox.shrink(),
    };
  }
}
