import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

class ScaleOnPress extends ConsumerStatefulWidget {
  final Widget child;
  const ScaleOnPress({super.key, required this.child});

  @override
  ConsumerState<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends ConsumerState<ScaleOnPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = ref.watch(settingsProvider).animationsEnabled;
    return Listener(
      onPointerDown: (_) { if (anim) _ctrl.forward(); },
      onPointerUp: (_) { if (anim) _ctrl.reverse(); },
      onPointerCancel: (_) { if (anim) _ctrl.reverse(); },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: anim ? 1.0 - 0.04 * _ctrl.value : 1.0,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
