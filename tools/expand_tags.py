import json
from pathlib import Path

def expand_tags():
    """Expand tag coverage from 155 to all 2230 kanji."""

    base = Path(__file__).parent

    # Load current tags
    with open(base / 'data' / 'kanji_tags.json', encoding='utf-8') as f:
        tagged = json.load(f)

    # Build map of character to tags
    char_to_tags = {}
    for entry in tagged:
        char_to_tags[entry['kanji_id']] = entry.get('tags', [])

    print(f"Currently tagged: {sum(1 for tags in char_to_tags.values() if tags)} / {len(char_to_tags)}")

    # Load all kanji
    with open(base / 'data' / 'kanji.json', encoding='utf-8') as f:
        all_kanji = json.load(f)

    print(f"Total kanji in database: {len(all_kanji)}")

    # Assign basic tags to kanji with empty tags
    level_tags = {
        1: ['n1', 'advanced'],
        2: ['n2', 'intermediate'],
        3: ['n3', 'intermediate'],
        4: ['n4', 'beginner'],
        5: ['miscellaneous'],
    }

    assigned_count = 0
    for kanji in all_kanji:
        char = kanji['character']
        level = kanji['jlpt_level']

        # If no tags or empty tags, assign based on JLPT level
        if char not in char_to_tags or not char_to_tags[char]:
            char_to_tags[char] = level_tags.get(level, ['miscellaneous'])
            assigned_count += 1

    print(f"Assigned tags to: {assigned_count} kanji")

    # Rebuild tagged list
    tagged = [
        {'kanji_id': char, 'tags': tags}
        for char, tags in char_to_tags.items()
    ]

    # Save expanded tags
    with open(base / 'data' / 'kanji_tags.json', 'w', encoding='utf-8') as f:
        json.dump(tagged, f, ensure_ascii=False, indent=2)

    print(f"Expanded to: {len(tagged)} kanji with tags")
    print(f"Tagged count: {sum(1 for t in tagged if t['tags'])}")

if __name__ == '__main__':
    expand_tags()
