"""Annotates N5 question hiragana text with {kanji|reading} furigana markup."""
import json, re
from pathlib import Path

WORD_DICT = {
    # Nouns
    'まいあさ': '毎朝', 'まいにち': '毎日', 'がっこう': '学校',
    'としょかん': '図書館', 'せんせい': '先生', 'こくばん': '黒板',
    'でんわ': '電話', 'おんがく': '音楽', 'えいが': '映画',
    'しんぶん': '新聞', 'にほんご': '日本語', 'にほん': '日本',
    'かいしゃ': '会社', 'しごと': '仕事', 'でんしゃ': '電車',
    'じかん': '時間', 'こうえん': '公園', 'しゃしん': '写真',
    'じしょ': '辞書', 'ちず': '地図', 'くすり': '薬',
    'あたま': '頭', 'ことば': '言葉', 'いみ': '意味',
    'みず': '水', 'ごはん': 'ご飯', 'あさごはん': '朝ご飯',
    'やさい': '野菜', 'にく': '肉', 'たまご': '卵',
    'まど': '窓', 'でんき': '電気', 'えき': '駅',
    'みせ': '店', 'ほん': '本', 'つくえ': '机',
    'はな': '花', 'あめ': '雨', 'かさ': '傘',
    'くるま': '車', 'かれ': '彼', 'かのじょ': '彼女',
    'あに': '兄', 'あね': '姉', 'いえ': '家', 'へや': '部屋',
    'よる': '夜', 'ごご': '午後', 'ふく': '服', 'かみ': '髪',
    'くつ': '靴', 'てがみ': '手紙', 'ともだち': '友達',
    'あした': '明日', 'きのう': '昨日', 'きょう': '今日',
    'かばん': '鞄', 'ちゅうしゃじょう': '駐車場',
    'がくせい': '学生', 'えいご': '英語',
    'おなか': 'お腹', 'のど': '喉',
    'あたらしい': '新しい', 'やさしい': '優しい',
    'たかい': '高い', 'やすい': '安い', 'おいしい': '美味しい',
    'わたし': '私', 'うみ': '海', 'やま': '山',
    'とうきょう': '東京', 'おおさか': '大阪',
    # Verb stems only (no する endings mixed in)
    'べんきょう': '勉強',
    # Verb stem forms used as standalone options
    'きき': '聞き', 'よみ': '読み', 'のみ': '飲み',
    'たべ': '食べ', 'かき': '書き', 'はなし': '話し',
    # Complete conjugated forms
    'かきました': '書きました', 'よみました': '読みました',
    'みました': '見ました', 'たべました': '食べました',
    'のみました': '飲みました', 'かいました': '買いました',
    'いきました': '行きました', 'きました': '来ました',
    'かえりました': '帰りました', 'はなしました': '話しました',
    'ならいました': '習いました', 'おきました': '起きました',
    'ねました': '寝ました', 'でました': '出ました',
    'はいりました': '入りました', 'あいました': '会いました',
    'つかいました': '使いました', 'つくりました': '作りました',
    'おしえました': '教えました', 'うりました': '売りました',
    'さがしました': '探しました',
    'かきます': '書きます', 'よみます': '読みます',
    'みます': '見ます', 'たべます': '食べます',
    'のみます': '飲みます', 'かいます': '買います',
    'いきます': '行きます', 'きます': '来ます',
    'かえります': '帰ります', 'はなします': '話します',
    'ならいます': '習います', 'おきます': '起きます',
    'ねます': '寝ます', 'でます': '出ます',
    'はいります': '入ります', 'つかいます': '使います',
    'おしえます': '教えます', 'やすみます': '休みます',
    'はたらきます': '働きます', 'あそびます': '遊びます',
    'もちます': '持ちます', 'とまります': '止まります',
    'かいません': '買いません', 'いきません': '行きません',
    'おしえません': '教えません', 'よみません': '読みません',
    'かきません': '書きません', 'ならいません': '習いません',
    'たべません': '食べません', 'のみません': '飲みません',
    'つかいません': '使いません',
    'けして': '消して', 'つけて': '付けて',
    'しめて': '閉めて', 'あけて': '開けて',
    'はいって': '入って', 'かえって': '帰って',
    'でて': '出て', 'たべて': '食べて',
    'のんで': '飲んで', 'かって': '買って',
    'とって': '撮って', 'かりて': '借りて',
    'ならべて': '並べて', 'つかって': '使って',
    'つくって': '作って', 'あらって': '洗って',
    'はなして': '話して', 'おしえて': '教えて',
    'さいて': '咲いて', 'ふって': '降って',
    'きいて': '聞いて', 'いって': '行って',
    'ねて': '寝て', 'でかけます': '出かけます',
    'さきます': '咲きます',
}

# Particles that trail nouns (never stand alone as kanji)
PARTICLES = ['は', 'が', 'を', 'に', 'で', 'と', 'も', 'へ', 'か', 'よ', 'ね',
             'から', 'まで', 'より', 'だけ', 'ので', 'のに', 'にも', 'への',
             'だと', 'でも', 'など', 'まで']
PARTICLES.sort(key=len, reverse=True)

# Prefixes that are not kanji-ified (demonstratives, this/that)
NON_KANJI_PREFIXES = ['この', 'その', 'あの', 'どの', 'どれも', 'なにも']

def annotate_segment(text):
    """Annotate a single hiragana segment (no spaces), return annotated string."""
    if not text:
        return text

    # Check exact match
    if text in WORD_DICT:
        kanji = WORD_DICT[text]
        return f'{{{kanji}|{text}}}' if kanji != text else text

    # Try stripping trailing particles to find stem
    for p in PARTICLES:
        if text.endswith(p) and len(text) > len(p):
            stem = text[:-len(p)]
            if stem in WORD_DICT:
                kanji = WORD_DICT[stem]
                if kanji != stem:
                    return f'{{{kanji}|{stem}}}' + p
    
    # Try stripping non-kanji prefix (この, その, etc.)
    for prefix in NON_KANJI_PREFIXES:
        if text.startswith(prefix) and len(text) > len(prefix):
            rest = text[len(prefix):]
            annotated_rest = annotate_segment(rest)
            if annotated_rest != rest:
                return prefix + annotated_rest

    # Greedy longest-prefix match
    best_len = 0
    for key in WORD_DICT:
        if text.startswith(key) and len(key) > best_len:
            best_len = len(key)
    if best_len >= 2:
        stem = text[:best_len]
        kanji = WORD_DICT[stem]
        if kanji != stem:
            suffix = annotate_segment(text[best_len:])
            return f'{{{kanji}|{stem}}}' + suffix

    return text

def annotate_chunk(chunk):
    """Annotate one space-delimited chunk, handling trailing punctuation."""
    if not chunk:
        return chunk
    # Check if chunk contains kanji/katakana already (pass through)
    if any('一' <= c <= '鿿' or '゠' <= c <= 'ヿ' for c in chunk):
        return chunk
    
    # Strip trailing punctuation
    punct_suffix = ''
    text = chunk
    while text and text[-1] in '。、！？』』～…':
        punct_suffix = text[-1] + punct_suffix
        text = text[:-1]
    
    return annotate_segment(text) + punct_suffix

def annotate(text):
    if not text:
        return text
    parts = text.split(' ')
    return ' '.join(annotate_chunk(p) for p in parts)

# Apply to questions (re-load clean JSON, removing previous display fields)
questions = json.load(open(str(Path(__file__).parent / 'data' / 'n5_questions.json')))

# Remove any old display fields first
for q in questions:
    for k in list(q.keys()):
        if k.endswith('_display'):
            del q[k]

changed = 0
for q in questions:
    for field in ['question_stem', 'option_1', 'option_2', 'option_3', 'option_4',
                  'passage', 'passage_title']:
        if q.get(field) is None:
            continue
        disp = annotate(q[field])
        if disp != q[field]:
            q[f'{field}_display'] = disp
            changed += 1

print(f"Added display annotations to {changed} fields\n")

# Spot-check
for q in questions[:20]:
    stem_d = q.get('question_stem_display', q['question_stem'])
    if stem_d != q['question_stem']:
        opts = []
        for i in range(1, 5):
            opts.append(q.get(f'option_{i}_display', q[f'option_{i}']))
        print(f"  {q['question_stem']}")
        print(f"→ {stem_d}")
        print(f"  Opts: {opts}")
        print()

with open(str(Path(__file__).parent / 'data' / 'n5_questions.json'), 'w', encoding='utf-8') as f:
    json.dump(questions, f, ensure_ascii=False, indent=2)
print("Saved.")
