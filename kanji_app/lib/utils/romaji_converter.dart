import 'package:flutter/services.dart';

class RomajiConverter {
  static const _map = {
    // vowels
    'a':'あ','i':'い','u':'う','e':'え','o':'お',
    // k
    'ka':'か','ki':'き','ku':'く','ke':'け','ko':'こ',
    // s
    'sa':'さ','si':'し','su':'す','se':'せ','so':'そ',
    'shi':'し',
    // t
    'ta':'た','ti':'ち','tu':'つ','te':'て','to':'と',
    'chi':'ち','tsu':'つ',
    // n
    'na':'な','ni':'に','nu':'ぬ','ne':'ね','no':'の',
    // h
    'ha':'は','hi':'ひ','hu':'ふ','he':'へ','ho':'ほ',
    'fu':'ふ',
    // m
    'ma':'ま','mi':'み','mu':'む','me':'め','mo':'も',
    // y
    'ya':'や','yu':'ゆ','yo':'よ',
    // r
    'ra':'ら','ri':'り','ru':'る','re':'れ','ro':'ろ',
    // w
    'wa':'わ','wi':'ゐ','we':'ゑ','wo':'を',
    // n alone
    'n':'ん','nn':'ん',
    // g
    'ga':'が','gi':'ぎ','gu':'ぐ','ge':'げ','go':'ご',
    // z
    'za':'ざ','zi':'じ','zu':'ず','ze':'ぜ','zo':'ぞ',
    'ji':'じ',
    // d
    'da':'だ','di':'ぢ','du':'づ','de':'で','do':'ど',
    // b
    'ba':'ば','bi':'び','bu':'ぶ','be':'べ','bo':'ぼ',
    // p
    'pa':'ぱ','pi':'ぴ','pu':'ぷ','pe':'ぺ','po':'ぽ',
    // compound
    'kya':'きゃ','kyu':'きゅ','kyo':'きょ',
    'sha':'しゃ','shu':'しゅ','sho':'しょ',
    'cha':'ちゃ','chu':'ちゅ','cho':'ちょ',
    'nya':'にゃ','nyu':'にゅ','nyo':'にょ',
    'hya':'ひゃ','hyu':'ひゅ','hyo':'ひょ',
    'mya':'みゃ','myu':'みゅ','myo':'みょ',
    'rya':'りゃ','ryu':'りゅ','ryo':'りょ',
    'gya':'ぎゃ','gyu':'ぎゅ','gyo':'ぎょ',
    'ja':'じゃ','ju':'じゅ','jo':'じょ',
    'bya':'びゃ','byu':'びゅ','byo':'びょ',
    'pya':'ぴゃ','pyu':'ぴゅ','pyo':'ぴょ',
  };

  static const _consonants = {'k','s','t','n','h','m','y','r','w','g','z','d','b','p','c','f','j'};

  static String convert(String romaji) {
    final buf = StringBuffer();
    int i = 0;
    while (i < romaji.length) {
      // double consonant → っ
      if (i + 1 < romaji.length &&
          romaji[i] == romaji[i + 1] &&
          _consonants.contains(romaji[i]) &&
          romaji[i] != 'n') {
        buf.write('っ');
        i++;
        continue;
      }
      // try 3-char match first
      if (i + 3 <= romaji.length) {
        final tri = romaji.substring(i, i + 3);
        if (_map.containsKey(tri)) {
          buf.write(_map[tri]);
          i += 3;
          continue;
        }
      }
      // try 2-char match
      if (i + 2 <= romaji.length) {
        final bi = romaji.substring(i, i + 2);
        if (_map.containsKey(bi)) {
          buf.write(_map[bi]);
          i += 2;
          continue;
        }
      }
      // n before consonant = ん; trailing n stays as 'n' (awaiting next char)
      if (romaji[i] == 'n') {
        final next = i + 1 < romaji.length ? romaji[i + 1] : '';
        if (next.isEmpty) {
          buf.write('ん');
          i++;
          continue;
        }
        if (_consonants.contains(next)) {
          buf.write('ん');
          i++;
          continue;
        }
      }
      // single char fallback (vowel or unknown)
      final single = romaji[i];
      buf.write(_map[single] ?? single);
      i++;
    }
    return buf.toString();
  }
}

class RomajiInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final converted = RomajiConverter.convert(next.text);
    return next.copyWith(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}
