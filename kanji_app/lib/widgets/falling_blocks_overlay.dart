import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FallingBlocksOverlay extends ConsumerStatefulWidget {
  const FallingBlocksOverlay({super.key});

  @override
  ConsumerState<FallingBlocksOverlay> createState() => _FallingBlocksOverlayState();
}

class _FallingBlocksOverlayState extends ConsumerState<FallingBlocksOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Size _size = const Size(400, 800);
  final _random = Random();
  late final List<_Block> _blocks;

  static const _colors = [
    Color(0xFF00E0E0), // cyan
    Color(0xFFFFE14D), // yellow
    Color(0xFFB14DFF), // purple
    Color(0xFF4DFF6A), // green
    Color(0xFFFF5277), // red
    Color(0xFF4D7CFF), // blue
    Color(0xFFFF9E3D), // orange
  ];

  @override
  void initState() {
    super.initState();
    _blocks = List.generate(16, (_) => _Block.spawn(_random, _size, scattered: true));
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
      for (final b in _blocks) b.update(dt, _size, _random);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ticker.isActive) _ticker.stop();
    return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(builder: (_, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          painter: _BlockPainter(_blocks, _colors),
          size: Size.infinite,
        );
      }),
    );
  }
}

class _Block {
  double x, y, vy, rotation, rotSpeed, size, opacity;
  int colorIdx;

  _Block._({
    required this.x, required this.y, required this.vy,
    required this.rotation, required this.rotSpeed,
    required this.size, required this.opacity, required this.colorIdx,
  });

  factory _Block.spawn(Random r, Size screen, {bool scattered = false}) => _Block._(
    x: r.nextDouble() * screen.width,
    y: scattered ? r.nextDouble() * screen.height : -(r.nextDouble() * 80 + 10),
    vy: r.nextDouble() * 50 + 30,
    rotation: r.nextDouble() * 2 * pi,
    rotSpeed: (r.nextDouble() - 0.5) * 2.0,
    size: r.nextDouble() * 10 + 8,
    opacity: r.nextDouble() * 0.16 + 0.08,
    colorIdx: r.nextInt(7),
  );

  void update(double dt, Size screen, Random r) {
    y += vy * dt;
    rotation += rotSpeed * dt;
    if (y > screen.height + 20) {
      final next = _Block.spawn(r, screen);
      x = next.x; y = next.y; vy = next.vy;
      rotation = next.rotation; rotSpeed = next.rotSpeed;
      size = next.size; opacity = next.opacity; colorIdx = next.colorIdx;
    }
  }
}

class _BlockPainter extends CustomPainter {
  final List<_Block> blocks;
  final List<Color> colors;
  _BlockPainter(this.blocks, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (final b in blocks) {
      final c = colors[b.colorIdx];
      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.rotate(b.rotation);
      final half = b.size / 2;
      final rect = Rect.fromLTWH(-half, -half, b.size, b.size);
      fill.color = c.withValues(alpha: b.opacity);
      stroke.color = c.withValues(alpha: b.opacity + 0.08);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BlockPainter old) => true;
}
