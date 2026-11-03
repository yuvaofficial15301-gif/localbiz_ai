import 'text_normalizer.dart';

/// Command vocabulary for all supported languages. Latin words match whole
/// tokens; native-script words match as token prefixes (handles suffixes).
class Kw {
  static List<String> _n(List<String> l) => l.map(Norm.base).toList();

  static final List<String> price = _n([
    'price', 'prices', 'rate', 'rates', 'cost', 'vilai', 'vilaiyai', 'vilaiya',
    'vila', 'dhara', 'bele', 'keemat', 'kimat', 'daam', 'bhav',
    'விலை', 'വില', 'ಬೆಲೆ', 'ధర', 'कीमत', 'दाम', 'भाव', 'रेट', 'ரேட்',
  ]);
  static final List<String> wholesale = _n([
    'wholesale', 'mottha', 'moththa', 'motha', 'ഹോൾസെയിൽ', 'മൊത്ത', 'ಸಗಟು',
    'ಹೋಲ್ಸೇಲ್', 'హోల్సేల్', 'టోకు', 'थोक', 'होलसेल', 'வோல்சேல்',
  ]);
  static final List<String> retail = _n([
    'retail', 'sillarai', 'chillara', 'சில்லறை', 'റീട്ടെയിൽ', 'ಚಿಲ್ಲರೆ',
    'రిటైల్', 'खुदरा', 'खुदरे', 'ரீடெயில்',
  ]);
  static final List<String> stock = _n([
    'stock', 'stocks', 'inventory', 'iruppu', 'இருப்பு', 'സ്റ്റോക്ക്',
    'ಸ್ಟಾಕ್', 'స్టాక్', 'स्टॉक', 'ஸ்டாக்',
  ]);
  static final List<String> low = _n([
    'low', 'kammi', 'குறைந்த', 'குறைவான', 'കുറവ്', 'കുറഞ്ഞ', 'ಕಡಿಮೆ',
    'తక్కువ', 'कम',
  ]);
  static final List<String> add = _n([
    'add', 'create', 'register', 'new', 'insert', 'serkka', 'serthu',
    'சேர்', 'ചേർക്ക', 'ಸೇರಿಸ', 'చేర్చ', 'जोड़', 'जोड', 'ऐड',
  ]);
  static final List<String> change = _n([
    'change', 'update', 'set', 'modify', 'revise', 'maatru', 'maathu',
    'maaru', 'matru', 'மாற்று', 'மாத்து', 'மாற்ற', 'മാറ്റ', 'ബദലി',
    'ಬದಲಿಸ', 'ಬದಲಾಯಿಸ', 'మార్చ', 'बदल', 'अपडेट',
  ]);
  static final List<String> increase = _n([
    'increase', 'raise', 'hike', 'up', 'kootu', 'koottu', 'ஏற்று', 'உயர்த்து',
    'அதிகரி', 'കൂട്ട', 'ಹೆಚ್ಚಿಸ', 'పెంచ', 'बढ़ा', 'बढ़', 'बढा',
  ]);
  static final List<String> decrease = _n([
    'decrease', 'reduce', 'lower', 'down', 'drop', 'kuraikka', 'kuraivu',
    'குறை', 'കുറയ്ക്ക', 'കുറക്ക', 'ಕಡಿಮೆಮಾಡು', 'తగ్గించ', 'घटा',
  ]);
  static final List<String> bill = _n([
    'bill', 'bills', 'billu', 'பில்', 'ബിൽ', 'ಬಿಲ್', 'బిల్', 'बिल',
  ]);
  static final List<String> complete = _n([
    'complete', 'finish', 'finalize', 'finalise', 'done', 'checkout', 'close',
    'mudi', 'mudichidu', 'mudikka', 'podu', 'முடி', 'முடிக்க', 'முடித்து',
    'போடு', 'തീർക്ക', 'ಮುಗಿಸ', 'పూర్తి', 'पूरा', 'खत्म',
  ]);
  static final List<String> show = _n([
    'show', 'list', 'display', 'view', 'open', 'kaattu', 'kaata', 'kaanbi',
    'காட்டு', 'காண்பி', 'കാണിക്ക', 'ತೋರಿಸ', 'చూపించ', 'दिखा',
  ]);
  static final List<String> sales = _n([
    'sales', 'sale', 'virpanai', 'vitpanai', 'vyaparam', 'விற்பனை',
    'വിൽപ്പന', 'വിൽപന', 'ಮಾರಾಟ', 'అమ్మక', 'बिक्री', 'सेल',
  ]);
  static final List<String> today = _n([
    'today', 'todays', 'inniku', 'indru', 'இன்று', 'இன்றைய', 'ഇന്ന്', 'ಇಂದು',
    'ఈరోజు', 'రోజు', 'आज',
  ]);
  static final List<String> week = _n([
    'week', 'weekly', 'vaaram', 'வாரம்', 'வார', 'ആഴ്ച', 'ವಾರ', 'వారం',
    'सप्ताह', 'हफ्ता', 'हफ्ते',
  ]);
  static final List<String> month = _n([
    'month', 'monthly', 'maatham', 'மாதம்', 'மாத', 'മാസ', 'ತಿಂಗಳ', 'నెల',
    'महीन', 'माह',
  ]);
  static final List<String> history = _n([
    'history', 'previous', 'old', 'last', 'munnadi', 'pazhaya', 'முந்தைய',
    'பழைய', 'മുമ്പത്തെ', 'ಹಿಂದಿನ', 'ముందటి', 'पिछली', 'पुरानी', 'पिछला',
  ]);
  static final List<String> my = _n([
    'my', 'mine', 'en', 'ennoda', 'என்', 'எனது', 'என்னுடைய', 'എന്റെ',
    'ನನ್ನ', 'నా', 'मेरा', 'मेरी', 'मेरे', 'mera', 'meri', 'mere', 'nanna',
    'ente',
  ]);
  static final List<String> name = _n([
    'name', 'peyar', 'per', 'பெயர்', 'பேர்', 'പേര്', 'ಹೆಸರು', 'పేరు',
    'नाम', 'naam',
  ]);
  static final List<String> shop = _n([
    'shop', 'store', 'kadai', 'kadaiyin', 'கடை', 'കട', 'ಅಂಗಡಿ', 'దుకాణ',
    'दुकान', 'dukan', 'dukaan',
  ]);
  static final List<String> address = _n([
    'address', 'location', 'where', 'enga', 'engae', 'முகவரி', 'எங்கே',
    'വിലാസം', 'എവിടെ', 'ವಿಳಾಸ', 'ಎಲ್ಲಿ', 'చిరునామా', 'ఎక్కడ', 'पता', 'कहाँ',
    'कहां',
  ]);
  static final List<String> phone = _n([
    'phone', 'mobile', 'number', 'contact', 'தொலைபேசி', 'போன்', 'மொபைல்',
    'ഫോൺ', 'ಫೋನ್', 'ఫోన్', 'फोन', 'मोबाइल',
  ]);
  static final List<String> greeting = _n([
    'hello', 'hi', 'hey', 'vanakkam', 'வணக்கம்', 'നമസ്കാരം', 'ನಮಸ್ಕಾರ',
    'నమస్కారం', 'नमस्ते', 'namaste',
  ]);
  static final List<String> yes = _n([
    'yes', 'ok', 'okay', 'confirm', 'confirmed', 'yep', 'sure', 'ama', 'aamam',
    'sari', 'seri', 'ஆம்', 'ஆமாம்', 'சரி', 'உறுதி', 'ശരി', 'അതെ', 'ഉറപ്പ്',
    'ಹೌದು', 'ಸರಿ', 'అవును', 'సరే', 'हाँ', 'हां', 'ठीक', 'haan', 'theek',
  ]);
  static final List<String> no = _n([
    'no', 'cancel', 'stop', 'illa', 'venda', 'vendam', 'இல்லை', 'வேண்டாம்',
    'ரத்து', 'വേണ്ട', 'ഇല്ല', 'ಬೇಡ', 'ಇಲ್ಲ', 'వద్దు', 'లేదు', 'नहीं', 'नही',
    'रद्द', 'nahi',
  ]);

  static final List<String> rupee = _n([
    'rupees', 'rupee', 'rs', 'inr', 'rupai', 'ruba', 'rupaya', 'ரூபாய்', 'ரூபா',
    'ரூ', 'രൂപ', 'ರೂಪಾಯಿ', 'రూపాయ', 'रुपये', 'रुपया', 'रुपए',
  ]);

  static final Map<String, String> unitWords = {
    for (final e in <String, String>{
      'kg': 'kg', 'kgs': 'kg', 'kilo': 'kg', 'kilos': 'kg', 'kilogram': 'kg',
      'kilograms': 'kg', 'கிலோ': 'kg', 'கிலோகிராம்': 'kg', 'കിലോ': 'kg',
      'ಕಿಲೋ': 'kg', 'ಕೆಜಿ': 'kg', 'కిలో': 'kg', 'కేజీ': 'kg', 'किलो': 'kg',
      'किलोग्राम': 'kg',
      'g': 'g', 'gm': 'g', 'gms': 'g', 'gram': 'g', 'grams': 'g',
      'கிராம்': 'g', 'ഗ്രാം': 'g', 'ಗ್ರಾಂ': 'g', 'గ్రాము': 'g', 'గ్రాం': 'g',
      'ग्राम': 'g',
      'l': 'l', 'lt': 'l', 'ltr': 'l', 'litre': 'l', 'litres': 'l',
      'liter': 'l', 'liters': 'l', 'லிட்டர்': 'l', 'ലിറ്റർ': 'l',
      'ಲೀಟರ್': 'l', 'లీటర్': 'l', 'लीटर': 'l',
      'ml': 'ml', 'millilitre': 'ml', 'milliliter': 'ml', 'மில்லி': 'ml',
      'മില്ലി': 'ml', 'ಮಿಲಿ': 'ml', 'మిల్లీ': 'ml', 'मिली': 'ml',
      'piece': 'piece', 'pieces': 'piece', 'pcs': 'piece', 'pc': 'piece',
      'nos': 'piece', 'துண்டு': 'piece', 'നം': 'piece', 'नग': 'piece',
      'packet': 'packet', 'packets': 'packet', 'pkt': 'packet',
      'pack': 'packet', 'பாக்கெட்': 'packet', 'പാക്കറ്റ്': 'packet',
      'ಪ್ಯಾಕೆಟ್': 'packet', 'ప్యాకెట్': 'packet', 'पैकेट': 'packet',
      'box': 'box', 'boxes': 'box', 'பெட்டி': 'box', 'ബോക്സ്': 'box',
      'ಬಾಕ್ಸ್': 'box', 'బాక్స్': 'box', 'डिब्बा': 'box', 'बॉक्स': 'box',
      'dozen': 'dozen', 'dozens': 'dozen', 'டசன்': 'dozen', 'ഡസൻ': 'dozen',
      'ಡಜನ್': 'dozen', 'డజను': 'dozen', 'दर्जन': 'dozen',
    }.entries)
      Norm.base(e.key): e.value
  };

  static const List<String> fillers = [
    'is', 'the', 'of', 'a', 'an', 'to', 'for', 'please', 'pls', 'me', 'you',
    'and', 'in', 'on', 'at', 'what', 'how', 'much', 'many', 'enna', 'evlo',
    'evvalavu', 'evalo', 'ku', 'la', 'ah', 'aa', 'ka', 'ha', 'pannu', 'panni',
    'pannunga', 'sollu', 'solla', 'sollunga', 'kodu', 'kudu', 'tell', 'give',
    'product', 'item', 'items', 'kitna', 'kya', 'ethra', 'eshtu', 'enta',
    'unit', 'units', 'also', 'then', 'with', 'from', 'it', 'this', 'that',
    'are', 'am', 'be', 'do', 'does', 'can', 'could', 'would', 'should',
  ];

  /// Latin command words that must never be fuzzy-matched to product names.
  static final Set<String> stop = _buildStop();

  static Set<String> _buildStop() {
    final s = <String>{...fillers};
    for (final l in [
      price, wholesale, retail, stock, low, add, change, increase, decrease,
      bill, complete, show, sales, today, week, month, history, my, name,
      shop, address, phone, greeting, yes, no, rupee,
    ]) {
      for (final w in l) {
        if (Norm.isLatin(w)) s.add(w);
      }
    }
    for (final k in unitWords.keys) {
      if (Norm.isLatin(k)) s.add(k);
    }
    return s;
  }

  static bool hit(String tok, List<String> words) {
    for (final w in words) {
      if (Norm.isLatin(w)) {
        if (tok == w) return true;
      } else {
        if (tok.startsWith(w)) return true;
      }
    }
    return false;
  }

  static bool isWholesale(String tok) {
    if (hit(tok, wholesale)) return true;
    // Tamil "மொத்த…" (wholesale) but not "மொத்தம்" (total)
    return tok.startsWith('மொத்த') && !tok.startsWith('மொத்தம்');
  }

  static bool isRupee(String tok) => tok.isNotEmpty && hit(tok, rupee);

  static String? unitOf(String tok) {
    final exact = unitWords[tok];
    if (exact != null) return exact;
    for (final e in unitWords.entries) {
      if (!Norm.isLatin(e.key) && e.key.length >= 2 && tok.startsWith(e.key)) {
        return e.value;
      }
    }
    return null;
  }

  static final RegExp _numRe = RegExp(r'^\d+(\.\d+)?$');
  static bool isNum(String t) => _numRe.hasMatch(t);
}
