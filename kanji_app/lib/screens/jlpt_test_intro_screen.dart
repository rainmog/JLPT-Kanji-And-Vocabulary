import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import 'jlpt_test_session_screen.dart';

class JlptTestIntroScreen extends StatefulWidget {
  final int level;
  const JlptTestIntroScreen({super.key, required this.level});

  @override
  State<JlptTestIntroScreen> createState() => _JlptTestIntroScreenState();
}

class _JlptTestIntroScreenState extends State<JlptTestIntroScreen> {
  String? _section; // null = all sections
  Map<String, dynamic>? _savedProgress;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await loadJlptProgress(widget.level, section: _section);
    if (mounted) setState(() { _savedProgress = saved; _checked = true; });
  }

  void _onSectionChanged(String? section) {
    setState(() { _section = section; _checked = false; _savedProgress = null; });
    _checkSaved();
  }

  void _startFresh() => Navigator.push(
    context,
    AppRoute.to(JlptTestSessionScreen(level: widget.level, section: _section)),
  );

  void _resume() {
    final saved = _savedProgress!;
    final index = saved['index'] as int;
    final rawAnswers = saved['answers'] as Map<String, dynamic>;
    final answers = rawAnswers.map((k, v) => MapEntry(int.parse(k), v as int));
    final vocabIds = (saved['vocabIds'] as List?)?.cast<int>();
    final grammarIds = (saved['grammarIds'] as List?)?.cast<int>();
    final readingIds = (saved['readingIds'] as List?)?.cast<int>();
    Navigator.push(
      context,
      AppRoute.to(JlptTestSessionScreen(
        level: widget.level,
        section: _section,
        resumeIndex: index,
        resumeAnswers: answers,
        resumeVocabIds: vocabIds,
        resumeGrammarIds: grammarIds,
        resumeReadingIds: readingIds,
      )),
    );
  }

  String get _startLabel {
    if (_section == null) return 'Start Test';
    final labels = {
      'vocabulary': 'Start Vocabulary Test',
      'grammar': 'Start Grammar Test',
      'reading': 'Start Reading Test',
    };
    return labels[_section] ?? 'Start Test';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('JLPT N${widget.level} Practice Test',
            style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Practice Mode',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            _SectionToggle(selected: _section, onChanged: _onSectionChanged),
            const SizedBox(height: 24),
            Text(
              'How the test works',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: AppColors.fg),
            ),
            const SizedBox(height: 16),
            if (_section == null || _section == 'vocabulary') ...[
              _SectionInfo(
                title: 'Vocabulary',
                description: 'Fill in the blank · kanji reading · kanji writing (~25 questions)',
                icon: Icons.text_fields,
              ),
              const SizedBox(height: 10),
            ],
            if (_section == null || _section == 'grammar') ...[
              _SectionInfo(
                title: 'Grammar',
                description: 'Particles, verb forms, and sentence ordering (~15 questions)',
                icon: Icons.account_tree_outlined,
              ),
              const SizedBox(height: 10),
            ],
            if (_section == null || _section == 'reading') ...[
              _SectionInfo(
                title: 'Reading',
                description: 'Short passages with comprehension questions (~8 questions)',
                icon: Icons.menu_book_outlined,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
            Text(
              '• Questions are randomly selected each run\n'
              '• No time limit — this is practice\n'
              '• Review missed questions at the end',
              style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.8),
            ),
            const SizedBox(height: 40),
            if (_checked && _savedProgress != null) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  ),
                ),
                onPressed: _resume,
                child: Text('Resume (Q${(_savedProgress!['index'] as int) + 1})',
                    style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.btnBg,
                  foregroundColor: AppColors.fg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  ),
                ),
                onPressed: _startFresh,
                child: const Text('Start Fresh', style: TextStyle(fontSize: 17)),
              ),
            ] else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  ),
                ),
                onPressed: _startFresh,
                child: Text(_startLabel, style: const TextStyle(fontSize: 17)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  final String? selected;
  final void Function(String?) onChanged;
  const _SectionToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [
      (null, 'All'),
      ('vocabulary', 'Vocab'),
      ('grammar', 'Grammar'),
      ('reading', 'Reading'),
    ];
    return Row(children: [
      for (final (value, label) in options) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected == value ? AppColors.accent : AppColors.btnBg,
                borderRadius: BorderRadius.circular(AppColors.buttonRadius),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected == value ? AppColors.bg : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
        if (label != 'Reading') const SizedBox(width: 6),
      ],
    ]);
  }
}

class _SectionInfo extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  const _SectionInfo({required this.title, required this.description, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.containerRadius),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.accent, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.fg)),
            const SizedBox(height: 4),
            Text(description,
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}
