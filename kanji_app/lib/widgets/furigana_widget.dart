import 'package:flutter/material.dart';
import '../theme.dart';

class FuriganaWidget extends StatelessWidget {
  final String meaning;
  final String onReading;
  final String kunReading;
  final String furigana;
  final String kanjiForm;

  const FuriganaWidget({
    super.key,
    required this.meaning,
    required this.onReading,
    required this.kunReading,
    required this.furigana,
    required this.kanjiForm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pillBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        children: [
          Text(meaning.toUpperCase(),
            style: TextStyle(fontSize: 9, color: AppColors.muted, letterSpacing: 1)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _readingBlock('ON', onReading),
              Container(width: 1, height: 28, color: const Color(0xFF1a2a38), margin: const EdgeInsets.symmetric(horizontal: 10)),
              _readingBlock('KUN', kunReading),
            ],
          ),
          const SizedBox(height: 5),
          Text(furigana,
            style: TextStyle(fontSize: 10, color: AppColors.accentBright)),
          const SizedBox(height: 3),
          Text(kanjiForm,
            style: TextStyle(fontSize: 20, color: AppColors.kanjiColor)),
        ],
      ),
    );
  }

  Widget _readingBlock(String label, String reading) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 7, color: Color(0xFF223344), letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(reading, style: TextStyle(fontSize: 10, color: Color(0xFF4d7799))),
    ]);
  }
}
