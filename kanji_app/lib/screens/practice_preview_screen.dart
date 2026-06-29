import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../widgets/item_info_sheet.dart';
import '../widgets/k_setup.dart';

// ── Sealed item-type hierarchy ────────────────────────────────────────────────

sealed class PreviewItems {
  const PreviewItems();
}

class KanjiPreviewItems extends PreviewItems {
  final List<Kanji> items;
  const KanjiPreviewItems(this.items);
}

class VocabPreviewItems extends PreviewItems {
  final List<VocabWord> items;
  const VocabPreviewItems(this.items);
}

class KanaPreviewItems extends PreviewItems {
  final List<KanaCharacter> items;
  const KanaPreviewItems(this.items);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PracticePreviewScreen extends ConsumerWidget {
  final PreviewItems items;
  final void Function(BuildContext) onBegin;
  const PracticePreviewScreen({
    super.key,
    required this.items,
    required this.onBegin,
  });

  int get _count => switch (items) {
    KanjiPreviewItems(:final items) => items.length,
    VocabPreviewItems(:final items) => items.length,
    KanaPreviewItems(:final items) => items.length,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final count = _count;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: KBackHeader(title: 'Preview', colors: colors),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                switch (items) {
                  KanjiPreviewItems() => 'These $count kanji will be practiced in this session. Tap any for full details.',
                  VocabPreviewItems() => 'These $count words will be practiced in this session. Tap any for full details.',
                  KanaPreviewItems() => 'These $count characters will be practiced in this session.',
                },
                style: TextStyle(
                  fontSize: 13,
                  color: KDesign.inkFaint(colors),
                ),
              ),
            ),
            Expanded(child: _buildList(context, colors)),
            KStickyFooter(
              colors: colors,
              child: KStartButton(
                label: 'Begin Practice',
                colors: colors,
                onTap: () => onBegin(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ThemeColors colors) {
    return switch (items) {
      KanjiPreviewItems(:final items) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(color: KDesign.line(colors), height: 1),
          itemBuilder: (context, i) {
            final kanji = items[i];
            return InkWell(
              onTap: () => showKanjiInfoSheet(context, kanji),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.btnBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        kanji.character,
                        style: TextStyle(
                          fontSize: 32,
                          color: AppColors.kanjiColor,
                          fontFamily: AppFonts.japaneseFont,
                          fontFamilyFallback: AppFonts.japaneseFallback,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  kanji.onReading.isNotEmpty ? 'On: ${kanji.onReading}' : '',
                                  style: TextStyle(fontSize: 13, color: AppColors.fg),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'N${kanji.jlptLevel}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (kanji.kunReading.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Kun: ${kanji.kunReading}',
                              style: TextStyle(fontSize: 13, color: AppColors.fg),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            kanji.meaning,
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      VocabPreviewItems(:final items) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(color: KDesign.line(colors), height: 1),
          itemBuilder: (context, i) {
            final word = items[i];
            final showReading = word.word != word.reading;
            final meanings = word.meanings
                .split(RegExp(r'[;,]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .take(2)
                .join(', ');
            return InkWell(
              onTap: () => showVocabInfoSheet(context, word),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.btnBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          word.word,
                          style: TextStyle(
                            fontSize: 26,
                            color: AppColors.kanjiColor,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppFonts.japaneseFont,
                            fontFamilyFallback: AppFonts.japaneseFallback,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (showReading)
                                Expanded(
                                  child: Text(
                                    word.reading,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.fg,
                                      fontFamily: AppFonts.japaneseFont,
                                      fontFamilyFallback: AppFonts.japaneseFallback,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  word.levelLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meanings,
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      KanaPreviewItems(:final items) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(color: KDesign.line(colors), height: 1),
          itemBuilder: (context, i) {
            final char = items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.btnBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      char.character,
                      style: TextStyle(
                        fontSize: 32,
                        color: AppColors.muted,
                        fontFamily: AppFonts.japaneseFont,
                        fontFamilyFallback: AppFonts.japaneseFallback,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        char.romaji,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        char.type,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
    };
  }
}
