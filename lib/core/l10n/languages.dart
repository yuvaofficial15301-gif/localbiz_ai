/// Supported languages. Add a new entry here (and strings in strings.dart)
/// to support another Indian language.
class Lang {
  final String code;
  final String name; // English name
  final String native;
  final String speechLocale; // speech_to_text locale, e.g. ta_IN
  final String ttsLocale; // flutter_tts locale, e.g. ta-IN
  final int index; // column in the strings tables
  const Lang(this.code, this.name, this.native, this.speechLocale,
      this.ttsLocale, this.index);
}

class Languages {
  static const List<Lang> all = [
    Lang('en', 'English', 'English', 'en_IN', 'en-IN', 0),
    Lang('ta', 'Tamil', 'தமிழ்', 'ta_IN', 'ta-IN', 1),
    Lang('ta_en', 'Tamil-English (Tanglish)', 'Tamil + English', 'en_IN', 'en-IN', 2),
    Lang('ml', 'Malayalam', 'മലയാളം', 'ml_IN', 'ml-IN', 3),
    Lang('kn', 'Kannada', 'ಕನ್ನಡ', 'kn_IN', 'kn-IN', 4),
    Lang('te', 'Telugu', 'తెలుగు', 'te_IN', 'te-IN', 5),
    Lang('hi', 'Hindi', 'हिन्दी', 'hi_IN', 'hi-IN', 6),
  ];

  static Lang byCode(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => all.first);

  /// Detects the script of [text]; returns [fallback] for Latin/unknown text.
  static String detect(String text, String fallback) {
    var ta = 0, ml = 0, kn = 0, te = 0, hi = 0;
    for (final r in text.runes) {
      if (r >= 0x0B80 && r <= 0x0BFF) {
        ta++;
      } else if (r >= 0x0D00 && r <= 0x0D7F) {
        ml++;
      } else if (r >= 0x0C80 && r <= 0x0CFF) {
        kn++;
      } else if (r >= 0x0C00 && r <= 0x0C7F) {
        te++;
      } else if (r >= 0x0900 && r <= 0x097F) {
        hi++;
      }
    }
    final best = [ta, ml, kn, te, hi].reduce((a, b) => a > b ? a : b);
    if (best == 0) return fallback;
    if (best == ta) return 'ta';
    if (best == ml) return 'ml';
    if (best == kn) return 'kn';
    if (best == te) return 'te';
    return 'hi';
  }
}
