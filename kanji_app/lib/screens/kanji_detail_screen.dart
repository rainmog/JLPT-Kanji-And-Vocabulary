import 'package:flutter/material.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/sentence_repository.dart';
import '../services/database_service.dart';
import '../theme.dart';

class KanjiDetailScreen extends StatelessWidget {
  final Kanji kanji;
  const KanjiDetailScreen({super.key, required this.kanji});

  Future<List<SentenceToken>> _fetchSentences() async {
    final rows = await dbService.query(
      'SELECT text_kanji, english_translation FROM sentences WHERE kanji_id = ? LIMIT 9',
      [kanji.id],
    );
    return rows.map((r) => SentenceToken(
      surface: r['text_kanji'] as String,
      reading: r['english_translation'] as String,
      isKanji: false,
      kanjiChar: null,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(kanji.character, style: TextStyle(color: AppColors.kanjiColor, fontSize: 24)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kanji.meaning, style: TextStyle(color: AppColors.fg, fontSize: 23)),
            const SizedBox(height: 16),
            _row('JLPT', 'N${kanji.jlptLevel}'),
            _row('On', kanji.onReading),
            _row('Kun', kanji.kunReading),
            _row('Strokes', '${kanji.strokeCount}'),
            const SizedBox(height: 24),
            Text('Example Sentences', style: TextStyle(color: AppColors.fg, fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FutureBuilder<List<SentenceToken>>(
              future: _fetchSentences(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No example sentences', style: TextStyle(color: AppColors.muted, fontSize: 12));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snapshot.data!.map((s) {
                    final sent = s.surface; // text_kanji
                    final trans = s.reading; // english_translation
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.pillBg,
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sent, style: TextStyle(color: AppColors.kanjiColor, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(trans, style: TextStyle(color: AppColors.muted, fontSize: 16)),
                        ]),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 70, child: Text(label, style: TextStyle(color: AppColors.muted, fontSize: 14))),
      Text(value, style: TextStyle(color: AppColors.fg, fontSize: 18)),
    ]),
  );
}
