import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../theme/app_theme_backgrounds.dart';
import '../theme_provider.dart';
import '../widgets/item_info_sheet.dart';
import '../widgets/k_setup.dart';
import '../widgets/sakura_overlay.dart';
import '../widgets/falling_blocks_overlay.dart';
import '../widgets/snow_overlay.dart';
import '../widgets/space_age_overlay.dart';

final _allVocabProvider = FutureProvider<List<VocabWord>>(
  (_) => vocabRepo.getAllVocab(),
);

class VocabularyDictionaryScreen extends ConsumerStatefulWidget {
  const VocabularyDictionaryScreen({super.key});

  @override
  ConsumerState<VocabularyDictionaryScreen> createState() =>
      _VocabularyDictionaryScreenState();
}

class _VocabularyDictionaryScreenState
    extends ConsumerState<VocabularyDictionaryScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int? _levelFilter; // null = all

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<VocabWord> _filter(List<VocabWord> words) {
    var result = words;
    if (_levelFilter != null) {
      result = result.where((w) => w.jlptLevel == _levelFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((w) =>
        w.word.contains(_query) ||
        w.reading.contains(_query) ||
        w.meanings.toLowerCase().contains(q)
      ).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final vocabAsync = ref.watch(_allVocabProvider);
    final appTheme = ref.watch(themeNotifier);
    final hasAnimatedBg = const {AppTheme.galaxy, AppTheme.loveLetter, AppTheme.lily, AppTheme.totoro, AppTheme.midnightCity}.contains(appTheme);

    return Scaffold(
      backgroundColor: hasAnimatedBg ? Colors.transparent : colors.bg,
      body: Stack(children: [const Positioned.fill(child: HomeBgLayer()), const Positioned.fill(child: SakuraPetalsOverlay()), const Positioned.fill(child: SpaceAgeStarsOverlay()), const Positioned.fill(child: SnowOverlay()), const Positioned.fill(child: FallingBlocksOverlay()), SafeArea(
        child: Column(children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: KBackHeader(title: 'Dictionary', colors: colors),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KDesign.line(colors)),
                boxShadow: KDesign.shadowSm(colors),
              ),
              child: TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: KDesign.ink(colors)),
                decoration: InputDecoration(
                  hintText: 'Search word, reading, or meaning…',
                  hintStyle: TextStyle(fontSize: 14, color: KDesign.inkFaint(colors), fontWeight: FontWeight.w500),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: KDesign.inkFaint(colors)),
                  suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _controller.clear(); setState(() => _query = ''); },
                        child: Icon(Icons.close_rounded, size: 18, color: KDesign.inkFaint(colors)),
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ),

          // Level filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [null, 5, 4, 3, 2, 1].map((level) {
                final on = _levelFilter == level;
                final label = level == null ? 'All' : 'N$level';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _levelFilter = level),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: on ? colors.accent : colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: on ? colors.accent : KDesign.line(colors)),
                        boxShadow: on ? KDesign.shadowAccent(colors) : null,
                      ),
                      child: Text(label, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: on ? Colors.white : KDesign.inkSoft(colors),
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: vocabAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (words) {
                final filtered = _filter(words);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isNotEmpty ? 'No results for "$_query"' : 'No vocabulary found',
                      style: TextStyle(fontSize: 15, color: KDesign.inkFaint(colors)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _VocabRow(word: filtered[i], colors: colors),
                );
              },
            ),
          ),
        ]),
      ),
      ]),
    );
  }
}

class _VocabRow extends StatelessWidget {
  final VocabWord word;
  final ThemeColors colors;
  const _VocabRow({required this.word, required this.colors});

  @override
  Widget build(BuildContext context) {
    final hasKanji = word.word != word.reading;
    return GestureDetector(
      onTap: () => showVocabInfoSheet(context, word),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(word.word, style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: KDesign.ink(colors), fontFamily: 'NotoSerifCJKjp',
              )),
              if (hasKanji) ...[
                const SizedBox(width: 8),
                Text(word.reading, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: KDesign.inkSoft(colors),
                )),
              ],
            ]),
            const SizedBox(height: 3),
            if (word.isUsuallyKana)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('Usually written in kana', style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600,
                  color: colors.accent, fontStyle: FontStyle.italic,
                )),
              ),
            Text(word.meanings, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w600,
              color: KDesign.inkSoft(colors),
            )),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: KDesign.tint(colors),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(word.levelLabel, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: colors.accent,
          )),
        ),
      ]),
    ),
    );
  }
}
