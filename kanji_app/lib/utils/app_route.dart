import 'package:flutter/material.dart';

class AppRoute {
  static bool animationsEnabled = true;

  static Route<T> to<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: animationsEnabled
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      reverseTransitionDuration: animationsEnabled
          ? const Duration(milliseconds: 150)
          : Duration.zero,
      transitionsBuilder: animationsEnabled
          ? (_, animation, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              )
          : (_, __, ___, child) => child,
    );
  }
}
