import 'package:flutter/material.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/database_service.dart';
import '../theme.dart';

// ── Kanji info content ────────────────────────────────────────────────────────

class KanjiInfoContent extends StatelessWidget {
  final Kanji kanji;
  const KanjiInfoContent({super.key, required this.kanji});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            kanji.character,
            style: TextStyle(
              fontSize: 48,
              color: AppColors.kanjiColor,
              fontFamily: AppFonts.japaneseFont,
              fontFamilyFallback: AppFonts.japaneseFallback,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'JLPT N${kanji.jlptLevel}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (kanji.onReading.isNotEmpty) _infoRow('On', kanji.onReading),
        if (kanji.kunReading.isNotEmpty) _infoRow('Kun', kanji.kunReading),
        const SizedBox(height: 4),
        Text(
          kanji.meaning,
          style: TextStyle(fontSize: 16, color: AppColors.fg, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Text(
          'Example Sentences',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.muted, letterSpacing: 0.4),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: dbService.query(
            'SELECT text_kanji, english_translation FROM sentences WHERE kanji_id=? ORDER BY RANDOM() LIMIT 5',
            [kanji.id],
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return Text('There are no sentences for this kanji.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted));
            }
            return Column(
              children: rows.map((r) => _sentenceCard(
                r['text_kanji'] as String,
                r['english_translation'] as String,
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(
        width: 40,
        child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.fg,
            fontFamily: AppFonts.japaneseFont,
            fontFamilyFallback: AppFonts.japaneseFallback,
          ),
        ),
      ),
    ]),
  );
}

// ── Vocab info content ────────────────────────────────────────────────────────

class VocabInfoContent extends StatelessWidget {
  final VocabWord word;
  const VocabInfoContent({super.key, required this.word});

  List<String> _topMeanings() {
    final raw = word.meanings;
    final parts = raw.split(RegExp(r'[;,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final showReading = word.word != word.reading;
    final meanings = _topMeanings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                word.word,
                style: TextStyle(
                  fontSize: 48,
                  color: AppColors.kanjiColor,
                  fontFamily: AppFonts.japaneseFont,
                  fontFamilyFallback: AppFonts.japaneseFallback,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showReading)
                Text(
                  word.reading,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.muted,
                    fontFamily: AppFonts.japaneseFont,
                    fontFamilyFallback: AppFonts.japaneseFallback,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (word.isUsuallyKana)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Usually written in kana',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.accent, fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ...meanings.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• $m',
            style: TextStyle(fontSize: 15, color: AppColors.fg, fontWeight: FontWeight.w600),
          ),
        )),
        const SizedBox(height: 20),
        Text(
          'Example Sentences',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.muted, letterSpacing: 0.4),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: dbService.query(
            'SELECT text_kanji, english_translation FROM sentences WHERE text_kanji LIKE ? ORDER BY RANDOM() LIMIT 5',
            ['%${word.word}%'],
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return Text('There are no sentences for this word.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted));
            }
            return Column(
              children: rows.map((r) => _sentenceCard(
                r['text_kanji'] as String,
                r['english_translation'] as String,
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Kana info content ─────────────────────────────────────────────────────────

class KanaInfoContent extends StatelessWidget {
  final KanaCharacter char;
  const KanaInfoContent({super.key, required this.char});

  @override
  Widget build(BuildContext context) {
    final typeLabel = char.type == 'hiragana' ? 'Hiragana' : 'Katakana';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            char.character,
            style: TextStyle(
              fontSize: 48,
              color: AppColors.kanjiColor,
              fontFamily: AppFonts.japaneseFont,
              fontFamilyFallback: AppFonts.japaneseFallback,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            char.romaji,
            style: TextStyle(fontSize: 28, color: AppColors.muted, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Related Words',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.muted, letterSpacing: 0.4),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: dbService.query(
            'SELECT word, meaning FROM kana_words WHERE type=? ORDER BY RANDOM() LIMIT 3',
            [char.type],
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return Text('No related words.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted));
            }
            return Column(
              children: rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text(
                    r['word'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.kanjiColor,
                      fontFamily: AppFonts.japaneseFont,
                      fontFamilyFallback: AppFonts.japaneseFallback,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    r['meaning'] as String,
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ]),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Shared sentence card ──────────────────────────────────────────────────────

Widget _sentenceCard(String japanese, String english) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.pillBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        japanese,
        style: TextStyle(
          fontSize: 15,
          color: AppColors.kanjiColor,
          fontFamily: AppFonts.japaneseFont,
          fontFamilyFallback: AppFonts.japaneseFallback,
        ),
      ),
      const SizedBox(height: 4),
      Text(english, style: TextStyle(fontSize: 13, color: AppColors.muted)),
    ]),
  ),
);

// ── Show helpers ──────────────────────────────────────────────────────────────

void showKanjiInfoSheet(BuildContext ctx, Kanji kanji) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(
          20, 16, 20,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: KanjiInfoContent(kanji: kanji),
      ),
    ),
  );
}

void showVocabInfoSheet(BuildContext ctx, VocabWord word) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(
          20, 16, 20,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: VocabInfoContent(word: word),
      ),
    ),
  );
}

void showKanaInfoSheet(BuildContext ctx, KanaCharacter char) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(
          20, 16, 20,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: KanaInfoContent(char: char),
      ),
    ),
  );
}
