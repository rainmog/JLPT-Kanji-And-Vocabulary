-- kanji_app_data.db — public schema
-- Tables: kanji, kanji_tags, sentences, vocabulary, vocabulary_tags,
--         jlpt_questions, kana, kana_words
-- Runtime tables (user_progress, session_log) are NOT included.

CREATE TABLE jlpt_questions (
        id INTEGER PRIMARY KEY,
        level INTEGER NOT NULL,
        section TEXT NOT NULL,
        question_type TEXT NOT NULL,
        passage_id INTEGER,
        passage TEXT,
        passage_title TEXT,
        question_stem TEXT NOT NULL,
        option_1 TEXT NOT NULL,
        option_2 TEXT NOT NULL,
        option_3 TEXT NOT NULL,
        option_4 TEXT NOT NULL,
        correct_option INTEGER NOT NULL,
        passage_display TEXT,
        passage_title_display TEXT,
        question_stem_display TEXT,
        option_1_display TEXT,
        option_2_display TEXT,
        option_3_display TEXT,
        option_4_display TEXT,
        correct_order TEXT,
        question_translation TEXT,
        passage_translation TEXT
    );

CREATE TABLE kana (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        romaji TEXT NOT NULL,
        acceptable_romaji TEXT NOT NULL,
        row TEXT NOT NULL,
        counterpart TEXT
    );

CREATE TABLE kana_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        romaji TEXT NOT NULL,
        acceptable_romaji TEXT NOT NULL,
        meaning TEXT NOT NULL,
        type TEXT NOT NULL
    );

CREATE TABLE kanji (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character TEXT UNIQUE NOT NULL,
        jlpt_level INTEGER NOT NULL,
        on_reading TEXT,
        kun_reading TEXT,
        meaning TEXT,
        stroke_count INTEGER
    );

CREATE TABLE kanji_tags (
        kanji_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (kanji_id, tag),
        FOREIGN KEY(kanji_id) REFERENCES kanji(id)
    );

CREATE TABLE sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kanji_id INTEGER NOT NULL,
        difficulty INTEGER NOT NULL,
        text_kanji TEXT NOT NULL,
        text_structured TEXT NOT NULL,
        english_translation TEXT NOT NULL,
        valid_readings TEXT NOT NULL,
        FOREIGN KEY(kanji_id) REFERENCES kanji(id)
    );

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE vocabulary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        reading TEXT NOT NULL,
        meanings TEXT NOT NULL,
        acceptable_answers TEXT NOT NULL,
        jlpt_level INTEGER NOT NULL,
        tags TEXT NOT NULL
    );

CREATE TABLE vocabulary_tags (
        vocab_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (vocab_id, tag),
        FOREIGN KEY(vocab_id) REFERENCES vocabulary(id)
    );

CREATE INDEX idx_jlpt_level_section ON jlpt_questions(level, section);

CREATE INDEX idx_jlpt_passage_id ON jlpt_questions(passage_id);

CREATE INDEX idx_kana_row ON kana(row);

CREATE INDEX idx_kana_type ON kana(type);

CREATE INDEX idx_kana_words_type ON kana_words(type);

CREATE INDEX idx_kanji_jlpt ON kanji(jlpt_level);

CREATE INDEX idx_kanji_tags_tag ON kanji_tags(tag);

CREATE INDEX idx_sentences_difficulty ON sentences(difficulty);

CREATE INDEX idx_sentences_kanji ON sentences(kanji_id);

CREATE INDEX idx_vocab_jlpt ON vocabulary(jlpt_level);

CREATE INDEX idx_vocab_tags_tag ON vocabulary_tags(tag);
