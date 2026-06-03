import xml.etree.ElementTree as ET
import json
from pathlib import Path

def parse(xml_path: str) -> list[dict]:
    tree = ET.parse(xml_path)
    root = tree.getroot()
    kanji_list = []
    for char in root.findall('character'):
        literal = char.findtext('literal')
        misc = char.find('misc')
        jlpt = misc.findtext('jlpt') if misc is not None else None
        if jlpt is None:
            continue  # skip non-JLPT kanji
        grade = misc.findtext('grade')
        stroke = misc.findtext('stroke_count')
        rmgroup = char.find('.//rmgroup')
        on_readings = [r.text for r in rmgroup.findall("reading[@r_type='ja_on']")] if rmgroup is not None else []
        kun_readings = [r.text for r in rmgroup.findall("reading[@r_type='ja_kun']")] if rmgroup is not None else []
        meanings = [m.text for m in rmgroup.findall('meaning') if m.get('m_lang') is None] if rmgroup is not None else []
        kanji_list.append({
            'character': literal,
            'jlpt_level': int(jlpt),
            'on_reading': '・'.join(on_readings),
            'kun_reading': '・'.join(kun_readings),
            'meaning': ', '.join(meanings[:3]),
            'stroke_count': int(stroke.strip()) if stroke else 0,
        })
    return kanji_list

if __name__ == '__main__':
    script_dir = Path(__file__).parent
    data = parse(str(script_dir / 'kanjidic2.xml'))
    with open(script_dir / 'data' / 'kanji.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Parsed {len(data)} JLPT kanji")
