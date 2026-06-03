import '../services/database_service.dart';

class JlptQuestion {
  final int id;
  final int level;
  final String section;
  final String questionType;
  final int? passageId;
  final String? passage;
  final String? passageTitle;
  final String questionStem;
  final List<String> options;
  final int correctOption;
  // Display variants: {kanji|reading} markup for furigana rendering.
  // Falls back to plain text fields when null.
  final String? passageDisplay;
  final String? passageTitleDisplay;
  final String? questionStemDisplay;
  final List<String?> optionsDisplay;
  // Sentence-reorder only: "a,b,c,d" → slot1=optA, slot2=optB, etc.
  final String? correctOrder;

  const JlptQuestion({
    required this.id,
    required this.level,
    required this.section,
    required this.questionType,
    this.passageId,
    this.passage,
    this.passageTitle,
    required this.questionStem,
    required this.options,
    required this.correctOption,
    this.passageDisplay,
    this.passageTitleDisplay,
    this.questionStemDisplay,
    required this.optionsDisplay,
    this.correctOrder,
  });

  factory JlptQuestion.fromMap(Map<String, dynamic> m) => JlptQuestion(
    id: m['id'] as int,
    level: m['level'] as int,
    section: m['section'] as String,
    questionType: m['question_type'] as String,
    passageId: m['passage_id'] as int?,
    passage: m['passage'] as String?,
    passageTitle: m['passage_title'] as String?,
    questionStem: m['question_stem'] as String,
    options: [
      m['option_1'] as String,
      m['option_2'] as String,
      m['option_3'] as String,
      m['option_4'] as String,
    ],
    correctOption: m['correct_option'] as int,
    passageDisplay: m['passage_display'] as String?,
    passageTitleDisplay: m['passage_title_display'] as String?,
    questionStemDisplay: m['question_stem_display'] as String?,
    optionsDisplay: [
      m['option_1_display'] as String?,
      m['option_2_display'] as String?,
      m['option_3_display'] as String?,
      m['option_4_display'] as String?,
    ],
    correctOrder: m['correct_order'] as String?,
  );

  String get correctAnswer => options[correctOption - 1];
  String get displayPassage => passageDisplay ?? passage ?? '';
  String get displayPassageTitle => passageTitleDisplay ?? passageTitle ?? '';
  String get displayQuestionStem => questionStemDisplay ?? questionStem;
  String displayOption(int i) => optionsDisplay[i] ?? options[i];

  // 0-based index of the ★ slot, derived from correctOrder + correctOption.
  int get starSlotIndex {
    if (correctOrder == null) return 0;
    final parts = correctOrder!.split(',');
    final idx = parts.indexWhere((p) => int.tryParse(p) == correctOption);
    return idx < 0 ? 0 : idx;
  }

  // Correct slot arrangement as list of 1-based option indices.
  List<int?> get correctSlots {
    if (correctOrder == null) return [null, null, null, null];
    final slots = correctOrder!.split(',').map((p) => int.tryParse(p)).toList();
    if (slots.length < 4) return [...slots, ...List.filled(4 - slots.length, null)];
    return slots;
  }
}

class JlptRepository {
  Future<List<JlptQuestion>> sampleVocabulary(int level, {int count = 25}) async {
    final rows = await dbService.query('''
      SELECT * FROM jlpt_questions
      WHERE level=? AND section='vocabulary'
      ORDER BY RANDOM() LIMIT ?
    ''', [level, count]);
    return rows.map(JlptQuestion.fromMap).toList();
  }

  Future<List<JlptQuestion>> sampleGrammar(int level, {int count = 15}) async {
    final rows = await dbService.query('''
      SELECT * FROM jlpt_questions
      WHERE level=? AND section='grammar'
      ORDER BY RANDOM() LIMIT ?
    ''', [level, count]);
    return rows.map(JlptQuestion.fromMap).toList();
  }

  Future<List<JlptQuestion>> sampleReading(int level, {int passageCount = 4}) async {
    final passageRows = await dbService.query('''
      SELECT DISTINCT passage_id FROM jlpt_questions
      WHERE level=? AND section='reading' AND passage_id IS NOT NULL
      ORDER BY RANDOM() LIMIT ?
    ''', [level, passageCount]);

    if (passageRows.isEmpty) return [];

    final ids = passageRows.map((r) => r['passage_id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await dbService.query('''
      SELECT * FROM jlpt_questions
      WHERE passage_id IN ($placeholders)
      ORDER BY passage_id, id
    ''', ids);
    return rows.map(JlptQuestion.fromMap).toList();
  }

  Future<JlptTestSession> buildSession(int level, {String? section}) async {
    final vocab = (section == null || section == 'vocabulary')
        ? await sampleVocabulary(level)
        : <JlptQuestion>[];
    final grammar = (section == null || section == 'grammar')
        ? await sampleGrammar(level)
        : <JlptQuestion>[];
    final reading = (section == null || section == 'reading')
        ? await sampleReading(level)
        : <JlptQuestion>[];
    return JlptTestSession(level: level, vocabulary: vocab, grammar: grammar, reading: reading);
  }

  Future<List<JlptQuestion>> _fetchByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await dbService.query(
      'SELECT * FROM jlpt_questions WHERE id IN ($placeholders)', ids);
    final byId = {for (final r in rows) (r['id'] as int): JlptQuestion.fromMap(r)};
    return ids.map((id) => byId[id]).whereType<JlptQuestion>().toList();
  }

  Future<JlptTestSession> buildSessionFromIds(int level, {
    required List<int> vocabIds,
    required List<int> grammarIds,
    required List<int> readingIds,
  }) async {
    final results = await Future.wait([
      _fetchByIds(vocabIds),
      _fetchByIds(grammarIds),
      _fetchByIds(readingIds),
    ]);
    return JlptTestSession(
      level: level,
      vocabulary: results[0],
      grammar: results[1],
      reading: results[2],
    );
  }
}

class JlptTestSession {
  final int level;
  final List<JlptQuestion> vocabulary;
  final List<JlptQuestion> grammar;
  final List<JlptQuestion> reading;

  const JlptTestSession({
    required this.level,
    required this.vocabulary,
    required this.grammar,
    required this.reading,
  });

  List<JlptQuestion> get allQuestions => [...vocabulary, ...grammar, ...reading];
  int get totalQuestions => vocabulary.length + grammar.length + reading.length;
}

final jlptRepo = JlptRepository();
