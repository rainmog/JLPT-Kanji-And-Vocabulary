# JLPT Test Guidelines

How the JLPT practice tests are built, stored, rendered, and validated. Read this
before adding, editing, or auditing any question. Rules and gotchas here were
learned the hard way — keep them current.

> Companion docs: [DEVNOTES.md](DEVNOTES.md) (gotchas index), [DESIGN.md](DESIGN.md).

---

## 1. Source of truth & build pipeline

**Questions live in JSON, not in the DB.** Never hand-edit `kanji.db` — it is
generated and your edits will be overwritten on the next build.

```
tools/data/n{1..5}_questions.json     ← edit HERE (source of truth)
        │  tools/build_db.py
        ▼
kanji_app/assets/kanji.db  (table: jlpt_questions)   ← generated, shipped in app
```

- `tools/build_db.py` → `_insert_jlpt_questions(path, level)` does
  `DELETE FROM jlpt_questions WHERE level=N` then re-inserts the whole file.
  So a level's questions are fully replaced from its JSON each build.
- Translations: `tools/translate_jlpt.py` (needs `ANTHROPIC_API_KEY`) writes
  `question_translation` / `passage_translation`; `tools/apply_translations.py`
  re-applies without the API. Re-run `build_db.py` after either.
- **Do not bump `_assetDbVersion`** casually — a bump rebuilds the on-device DB
  and only preserves kanji `user_progress`, wiping vocab/kana progress
  (DEVNOTES gotcha 26). Question content ships in the asset DB, so shipping new
  questions *does* require a version bump — coordinate it with a progress-safe
  migration.

### Level encoding is inverted (the #1 footgun)

`level` / `jlpt_level`: **1 = N1 (hardest) … 5 = N5 (easiest)**. Throughout the
codebase. N5 questions = `level = 5`.

---

## 2. Schema — `jlpt_questions`

| column | meaning |
|---|---|
| `id` | PK (assigned by DB, not JSON) |
| `level` | 1–5, inverted (see above) |
| `section` | `vocabulary` \| `grammar` \| `reading` |
| `question_type` | see §3 |
| `passage_id` | groups reading questions to a shared passage; `null` otherwise |
| `passage`, `passage_title` | plain-kana passage text (reading only) |
| `question_stem` | the prompt, plain kana/text |
| `option_1..4` | the four choices, plain text |
| `correct_option` | **1-based** index (1–4) of the right choice |
| `*_display` | furigana-markup variants (see §4); `null` = render plain field |
| `correct_order` | reorder only: full sequence of option indices (see §3.6) |
| `question_translation`, `passage_translation` | English, `**bold**` on answer |

`correctAnswer` in code = `options[correct_option - 1]`.

---

## 3. Sections & question types

Current N5 mix (115 total) — treat as the target ratio when scaling:

| section | type | count | share |
|---|---|---|---|
| vocabulary | `fill_blank` | 50 | 43% |
| grammar | `fill_blank` | 30 | 26% |
| reading | `comprehension` | 12 | 10% |
| vocabulary | `kanji_reading` | 10 | 9% |
| vocabulary | `kanji_writing` | 8 | 7% |
| grammar | `sentence_reorder` | 5 | 4% |

### 3.1 vocabulary / fill_blank
Sentence with `（　　）`; pick the word that fits. Distractors are real words of
the **same part of speech** that are wrong in context. Options usually carry
`option_N_display` furigana. Example: turn off / turn on / close / open the TV.

### 3.2 grammar / fill_blank
Same shape but the blank tests a **particle or grammar form** (を/に/で/が, verb
form, etc.). Distractors are other grammatically-possible-looking particles/forms
that are wrong here. Usually only `question_stem_display` is set (options are
short kana).

### 3.3 reading / comprehension
`passage_id` links 1+ questions to one `passage` (+ `passage_title`). Passage is
short, level-appropriate (notice, menu, note, short letter). Each question stands
alone but is answerable **only from the passage**. Passage gets its own
translation; a passage interstitial shows before its question group.

### 3.4 vocabulary / kanji_reading
Stem shows a kanji in context and asks its reading. Options are **kana readings**
→ `option_*_display` are `null` (nothing to furigana-ize). Distractors are
plausible wrong readings (other kanji's readings, on/kun confusion).

### 3.5 vocabulary / kanji_writing
Stem gives a word in kana and asks which **kanji** writes it. Options are kanji
(with `option_N_display` furigana so the learner can check). Distractors are
visually/semantically near kanji.

### 3.6 grammar / sentence_reorder  ⚠ most error-prone
Stem has four blanks `〔　　〕`; the learner drags all four options into order; the
graded position is the ★ slot.

- `correct_order` = comma list of option indices in the **correct full order**,
  e.g. `"1,3,4,2"` → slot1=opt1, slot2=opt3, slot3=opt4, slot4=opt2.
- `correct_option` = the option that belongs in the **★ slot**.
- Code (`jlpt_repository.dart` `starSlotIndex`) derives the star position as
  `correct_order.indexOf(correct_option)`. So **`correct_option` MUST appear in
  `correct_order`**, and the star lands wherever that option sits.
- Fairness: the intended full ordering must be the **only natural** ordering, and
  the ★-slot word must be unambiguous. Avoid sentences where two orderings are
  both grammatical.

---

## 4. Furigana display markup

`*_display` fields use ruby syntax: `{漢字|かんじ}`. Multiple runs concatenate:
`{私|わたし}は {毎日|まいにち} {学校|がっこう} …`. Rules:

- A `_display` field of `null` means "render the plain field as-is" (used when the
  text is already all kana, e.g. kanji_reading options).
- Every `{kanji|reading}` reading must be correct hiragana for that kanji **in
  that word** (watch on/kun and okurigana: 食べる → `{食べ|た}べる`).
- Okurigana stays outside the braces (only the kanji gets ruby).
- Keep spacing identical to the plain field so the two render in the same layout.

---

## 5. Translation fields

- `question_translation`: English of the stem, with the **correct answer in
  `**bold**`** (renders bold in-app via `_translationText()`).
- `passage_translation`: English of the passage; line breaks preserved.
- For fill-blank, the blank is filled with the English answer, bolded.

---

## 6. Fairness rules (what the audit enforces)

A question is **unfair** and must be fixed if any of these fail:

1. **Exactly one correct option.** No second option that is also fully correct in
   context (the classic "dual answer"). This is the top thing to hunt for.
2. **`correct_option` ∈ 1..4** and points at the genuinely correct choice.
3. **Distractors are wrong** — plausible but clearly incorrect to someone who
   knows the point. No distractor that is a synonym/equally-valid answer.
4. **No duplicate options** (no two identical option strings).
5. **Same category options** — all four are the same POS / same kind (all
   particles, all verbs in same form, all kanji, all readings). No odd-one-out
   that gives the answer away by shape.
6. **No answer leakage** — the stem (or another option, or the furigana) must not
   reveal the answer. E.g. don't furigana-annotate the very kanji whose reading is
   being tested.
7. **Level-appropriate.**
   - N5 stems are mostly kana; kanji used should be within N5 kanji scope and
     carry furigana in `_display`.
   - Grammar/vocab must be within the level's scope list — no N3 grammar in an N5
     item.
8. **Reading questions answerable from the passage** — not from outside knowledge,
   and not ambiguous between two options.
9. **Reorder** — unique natural ordering; `correct_option` present in
   `correct_order`; ★-slot answer unambiguous (see §3.6).
10. **Natural Japanese** — the correct sentence reads as something a native would
    actually say. No stilted filler just to make a distractor wrong.
11. **No offensive / politically loaded / real-person content.**

---

## 7. Copyright

**Do not copy official JLPT past papers or any copyrighted practice book.** Those
items are © JEES/publishers. Allowed inputs are *facts / scope lists*:

- Kanji, vocab, and grammar **scope lists** for each level (which items are
  testable) — these are facts, fine to use.
- Public CC-licensed word lists already in the repo (e.g. Waller/tanos, CC BY).

Write **original** stems, passages, and distractors. Inspiration from the *style*
and *difficulty* of real tests is fine; verbatim reuse is not.

---

## 8. Authoring checklist (per new question)

- [ ] Correct `level` (inverted!) and `section` / `question_type`.
- [ ] `correct_option` is 1-based and points at the one right answer.
- [ ] Exactly one correct answer; distractors same-category and clearly wrong.
- [ ] `_display` furigana set where needed, readings verified, spacing matches.
- [ ] `question_translation` present, answer bolded.
- [ ] Reading: `passage_id` set + `passage`/`passage_translation` present.
- [ ] Reorder: `correct_order` set, `correct_option` ∈ it, unique ordering.
- [ ] Within level scope; natural Japanese; original (not copied).
- [ ] No duplicate of an existing item in the same level file.

---

## 9. Validation tooling

`tools/validate_database.py` today validates **sentences**, not questions.
Question fairness is being added as a dedicated validator (`validate_questions.py`)
that mechanically checks: 1-based correct_option in range, no duplicate options,
reorder `correct_option ∈ correct_order`, `_display` readings are kana, translation
present, and flags exact-duplicate stems. Semantic checks (dual answers, level
scope, natural Japanese) still need human/LLM review — the mechanical pass narrows
where to look.

Run order when changing questions:
```
python3 tools/validate_questions.py --level 5   # mechanical fairness pass
python3 tools/build_db.py                        # rebuild asset DB
```

---

## 10. Open questions (need your input)

- **Target size per level.** N5 is being 4×'d to ~460. Same for N1–N4 later, or
  N5 only for now?
- **Section ratio on scale-up.** Keep the current N5 mix (§3), or shift (e.g. more
  reading passages)?
- **Reading passage length cap** for N5 — how long is too long?
- Should `validate_questions.py` run in CI / as a pre-build gate?

<!-- Add decisions here as we make them so the guidelines stay the single source. -->
