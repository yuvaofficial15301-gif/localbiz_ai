import 'dart:math';

/// Exact money handling in integer minor units (paise).
class Money {
  static String symbol = '₹';

  static String format(int paise, {String? sym}) {
    final s = sym ?? symbol;
    final neg = paise < 0;
    final a = paise.abs();
    final whole = _group(a ~/ 100);
    final frac = a % 100;
    final body = frac == 0 ? whole : '$whole.${frac.toString().padLeft(2, '0')}';
    return '${neg ? '-' : ''}$s$body';
  }

  /// Indian digit grouping: 12,34,567
  static String _group(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  /// Parses "65", "65.5", "₹1,200.25" into paise. Returns null if invalid.
  static int? parse(String input) {
    final s = input.trim().replaceAll(',', '').replaceAll('₹', '').trim();
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    var frac = 0;
    if (parts.length == 2) frac = int.parse(parts[1].padRight(2, '0'));
    return whole * 100 + frac;
  }

  /// Plain editable text, e.g. 6550 -> "65.5", 6500 -> "65".
  static String plain(int? paise) {
    if (paise == null) return '';
    final whole = paise ~/ 100;
    final frac = paise % 100;
    if (frac == 0) return '$whole';
    final f = frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0+$'), '');
    return '$whole.$f';
  }
}

/// Quantities are stored as integer thousandths of a unit (milli-units).
class Qty {
  static String format(int milli) {
    final neg = milli < 0;
    final a = milli.abs();
    final whole = a ~/ 1000;
    final frac = a % 1000;
    var s = '$whole';
    if (frac != 0) {
      final f = frac.toString().padLeft(3, '0').replaceAll(RegExp(r'0+$'), '');
      s = '$s.$f';
    }
    return neg ? '-$s' : s;
  }

  static int? parse(String input) {
    final s = input.trim();
    if (!RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    var frac = 0;
    if (parts.length == 2) frac = int.parse(parts[1].padRight(3, '0'));
    return whole * 1000 + frac;
  }

  /// Line total in paise = round(unitPrice * qty).
  static int lineTotal(int unitPricePaise, int qtyMilli) {
    return (unitPricePaise * qtyMilli + 500) ~/ 1000;
  }
}

/// Unit definitions and conversion inside a unit family.
class Units {
  static const List<String> standard = [
    'kg', 'g', 'l', 'ml', 'piece', 'packet', 'box', 'dozen'
  ];

  static const Map<String, String> _family = {
    'kg': 'mass', 'g': 'mass',
    'l': 'volume', 'ml': 'volume',
    'piece': 'count', 'dozen': 'count',
  };
  static const Map<String, int> _factor = {
    'kg': 1000, 'g': 1,
    'l': 1000, 'ml': 1,
    'piece': 1, 'dozen': 12,
  };

  static String family(String unit) => _family[unit] ?? 'custom:$unit';
  static int factor(String unit) => _factor[unit] ?? 1;

  static bool compatible(String a, String b) => family(a) == family(b);

  /// Converts milli-quantity between compatible units with half-up rounding.
  static int convertMilli(int milli, String from, String to) {
    if (from == to) return milli;
    if (!compatible(from, to)) {
      throw ArgumentError('Incompatible units: $from -> $to');
    }
    final f = factor(from);
    final t = factor(to);
    return (milli * f * 2 + t) ~/ (t * 2);
  }

  static const Map<String, String> _alias = {
    'kg': 'kg', 'kgs': 'kg', 'kilo': 'kg', 'kilos': 'kg', 'kilogram': 'kg',
    'kilograms': 'kg',
    'g': 'g', 'gm': 'g', 'gms': 'g', 'gram': 'g', 'grams': 'g',
    'l': 'l', 'lt': 'l', 'ltr': 'l', 'litre': 'l', 'litres': 'l', 'liter': 'l',
    'liters': 'l',
    'ml': 'ml', 'millilitre': 'ml', 'milliliter': 'ml', 'millilitres': 'ml',
    'piece': 'piece', 'pieces': 'piece', 'pcs': 'piece', 'pc': 'piece',
    'nos': 'piece',
    'packet': 'packet', 'packets': 'packet', 'pkt': 'packet',
    'pack': 'packet',
    'box': 'box', 'boxes': 'box',
    'dozen': 'dozen', 'dozens': 'dozen',
  };

  /// Normalises typed unit text to a stored unit code; custom units pass through.
  static String normalize(String input) {
    final s = input.trim().toLowerCase();
    return _alias[s] ?? s;
  }

  static bool isValid(String unit) {
    final u = unit.trim();
    return u.isNotEmpty && u.length <= 20;
  }
}

/// Splits [amount] across [weights] proportionally; the remainder goes to the
/// last non-zero weight so the parts always add up exactly.
List<int> allocate(int amount, List<int> weights) {
  final total = weights.fold<int>(0, (a, b) => a + b);
  final out = List<int>.filled(weights.length, 0);
  if (total <= 0 || amount <= 0) return out;
  var used = 0;
  var lastIdx = -1;
  for (var i = 0; i < weights.length; i++) {
    if (weights[i] > 0) lastIdx = i;
  }
  for (var i = 0; i < weights.length; i++) {
    if (i == lastIdx) {
      out[i] = amount - used;
    } else {
      out[i] = (amount * weights[i]) ~/ total;
      used += out[i];
    }
  }
  return out;
}

int clampInt(int v, int lo, int hi) => max(lo, min(hi, v));

/// Overridable clock for deterministic tests.
class AppClock {
  static DateTime Function() now = DateTime.now;
}

String nowIso() => AppClock.now().toIso8601String();
