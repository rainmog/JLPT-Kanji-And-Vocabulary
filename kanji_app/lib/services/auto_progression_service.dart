import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class AutoProgressionResult {
  final int addedKanji;
  final int addedVocab;
  final int addedKana;
  final List<int> newlyCompletedKanjiLevels; // jlpt_level values (5=N5, 1=N1)
  final List<int> newlyCompletedVocabLevels;

  const AutoProgressionResult({
    this.addedKanji = 0,
    this.addedVocab = 0,
    this.addedKana = 0,
    this.newlyCompletedKanjiLevels = const [],
    this.newlyCompletedVocabLevels = const [],
  });

  bool get hasCompletions =>
      newlyCompletedKanjiLevels.isNotEmpty || newlyCompletedVocabLevels.isNotEmpty;
}

class AutoProgressionService {
  /// Run auto-progression. Returns result + updated settings (caller must save settings).
  Future<({AutoProgressionResult result, AppSettings updatedSettings})> run({
    required AppSettings settings,
  }) async {
    if (!settings.autoProgressionEnabled) {
      return (result: const AutoProgressionResult(), updatedSettings: settings);
    }

    var updatedSettings = settings;
    int addedKanji = 0;
    int addedVocab = 0;
    int addedKana = 0;

    // ── Staged fill: hiragana first → katakana+vocab → kanji+vocab ───────
    // Stage is determined by kana state so we check that first.
    final hiraganaProgress = await kanaRepo.getProgress(type: 'hiragana');
    final allHiraganaLearned = hiraganaProgress.learned >= hiraganaProgress.total;

    if (!allHiraganaLearned) {
      // Stage 1: only fill hiragana targets (up to 15)
      final hiraganaTargetCount = (await kanaRepo.getTargeted(type: 'hiragana')).length;
      if (hiraganaTargetCount < 15) {
        final need = 15 - hiraganaTargetCount;
        final nextKana = await kanaRepo.getNextUntargetedKana(need, type: 'hiragana');
        for (final ch in nextKana) {
          await kanaRepo.setStatus(ch.id, 'target');
        }
        addedKana = nextKana.length;
      }
    } else {
      final katakanaProgress = await kanaRepo.getProgress(type: 'katakana');
      final allKatakanaLearned = katakanaProgress.learned >= katakanaProgress.total;

      if (!allKatakanaLearned) {
        // Stage 2: fill katakana (up to 15) + vocab; skip kanji
        final katakanaTargetCount = (await kanaRepo.getTargeted(type: 'katakana')).length;
        if (katakanaTargetCount < 15) {
          final need = 15 - katakanaTargetCount;
          final nextKana = await kanaRepo.getNextUntargetedKana(need, type: 'katakana');
          for (final ch in nextKana) {
            await kanaRepo.setStatus(ch.id, 'target');
          }
          addedKana = nextKana.length;
        }

        final currentVocabTargets2 = await vocabRepo.getTargetCount();
        final vocabDeficit2 = (settings.autoProgressionVocabQuota - currentVocabTargets2)
            .clamp(0, settings.autoProgressionVocabQuota);
        if (vocabDeficit2 > 0) {
          final nextVocab = await vocabRepo.getNextUntargetedVocab(vocabDeficit2);
          if (nextVocab.isNotEmpty) {
            final db = await dbService.database;
            final batch = db.batch();
            final now = DateTime.now().millisecondsSinceEpoch;
            for (final v in nextVocab) {
              batch.rawInsert(
                'INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at) VALUES (?, ?)',
                [v.id, now],
              );
            }
            await batch.commit(noResult: true);
            addedVocab = nextVocab.length;
          }
        }
      } else {
        // Stage 3: all kana learned — fill kanji + vocab normally
        final currentKanjiTargets = (await kanjiRepo.getTargetKanjiList()).length;
        final kanjiDeficit = (settings.autoProgressionKanjiQuota - currentKanjiTargets)
            .clamp(0, settings.autoProgressionKanjiQuota);
        if (kanjiDeficit > 0) {
          final nextKanji = await kanjiRepo.getNextUnlearned(kanjiDeficit);
          if (nextKanji.isNotEmpty) {
            await kanjiRepo.bulkSetTarget(nextKanji.map((k) => k.id).toList());
            addedKanji = nextKanji.length;
          }
        }

        final currentVocabTargets = await vocabRepo.getTargetCount();
        final vocabDeficit = (settings.autoProgressionVocabQuota - currentVocabTargets)
            .clamp(0, settings.autoProgressionVocabQuota);
        if (vocabDeficit > 0) {
          final nextVocab = await vocabRepo.getNextUntargetedVocab(vocabDeficit);
          if (nextVocab.isNotEmpty) {
            final db = await dbService.database;
            final batch = db.batch();
            final now = DateTime.now().millisecondsSinceEpoch;
            for (final v in nextVocab) {
              batch.rawInsert(
                'INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at) VALUES (?, ?)',
                [v.id, now],
              );
            }
            await batch.commit(noResult: true);
            addedVocab = nextVocab.length;
          }
        }
      }
    }

    // ── Level completion detection ────────────────────────────────────────
    final newlyCompletedKanji = <int>[];
    final newlyCompletedVocab = <int>[];

    final kanjiProgress = await kanjiRepo.getProgressByLevel();
    for (final level in [5, 4, 3, 2, 1]) {
      if (settings.completedKanjiLevels.contains(level)) continue;
      final p = kanjiProgress[level];
      if (p != null && p.total > 0 && p.learned >= p.total) {
        newlyCompletedKanji.add(level);
      }
    }

    final vocabProgress = await vocabRepo.getProgressByLevel();
    for (final level in [5, 4, 3, 2, 1]) {
      if (settings.completedVocabLevels.contains(level)) continue;
      final p = vocabProgress[level];
      if (p != null && p.total > 0 && p.learned >= p.total) {
        newlyCompletedVocab.add(level);
      }
    }

    if (newlyCompletedKanji.isNotEmpty || newlyCompletedVocab.isNotEmpty) {
      updatedSettings = updatedSettings.copyWith(
        completedKanjiLevels: [
          ...updatedSettings.completedKanjiLevels,
          ...newlyCompletedKanji,
        ],
        completedVocabLevels: [
          ...updatedSettings.completedVocabLevels,
          ...newlyCompletedVocab,
        ],
      );
    }

    return (
      result: AutoProgressionResult(
        addedKanji: addedKanji,
        addedVocab: addedVocab,
        addedKana: addedKana,
        newlyCompletedKanjiLevels: newlyCompletedKanji,
        newlyCompletedVocabLevels: newlyCompletedVocab,
      ),
      updatedSettings: updatedSettings,
    );
  }
}

final autoProgressionService = AutoProgressionService();
