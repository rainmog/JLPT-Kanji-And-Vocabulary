import json, sqlite3, os, sys
from pathlib import Path
from validate_database import validate_all
from tag_kanji import TAG_RULES

BASE = Path(__file__).parent

def build(out_path: Path | str = None):
    if out_path is None:
        out_path = BASE.parent / 'kanji_app' / 'assets' / 'kanji.db'
    out_path = Path(out_path)
    os.makedirs(out_path.parent, exist_ok=True)
    if out_path.exists():
        out_path.unlink()
    conn = sqlite3.connect(out_path)
    c = conn.cursor()

    char_to_tags: dict[str, list[str]] = {}
    for _tag, _chars in TAG_RULES.items():
        for _ch in _chars:
            char_to_tags.setdefault(_ch, []).append(_tag)

    def compute_vocab_tags(word: str) -> list[str]:
        tags: set[str] = set()
        for ch in word:
            tags.update(char_to_tags.get(ch, []))
        return sorted(tags)

    c.executescript("""
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
    CREATE TABLE user_progress (
        kanji_id INTEGER PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'unlearned',
        consecutive_correct INTEGER NOT NULL DEFAULT 0,
        total_seen INTEGER NOT NULL DEFAULT 0,
        total_correct INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(kanji_id) REFERENCES kanji(id)
    );
    CREATE TABLE session_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        mode TEXT NOT NULL,
        kanji_ids TEXT NOT NULL,
        score INTEGER NOT NULL
    );
    CREATE INDEX idx_kanji_jlpt ON kanji(jlpt_level);
    CREATE INDEX idx_kanji_tags_tag ON kanji_tags(tag);
    CREATE INDEX idx_sentences_kanji ON sentences(kanji_id);
    CREATE INDEX idx_sentences_difficulty ON sentences(difficulty);
    CREATE INDEX idx_progress_status ON user_progress(status);
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
    CREATE INDEX idx_vocab_jlpt ON vocabulary(jlpt_level);
    CREATE INDEX idx_vocab_tags_tag ON vocabulary_tags(tag);
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
        correct_order TEXT
    );
    CREATE INDEX idx_jlpt_level_section ON jlpt_questions(level, section);
    CREATE INDEX idx_jlpt_passage_id ON jlpt_questions(passage_id);
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
    CREATE INDEX idx_kana_type ON kana(type);
    CREATE INDEX idx_kana_row ON kana(row);
    CREATE INDEX idx_kana_words_type ON kana_words(type);
    """)

    with open(BASE / 'data' / 'kanji.json', encoding='utf-8') as f:
        kanji_list = json.load(f)
    char_to_id: dict[str, int] = {}
    for k in kanji_list:
        c.execute(
            "INSERT INTO kanji (character,jlpt_level,on_reading,kun_reading,meaning,stroke_count) VALUES (?,?,?,?,?,?)",
            (k['character'], k['jlpt_level'], k['on_reading'], k['kun_reading'], k['meaning'], k['stroke_count'])
        )
        char_to_id[k['character']] = c.lastrowid
        c.execute("INSERT INTO user_progress (kanji_id) VALUES (?)", (c.lastrowid,))

    with open(BASE / 'data' / 'kanji_tags.json', encoding='utf-8') as f:
        tag_data = json.load(f)
    tag_inserts = []
    for entry in tag_data:
        kid = char_to_id.get(entry['kanji_id'])
        if kid:
            for tag in entry['tags']:
                tag_inserts.append((kid, tag))
    if tag_inserts:
        c.executemany("INSERT INTO kanji_tags (kanji_id, tag) VALUES (?,?)", tag_inserts)

    with open(BASE / 'data' / 'sentences_v2.json', encoding='utf-8') as f:
        sentence_data = json.load(f)
    for entry in sentence_data:
        kid = char_to_id.get(entry['character'])
        if not kid:
            continue
        for s in entry['sentences']:
            c.execute(
                "INSERT INTO sentences (kanji_id,difficulty,text_kanji,text_structured,english_translation,valid_readings) VALUES (?,?,?,?,?,?)",
                (kid, s['difficulty'], s['text_kanji'],
                 json.dumps(s['text_structured'], ensure_ascii=False),
                 s['english_translation'],
                 json.dumps(s['valid_readings'], ensure_ascii=False))
            )

    # ── Vocabulary ──────────────────────────────────────────────────────────
    vocab_pos_path = BASE / 'data' / 'vocab_pos_tags.json'
    vocab_pos_tags: dict[str, list[str]] = {}
    if vocab_pos_path.exists():
        vocab_pos_tags = json.loads(vocab_pos_path.read_text())
        print(f'Loaded POS tags for {len(vocab_pos_tags)} vocab entries')

    vocab_path = BASE / 'data' / 'vocab.json'
    if vocab_path.exists():
        vocab_data = json.loads(vocab_path.read_text())
        for entry in vocab_data:
            pos_tags = vocab_pos_tags.get(f"{entry['word']}|{entry['reading']}", [])
            computed_tags = sorted(set(compute_vocab_tags(entry['word'])) | set(pos_tags))
            c.execute(
                'INSERT OR IGNORE INTO vocabulary (word, reading, meanings, acceptable_answers, jlpt_level, tags) VALUES (?,?,?,?,?,?)',
                (
                    entry['word'],
                    entry['reading'],
                    entry['meanings'],
                    json.dumps(entry['acceptable_answers'], ensure_ascii=False),
                    entry['jlpt_level'],
                    json.dumps(computed_tags, ensure_ascii=False),
                )
            )
            # Always SELECT the id — lastrowid is unreliable after INSERT OR IGNORE on conflict
            row = c.execute(
                'SELECT id FROM vocabulary WHERE word=? AND reading=?',
                (entry['word'], entry['reading'])
            ).fetchone()
            if row:
                vocab_id = row[0]
                for tag in computed_tags:
                    c.execute(
                        'INSERT OR IGNORE INTO vocabulary_tags (vocab_id, tag) VALUES (?,?)',
                        (vocab_id, tag)
                    )
        print(f'Inserted {len(vocab_data)} vocabulary entries')
    else:
        print('WARNING: tools/data/vocab.json not found — vocabulary table will be empty')

    def _insert_jlpt_questions(path, level):
        if not path.exists():
            print(f'WARNING: {path.name} not found — skipping N{level}')
            return
        qs = json.load(open(path, encoding='utf-8'))
        c.execute(f'DELETE FROM jlpt_questions WHERE level={level}')
        for q in qs:
            c.execute('''
                INSERT INTO jlpt_questions
                (level, section, question_type, passage_id, passage, passage_title,
                 question_stem, option_1, option_2, option_3, option_4, correct_option,
                 passage_display, passage_title_display, question_stem_display,
                 option_1_display, option_2_display, option_3_display, option_4_display,
                 correct_order)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ''', (
                q['level'], q['section'], q['question_type'],
                q.get('passage_id'), q.get('passage'), q.get('passage_title'),
                q['question_stem'],
                q['option_1'], q['option_2'], q['option_3'], q['option_4'],
                q['correct_option'],
                q.get('passage_display'), q.get('passage_title_display'),
                q.get('question_stem_display'),
                q.get('option_1_display'), q.get('option_2_display'),
                q.get('option_3_display'), q.get('option_4_display'),
                q.get('correct_order'),
            ))
        print(f'Inserted {len(qs)} N{level} JLPT questions')

    _insert_jlpt_questions(BASE / 'data' / 'n5_questions.json', 5)
    _insert_jlpt_questions(BASE / 'data' / 'n4_questions.json', 4)
    _insert_jlpt_questions(BASE / 'data' / 'n3_questions.json', 3)
    _insert_jlpt_questions(BASE / 'data' / 'n2_questions.json', 2)
    _insert_jlpt_questions(BASE / 'data' / 'n1_questions.json', 1)

    # ── Kana ─────────────────────────────────────────────────────────────────
    # (char, romaji, [extra_romaji], row)
    HIRAGANA_DATA = [
        # Basic
        ('あ','a',[],'あ行'), ('い','i',[],'あ行'), ('う','u',[],'あ行'), ('え','e',[],'あ行'), ('お','o',[],'あ行'),
        ('か','ka',[],'か行'), ('き','ki',[],'か行'), ('く','ku',[],'か行'), ('け','ke',[],'か行'), ('こ','ko',[],'か行'),
        ('さ','sa',[],'さ行'), ('し','shi',['si'],'さ行'), ('す','su',[],'さ行'), ('せ','se',[],'さ行'), ('そ','so',[],'さ行'),
        ('た','ta',[],'た行'), ('ち','chi',['ti'],'た行'), ('つ','tsu',['tu'],'た行'), ('て','te',[],'た行'), ('と','to',[],'た行'),
        ('な','na',[],'な行'), ('に','ni',[],'な行'), ('ぬ','nu',[],'な行'), ('ね','ne',[],'な行'), ('の','no',[],'な行'),
        ('は','ha',[],'は行'), ('ひ','hi',[],'は行'), ('ふ','fu',['hu'],'は行'), ('へ','he',[],'は行'), ('ほ','ho',[],'は行'),
        ('ま','ma',[],'ま行'), ('み','mi',[],'ま行'), ('む','mu',[],'ま行'), ('め','me',[],'ま行'), ('も','mo',[],'ま行'),
        ('や','ya',[],'や行'), ('ゆ','yu',[],'や行'), ('よ','yo',[],'や行'),
        ('ら','ra',[],'ら行'), ('り','ri',[],'ら行'), ('る','ru',[],'ら行'), ('れ','re',[],'ら行'), ('ろ','ro',[],'ら行'),
        ('わ','wa',[],'わ行'), ('を','wo',['o'],'わ行'), ('ん','n',['nn'],'わ行'),
        # Dakuten
        ('が','ga',[],'が行'), ('ぎ','gi',[],'が行'), ('ぐ','gu',[],'が行'), ('げ','ge',[],'が行'), ('ご','go',[],'が行'),
        ('ざ','za',[],'ざ行'), ('じ','ji',['zi'],'ざ行'), ('ず','zu',[],'ざ行'), ('ぜ','ze',[],'ざ行'), ('ぞ','zo',[],'ざ行'),
        ('だ','da',[],'だ行'), ('ぢ','ji',['di','zi'],'だ行'), ('づ','zu',['du'],'だ行'), ('で','de',[],'だ行'), ('ど','do',[],'だ行'),
        ('ば','ba',[],'ば行'), ('び','bi',[],'ば行'), ('ぶ','bu',[],'ば行'), ('べ','be',[],'ば行'), ('ぼ','bo',[],'ば行'),
        # Handakuten
        ('ぱ','pa',[],'ぱ行'), ('ぴ','pi',[],'ぱ行'), ('ぷ','pu',[],'ぱ行'), ('ぺ','pe',[],'ぱ行'), ('ぽ','po',[],'ぱ行'),
        # Combos
        ('きゃ','kya',[],'きゃ行'), ('きゅ','kyu',[],'きゃ行'), ('きょ','kyo',[],'きゃ行'),
        ('しゃ','sha',['sya'],'しゃ行'), ('しゅ','shu',['syu'],'しゃ行'), ('しょ','sho',['syo'],'しゃ行'),
        ('ちゃ','cha',['tya'],'ちゃ行'), ('ちゅ','chu',['tyu'],'ちゃ行'), ('ちょ','cho',['tyo'],'ちゃ行'),
        ('にゃ','nya',[],'にゃ行'), ('にゅ','nyu',[],'にゃ行'), ('にょ','nyo',[],'にゃ行'),
        ('ひゃ','hya',[],'ひゃ行'), ('ひゅ','hyu',[],'ひゃ行'), ('ひょ','hyo',[],'ひゃ行'),
        ('みゃ','mya',[],'みゃ行'), ('みゅ','myu',[],'みゃ行'), ('みょ','myo',[],'みゃ行'),
        ('りゃ','rya',[],'りゃ行'), ('りゅ','ryu',[],'りゃ行'), ('りょ','ryo',[],'りゃ行'),
        ('ぎゃ','gya',[],'ぎゃ行'), ('ぎゅ','gyu',[],'ぎゃ行'), ('ぎょ','gyo',[],'ぎゃ行'),
        ('じゃ','ja',['zya','jya'],'じゃ行'), ('じゅ','ju',['zyu','jyu'],'じゃ行'), ('じょ','jo',['zyo','jyo'],'じゃ行'),
        ('びゃ','bya',[],'びゃ行'), ('びゅ','byu',[],'びゃ行'), ('びょ','byo',[],'びゃ行'),
        ('ぴゃ','pya',[],'ぴゃ行'), ('ぴゅ','pyu',[],'ぴゃ行'), ('ぴょ','pyo',[],'ぴゃ行'),
    ]

    EXTENDED_KATAKANA = [
        # (char, romaji, [extra], row) — no hiragana counterpart
        ('ファ','fa',[],'拡張'),('フィ','fi',[],'拡張'),('フェ','fe',[],'拡張'),('フォ','fo',[],'拡張'),
        ('ウィ','wi',[],'拡張'),('ウェ','we',[],'拡張'),('ウォ','wo',[],'拡張'),
        ('ティ','ti',[],'拡張'),('ディ','di',[],'拡張'),
        ('チェ','che',[],'拡張'),('シェ','she',[],'拡張'),('ジェ','je',[],'拡張'),
        ('ツァ','tsa',[],'拡張'),('デュ','dyu',[],'拡張'),('フュ','fyu',[],'拡張'),
    ]

    def hira_to_kata(ch):
        return ''.join(chr(ord(c) + 0x60) for c in ch)

    def kata_to_hira(ch):
        return ''.join(chr(ord(c) - 0x60) for c in ch)

    kana_count = 0
    for (char, romaji, extras, row) in HIRAGANA_DATA:
        kata = hira_to_kata(char)
        acceptable = json.dumps([romaji] + extras, ensure_ascii=False)
        c.execute(
            'INSERT INTO kana (character,type,romaji,acceptable_romaji,row,counterpart) VALUES (?,?,?,?,?,?)',
            (char, 'hiragana', romaji, acceptable, row, kata)
        )
        c.execute(
            'INSERT INTO kana (character,type,romaji,acceptable_romaji,row,counterpart) VALUES (?,?,?,?,?,?)',
            (kata, 'katakana', romaji, acceptable, row, char)
        )
        kana_count += 2

    for (char, romaji, extras, row) in EXTENDED_KATAKANA:
        acceptable = json.dumps([romaji] + extras, ensure_ascii=False)
        c.execute(
            'INSERT INTO kana (character,type,romaji,acceptable_romaji,row,counterpart) VALUES (?,?,?,?,?,?)',
            (char, 'katakana', romaji, acceptable, row, None)
        )
        kana_count += 1

    print(f'Inserted {kana_count} kana characters')

    # Hiragana words (written entirely in hiragana)
    HIRAGANA_WORDS = [
        ('あし','ashi','foot / leg'),('あたま','atama','head'),('あめ','ame','rain'),
        ('あさ','asa','morning'),('あき','aki','autumn'),('あかちゃん','akachan','baby'),
        ('いえ','ie','house'),('いぬ','inu','dog'),('いもうと','imouto','younger sister'),
        ('うみ','umi','sea'),('うた','uta','song'),
        ('おかあさん','okaasan','mother'),('おとうさん','otousan','father'),
        ('おとこ','otoko','man'),('おんな','onna','woman'),('おなか','onaka','stomach'),
        ('かわ','kawa','river'),('かぜ','kaze','wind'),('かみ','kami','paper / hair / god'),
        ('きのう','kinou','yesterday'),('くすり','kusuri','medicine'),('くち','kuchi','mouth'),
        ('くも','kumo','cloud'),('こども','kodomo','child'),('こころ','kokoro','heart / mind'),
        ('さかな','sakana','fish'),('さくら','sakura','cherry blossom'),('さむい','samui','cold (weather)'),
        ('しごと','shigoto','work'),('しんぶん','shinbun','newspaper'),
        ('すし','sushi','sushi'),('そら','sora','sky'),('そと','soto','outside'),
        ('たべもの','tabemono','food'),('ちち','chichi','father / milk'),('つき','tsuki','moon'),
        ('てがみ','tegami','letter'),('でんしゃ','densha','train'),
        ('とり','tori','bird'),('ともだち','tomodachi','friend'),
        ('なまえ','namae','name'),('なつ','natsu','summer'),('なか','naka','inside / middle'),
        ('にく','niku','meat'),('にほん','nihon','Japan'),('ねこ','neko','cat'),
        ('のみもの','nomimono','drink'),
        ('はな','hana','flower / nose'),('はる','haru','spring'),('ひと','hito','person'),
        ('ふゆ','fuyu','winter'),('ふね','fune','ship / boat'),
        ('へや','heya','room'),('ほん','hon','book'),
        ('まち','machi','town'),('みず','mizu','water'),('みち','michi','road / path'),
        ('むすこ','musuko','son'),('むすめ','musume','daughter'),('もり','mori','forest'),
        ('やま','yama','mountain'),('ゆき','yuki','snow'),('よる','yoru','night'),
        ('りんご','ringo','apple'),('わたし','watashi','I / me'),
        ('こんにちは','konnichiwa','hello'),('ありがとう','arigatou','thank you'),
        ('おはよう','ohayou','good morning'),('さようなら','sayounara','goodbye'),
    ]

    KATAKANA_WORDS = [
        ('アイスクリーム','aisukuriimu','ice cream'),('アニメ','anime','anime'),
        ('アパート','apaato','apartment'),('アルバイト','arubaito','part-time job'),
        ('インターネット','intaanetto','internet'),('ウイルス','uirusu','virus'),
        ('エアコン','eakon','air conditioner'),('エレベーター','erebeetaa','elevator'),
        ('オレンジ','orenji','orange'),('カメラ','kamera','camera'),
        ('カレー','karee','curry'),('カレンダー','karendaa','calendar'),
        ('ギター','gitaa','guitar'),('コーヒー','koohii','coffee'),
        ('コンビニ','konbini','convenience store'),('コンピューター','konpyuutaa','computer'),
        ('サッカー','sakkaa','soccer'),('スーパー','suupaa','supermarket'),
        ('スポーツ','supootsu','sports'),('スマートフォン','sumaatofon','smartphone'),
        ('セーター','seetaa','sweater'),('タクシー','takushii','taxi'),
        ('テスト','tesuto','test / exam'),('テレビ','terebi','television'),
        ('デパート','depaato','department store'),('トイレ','toire','toilet'),
        ('ドア','doa','door'),('トマト','tomato','tomato'),
        ('ニュース','nyuusu','news'),('ノート','nooto','notebook'),
        ('バス','basu','bus'),('パソコン','pasokon','personal computer'),
        ('ハンバーガー','hanbaagaa','hamburger'),('ピアノ','piano','piano'),
        ('ビール','biiru','beer'),('フランス','furansu','France'),
        ('ベッド','beddo','bed'),('ホテル','hoteru','hotel'),
        ('マンション','manshon','apartment building'),('メール','meeru','email / mail'),
        ('ラジオ','rajio','radio'),('レストラン','resutoran','restaurant'),
        ('ロボット','robotto','robot'),('ワイン','wain','wine'),
        ('パン','pan','bread'),('バナナ','banana','banana'),
        ('チョコレート','chokoreeto','chocolate'),('ケーキ','keeki','cake'),
        ('ジュース','juusu','juice'),('コップ','koppu','cup / glass'),
        ('スプーン','supuun','spoon'),('フォーク','fooku','fork'),
        ('ナイフ','naifu','knife'),('テーブル','teeburu','table'),
        ('ピザ','piza','pizza'),('サラダ','sarada','salad'),
        ('スープ','suupu','soup'),('リモコン','rimokon','remote control'),
        ('シャワー','shawaa','shower'),('アラーム','araamu','alarm'),
        ('バスケットボール','basukettoboouru','basketball'),('サンドウィッチ','sandoicchi','sandwich'),
    ]

    word_count = 0
    for (word, romaji, meaning) in HIRAGANA_WORDS:
        c.execute(
            'INSERT INTO kana_words (word,romaji,acceptable_romaji,meaning,type) VALUES (?,?,?,?,?)',
            (word, romaji, json.dumps([romaji], ensure_ascii=False), meaning, 'hiragana')
        )
        word_count += 1
    for (word, romaji, meaning) in KATAKANA_WORDS:
        c.execute(
            'INSERT INTO kana_words (word,romaji,acceptable_romaji,meaning,type) VALUES (?,?,?,?,?)',
            (word, romaji, json.dumps([romaji], ensure_ascii=False), meaning, 'katakana')
        )
        word_count += 1
    print(f'Inserted {word_count} kana words')

    conn.commit()
    conn.close()
    size_mb = out_path.stat().st_size / 1024 / 1024
    print(f"Built {out_path} ({size_mb:.1f} MB)")

if __name__ == '__main__':
    try:
        # Run validation before building
        print("Running data validation...")
        if not validate_all():
            print("\nERROR: Data validation failed. Fix errors before building.", file=sys.stderr)
            sys.exit(1)

        print("\nBuilding database...")
        build()
    except FileNotFoundError as e:
        print(f"ERROR: missing input file: {e.filename}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    except sqlite3.Error as e:
        print(f"ERROR: database error: {e}", file=sys.stderr)
        sys.exit(1)
