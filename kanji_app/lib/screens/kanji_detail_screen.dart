import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../theme_provider.dart';
import '../widgets/item_info_sheet.dart';
import '../widgets/k_setup.dart';

class KanjiDetailScreen extends ConsumerWidget {
  final Kanji kanji;
  const KanjiDetailScreen({super.key, required this.kanji});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: KBackHeader(title: kanji.character, colors: colors),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: KanjiInfoContent(kanji: kanji),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
