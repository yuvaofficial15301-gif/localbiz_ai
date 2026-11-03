/// Normalises typed or spoken text so Tamil, English, Tanglish, Malayalam,
/// Kannada, Telugu and Hindi commands can be matched with one set of rules.
class Norm {
  static const Map<String, String> _numberWords = {
    // English
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
    'twenty': '20', 'fifty': '50', 'hundred': '100', 'half': '0.5',
    'quarter': '0.25',
    // Tamil
    'ஒன்று': '1', 'ஒரு': '1', 'இரண்டு': '2', 'மூன்று': '3', 'நான்கு': '4',
    'ஐந்து': '5', 'ஆறு': '6', 'ஏழு': '7', 'எட்டு': '8', 'ஒன்பது': '9',
    'பத்து': '10', 'அரை': '0.5',
    // Tanglish
    'onnu': '1', 'oru': '1', 'rendu': '2', 'moonu': '3', 'naalu': '4',
    'anju': '5', 'aaru': '6', 'ezhu': '7', 'ettu': '8', 'ombodhu': '9',
    'pathu': '10', 'arai': '0.5',
    // Malayalam
    'ഒന്ന്': '1', 'രണ്ട്': '2', 'മൂന്ന്': '3', 'നാല്': '4', 'അഞ്ച്': '5',
    'ആറ്': '6', 'ഏഴ്': '7', 'എട്ട്': '8', 'ഒമ്പത്': '9', 'പത്ത്': '10',
    'അര': '0.5',
    // Kannada
    'ಒಂದು': '1', 'ಎರಡು': '2', 'ಮೂರು': '3', 'ನಾಲ್ಕು': '4', 'ಐದು': '5',
    'ಆರು': '6', 'ಏಳು': '7', 'ಎಂಟು': '8', 'ಒಂಬತ್ತು': '9', 'ಹತ್ತು': '10',
    'ಅರ್ಧ': '0.5',
    // Telugu
    'ఒకటి': '1', 'రెండు': '2', 'మూడు': '3', 'నాలుగు': '4', 'ఐదు': '5',
    'ఆరు': '6', 'ఏడు': '7', 'ఎనిమిది': '8', 'తొమ్మిది': '9', 'పది': '10',
    'అర్ధ': '0.5',
    // Hindi
    'एक': '1', 'दो': '2', 'तीन': '3', 'चार': '4', 'पांच': '5', 'पाँच': '5',
    'छह': '6', 'सात': '7', 'आठ': '8', 'नौ': '9', 'दस': '10', 'आधा': '0.5',
  };

  /// Lower-case and strip zero-width joiners (keeps all other characters).
  static String base(String s) =>
      s.toLowerCase().replaceAll(RegExp('[\u200b\u200c\u200d\u2060]'), '');

  static String _asciiDigits(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      int? v;
      if (r >= 0x0966 && r <= 0x096F) {
        v = r - 0x0966;
      } else if (r >= 0x0BE6 && r <= 0x0BEF) {
        v = r - 0x0BE6;
      } else if (r >= 0x0D66 && r <= 0x0D6F) {
        v = r - 0x0D66;
      } else if (r >= 0x0CE6 && r <= 0x0CEF) {
        v = r - 0x0CE6;
      } else if (r >= 0x0C66 && r <= 0x0C6F) {
        v = r - 0x0C66;
      }
      if (v != null) {
        b.write(v);
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static String normalize(String raw) {
    var s = base(raw);
    s = s.replaceAll('₹', ' rs ');
    s = _asciiDigits(s);
    s = s.replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\.\s]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ');
    s = s.replaceAllMapped(
        RegExp(r'(\d)([^\d\s.])'), (m) => '${m[1]} ${m[2]}');
    s = s.replaceAllMapped(
        RegExp(r'([^\d\s.])(\d)'), (m) => '${m[1]} ${m[2]}');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return s;
    final out = <String>[];
    for (final t in s.split(' ')) {
      out.add(_numberWords[t] ?? t);
    }
    return out.join(' ');
  }

  static bool isLatin(String w) => w.isNotEmpty && w.codeUnitAt(0) < 0x250;
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = prev[j] + 1;
      if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
      if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
      cur[j] = v;
    }
    prev = cur;
  }
  return prev[b.length];
}
