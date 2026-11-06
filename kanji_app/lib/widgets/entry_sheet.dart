import 'package:flutter/material.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/database_service.dart';
import '../theme.dart';
import 'item_info_sheet.dart';

/// Opens the dictionary-style page for the kanji with [id].
Future<void> showKanjiEntryById(BuildContext ctx, int id) async {
  final k = await kanjiRepo.getById(id);
  if (k != null && ctx.mounted) showKanjiInfoSheet(ctx, k);
}

/// Opens the dictionary-style page for the vocabulary word with [id].
Future<void> showVocabEntryById(BuildContext ctx, int id) async {
  final rows = await dbService.query('SELECT * FROM vocabulary WHERE id = ?', [id]);
  if (rows.isNotEmpty && ctx.mounted) {
    showVocabInfoSheet(ctx, VocabWord.fromMap(rows.first));
  }
}

/// Opens the info page for a kana character.
void showKanaEntry(BuildContext ctx, KanaCharacter c) => showKanaInfoSheet(ctx, c);

/// Speed-read items are just (display, answer) strings: find the matching
/// vocabulary word or kana character and open its page. No-op if neither exists.
Future<void> showEntryForDisplay(BuildContext ctx, String display, String answer) async {
  final v = await dbService.query(
    'SELECT * FROM vocabulary WHERE word = ? AND reading = ? LIMIT 1', [display, answer]);
  if (v.isNotEmpty) {
    if (ctx.mounted) showVocabInfoSheet(ctx, VocabWord.fromMap(v.first));
    return;
  }
  final k = await dbService.query('SELECT * FROM kana WHERE character = ? LIMIT 1', [display]);
  if (k.isNotEmpty && ctx.mounted) {
    showKanaInfoSheet(ctx, KanaCharacter.fromRow({...k.first, 'status': 'learned'}));
  }
}

/// Simple page for a kana-practice word (these live in their own small table,
/// with no dictionary entry or example sentences).
void showKanaWordSheet(BuildContext ctx, KanaWord w) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(w.word, style: TextStyle(
          fontSize: 44, color: AppColors.kanjiColor,
          fontFamily: AppFonts.japaneseFont, fontFamilyFallback: AppFonts.japaneseFallback)),
        const SizedBox(height: 6),
        Text(w.romaji, style: TextStyle(fontSize: 18, color: AppColors.muted)),
        const SizedBox(height: 10),
        Text(w.meaning, style: TextStyle(fontSize: 16, color: AppColors.fg)),
      ]),
    ),
  );
}
