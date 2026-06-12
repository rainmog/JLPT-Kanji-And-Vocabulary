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
                  KanjiPreviewItems() => 'These $count kanji will be practiced in this session. Tap any to review their meaning first.',
                  VocabPreviewItems() => 'These $count words will be practiced in this session. Tap any to review their meaning first.',
                  KanaPreviewItems() => 'These $count characters will be practiced in this session. Tap any to preview.',
                },
                style: TextStyle(
                  fontSize: 13,
                  color: KDesign.inkFaint(colors),
                ),
              ),
            ),
            Expanded(child: _buildGrid(context)),
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

  Widget _buildGrid(BuildContext context) {
    return switch (items) {
      KanjiPreviewItems(:final items) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final kanji = items[i];
            return GestureDetector(
              onTap: () => showKanjiInfoSheet(context, kanji),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.btnBg,
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  kanji.character,
                  style: TextStyle(
                    fontSize: 22,
                    color: AppColors.kanjiColor,
                  ),
                ),
              ),
            );
          },
        ),
      VocabPreviewItems(:final items) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.4,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final word = items[i];
            final showReading = word.word != word.reading;
            return GestureDetector(
              onTap: () => showVocabInfoSheet(context, word),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.btnBg,
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      word.word,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.kanjiColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showReading) ...[
                      const SizedBox(height: 2),
                      Text(
                        word.reading,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.kanjiColor.withValues(alpha: 0.75),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      KanaPreviewItems(:final items) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final char = items[i];
            return GestureDetector(
              onTap: () => showKanaInfoSheet(context, char),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.btnBg,
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  char.character,
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.muted,
                  ),
                ),
              ),
            );
          },
        ),
    };
  }
}
