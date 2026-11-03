import 'keywords.dart';
import 'text_normalizer.dart';

class ProductRef {
  final int id;
  final String name;
  final String unit;
  final List<String> candidates; // normalised names, alternatives, synonyms
  const ProductRef(this.id, this.name, this.unit, this.candidates);
}

/// Resolves a spoken/typed product name to a product in the local database.
/// Multilingual synonym groups only help *matching*; they never create data.
class ProductMatcher {
  static const List<List<String>> synonymGroups = [
    ['rice', 'arisi', 'அரிசி', 'അരി', 'ಅಕ್ಕಿ', 'బియ్యం', 'చావల్', 'चावल', 'chawal', 'biyyam', 'akki'],
    ['sugar', 'sakkarai', 'சர்க்கரை', 'சீனி', 'சக்கரை', 'പഞ്ചസാര', 'ಸಕ್ಕರೆ', 'చక్కెర', 'चीनी', 'शक्कर', 'cheeni', 'shakkar', 'panchasara', 'sakkare'],
    ['oil', 'ennai', 'எண்ணெய்', 'എണ്ണ', 'ಎಣ್ಣೆ', 'నూనె', 'तेल', 'tel', 'enne'],
    ['wheat', 'godhumai', 'கோதுமை', 'ഗോതമ്പ്', 'ಗೋಧಿ', 'గోధుమ', 'गेहूं', 'गेहु', 'gehun', 'atta'],
    ['dal', 'paruppu', 'பருப்பு', 'പരിപ്പ്', 'ಬೇಳೆ', 'పప్పు', 'दाल', 'dhal'],
    ['salt', 'uppu', 'உப்பு', 'ഉപ്പ്', 'ಉಪ್ಪು', 'ఉప్పు', 'नमक', 'namak'],
    ['milk', 'paal', 'பால்', 'പാൽ', 'ಹಾಲು', 'పాలు', 'दूध', 'doodh', 'haalu'],
    ['tea', 'chai', 'தேநீர்', 'டீ', 'ചായ', 'ಚಹಾ', 'టీ', 'चाय'],
    ['coffee', 'kaapi', 'காபி', 'കാപ്പി', 'ಕಾಫಿ', 'కాఫీ', 'कॉफी'],
    ['onion', 'vengayam', 'வெங்காயம்', 'ഉള്ളി', 'ಈರುಳ್ಳಿ', 'ఉల్లిపాయ', 'प्याज', 'pyaz'],
    ['tomato', 'thakkali', 'தக்காளி', 'തക്കാളി', 'ಟೊಮೇಟೊ', 'టమాటా', 'टमाटर'],
    ['potato', 'urulai', 'உருளைக்கிழங்கு', 'ഉരുളക്കിഴങ്ങ്', 'ಆಲೂಗಡ್ಡೆ', 'బంగాళాదుంప', 'आलू', 'aloo'],
    ['bread', 'ரொட்டி', 'ബ്രെഡ്', 'ಬ್ರೆಡ್', 'బ్రెడ్', 'ब्रेड', 'पाव'],
    ['egg', 'muttai', 'முட்டை', 'മുട്ട', 'ಮೊಟ್ಟೆ', 'గుడ్డు', 'अंडा', 'anda'],
    ['soap', 'சோப்பு', 'സോപ്പ്', 'ಸೋಪು', 'సబ్బు', 'साबुन'],
    ['pen', 'பேனா', 'പേന', 'ಪೆನ್', 'పెన్', 'कलम'],
    ['notebook', 'note book', 'நோட்டு', 'നോട്ട്ബുക്ക്', 'ನೋಟ್ಬುಕ್', 'నోట్బుక్', 'कॉपी'],
  ];

  static List<ProductRef> build(List<Map<String, Object?>> rows) {
    final groups = synonymGroups
        .map((g) => g.map(Norm.normalize).where((e) => e.isNotEmpty).toList())
        .toList();
    final out = <ProductRef>[];
    for (final r in rows) {
      final name = r['name'] as String;
      final alts = ((r['alt_names'] as String?) ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      final own = <String>{Norm.normalize(name), ...alts.map(Norm.normalize)}
        ..removeWhere((e) => e.isEmpty);
      final cands = <String>{...own};
      for (final g in groups) {
        if (g.any(own.contains)) cands.addAll(g);
      }
      out.add(ProductRef(r['id'] as int, name, (r['unit'] as String?) ?? 'kg',
          cands.toList()));
    }
    return out;
  }

  /// Best product for the normalised text, or null.
  static ProductRef? find(String norm, List<String> tokens, List<ProductRef> prods) {
    ProductRef? best;
    var bestScore = 0;
    final padded = ' $norm ';
    for (final p in prods) {
      for (final c in p.candidates) {
        if (c.isEmpty) continue;
        var score = 0;
        if (Norm.isLatin(c)) {
          if (c.contains(' ')) {
            if (padded.contains(' $c ')) score = c.length + 10;
          } else {
            for (final t in tokens) {
              if (t == c) {
                score = c.length + 10;
                break;
              }
              if (c.length >= 4 && t.startsWith(c) && t.length <= c.length + 3) {
                score = c.length + 5;
              }
            }
          }
        } else if (c.length >= 2 && norm.contains(c)) {
          score = c.length + 10;
        }
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
    }
    if (best != null) return best;

    // Fuzzy fallback for small spelling differences in Latin text.
    var bestDist = 99;
    for (final t in tokens) {
      if (t.length < 4 || Kw.isNum(t) || Kw.stop.contains(t)) continue;
      if (!Norm.isLatin(t)) continue;
      for (final p in prods) {
        for (final c in p.candidates) {
          if (!Norm.isLatin(c) || c.contains(' ') || c.length < 4) continue;
          final d = levenshtein(t, c);
          final allowed = c.length <= 6 ? 1 : 2;
          if (d <= allowed && d < bestDist) {
            bestDist = d;
            best = p;
          }
        }
      }
    }
    return best;
  }
}
