import 'package:flutter/material.dart';
import '../theme_provider.dart';
import '../theme.dart';

/// Shown when fewer targets exist than the requested session size.
/// Returns true if the user wants to continue with the shorter [available]
/// session, false (or null) to cancel.
Future<bool> confirmShortSession(
  BuildContext context, {
  required ThemeColors colors,
  required int available,
  required int requested,
  String noun = 'questions',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Not enough targets',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.fg),
      ),
      content: Text(
        "You asked for $requested $noun but only $available are available with your "
        "current targets. Continue with a shorter session of $available?",
        style: TextStyle(fontSize: 14.5, color: KDesign.inkSoft(colors), height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Continue with $available',
              style: TextStyle(color: colors.accent, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return result ?? false;
}
