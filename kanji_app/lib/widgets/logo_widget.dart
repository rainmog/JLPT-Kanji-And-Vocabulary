import 'package:flutter/material.dart';
import '../theme.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  const LogoWidget({super.key, this.size = 220});

  @override
  Widget build(BuildContext context) {
    final pageW = size * 0.44;
    final pageH = size * 0.575;
    final spineW = size * 0.06;
    final radius = size * 0.035;
    final lineH = size * 0.014;
    final lineColor = AppColors.muted.withValues(alpha: 0.55);
    final lineDecor = BoxDecoration(
      color: lineColor,
      borderRadius: BorderRadius.circular(2),
    );
    final pad = size * 0.08;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Book icon
        SizedBox(
          height: pageH,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left page
              Container(
                width: pageW,
                height: pageH,
                decoration: BoxDecoration(
                  color: AppColors.btnBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    bottomLeft: Radius.circular(radius),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 1.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: lineH, decoration: lineDecor),
                    SizedBox(height: size * 0.065),
                    Container(width: double.infinity, height: lineH, decoration: lineDecor),
                    SizedBox(height: size * 0.065),
                    Container(width: double.infinity, height: lineH, decoration: lineDecor),
                    SizedBox(height: size * 0.065),
                    Container(width: pageW * 0.5, height: lineH, decoration: lineDecor),
                  ],
                ),
              ),
              // Spine
              Container(width: spineW, height: pageH, color: AppColors.accent),
              // Right page
              Container(
                width: pageW,
                height: pageH,
                decoration: BoxDecoration(
                  color: AppColors.pillBg,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(radius),
                    bottomRight: Radius.circular(radius),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '語',
                  style: TextStyle(
                    fontSize: size * 0.255,
                    fontWeight: FontWeight.bold,
                    color: AppColors.kanjiColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: size * 0.08),

        // Divider
        Container(
          width: size * 0.7,
          height: 1,
          color: AppColors.accent.withValues(alpha: 0.4),
        ),

        SizedBox(height: size * 0.07),

        // JLPT
        Text(
          'JLPT',
          style: TextStyle(
            fontSize: size * 0.345,
            fontWeight: FontWeight.w800,
            color: AppColors.fg,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),

        SizedBox(height: size * 0.025),

        // Subtitle
        Text(
          'KANJI & VOCABULARY',
          style: TextStyle(
            fontSize: size * 0.065,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
            letterSpacing: size * 0.025,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
