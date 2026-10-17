/// Normalisation de recherche (ADR-007), identique pour le texte indexé et
/// pour la saisie de l'utilisateur : minuscules, accents retirés, « œ » → « oe »,
/// apostrophes, ponctuation et espaces (insécables compris) → un seul espace.
/// Cas de référence : packages/shared_contracts/fixtures/search/normalization.json.
String fold(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buffer.write(_foldRune(rune));
  }
  return buffer.toString().replaceAll(_spaces, ' ').trim();
}

final _spaces = RegExp(r'\s+');

/// Lettres latines et chiffres conservés ; tout le reste devient un espace.
final _wordChar = RegExp(r'[a-z0-9]');

String _foldRune(int rune) {
  final mapped = _map[rune];
  if (mapped != null) return mapped;
  final char = String.fromCharCode(rune);
  return _wordChar.hasMatch(char) ? char : ' ';
}

const _map = <int, String>{
  0xe0: 'a', 0xe1: 'a', 0xe2: 'a', 0xe3: 'a', 0xe4: 'a', 0xe5: 'a', // àáâãäå
  0xe6: 'ae', 0x153: 'oe', // æ œ
  0xe7: 'c', // ç
  0xe8: 'e', 0xe9: 'e', 0xea: 'e', 0xeb: 'e', // èéêë
  0xec: 'i', 0xed: 'i', 0xee: 'i', 0xef: 'i', // ìíîï
  0xf1: 'n', // ñ
  0xf2: 'o', 0xf3: 'o', 0xf4: 'o', 0xf5: 'o', 0xf6: 'o', // òóôõö
  0xf9: 'u', 0xfa: 'u', 0xfb: 'u', 0xfc: 'u', // ùúûü
  0xfd: 'y', 0xff: 'y', // ýÿ
};
