/// Minimal RFC-4180 style CSV reader/writer.
class Csv {
  static String encode(List<List<String>> rows) {
    final b = StringBuffer();
    for (final r in rows) {
      b.writeln(r.map(_esc).join(','));
    }
    return b.toString();
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static List<List<String>> parse(String input) {
    var text = input;
    final rows = <List<String>>[];
    var row = <String>[];
    final cur = StringBuffer();
    var inQuotes = false;
    var i = 0;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    while (i < text.length) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cur.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cur.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          row.add(cur.toString());
          cur.clear();
        } else if (c == '\n' || c == '\r') {
          if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
          row.add(cur.toString());
          cur.clear();
          if (!(row.length == 1 && row[0].isEmpty)) rows.add(row);
          row = <String>[];
        } else {
          cur.write(c);
        }
      }
      i++;
    }
    if (cur.isNotEmpty || row.isNotEmpty) {
      row.add(cur.toString());
      rows.add(row);
    }
    return rows;
  }
}
