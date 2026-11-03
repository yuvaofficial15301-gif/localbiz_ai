import 'languages.dart';

/// Translations. Each key maps to 7 strings in the order of [Languages.all]:
/// en, ta, ta_en, ml, kn, te, hi. Missing entries fall back to English.
/// Placeholders look like {name}.
class S {
  static String t(String lang, String key, [Map<String, String>? params]) {
    final row = _m[key];
    var out = key;
    if (row != null) {
      final i = Languages.byCode(lang).index;
      out = (i < row.length && row[i].isNotEmpty) ? row[i] : row[0];
    }
    if (params != null) {
      params.forEach((k, v) => out = out.replaceAll('{$k}', v));
    }
    return out;
  }

  static const Map<String, List<String>> _m = {
    // ---------- navigation & home ----------
    'nav_home': ['Home', 'முகப்பு', 'Home', 'ഹോം', 'ಮುಖಪುಟ', 'హోమ్', 'होम'],
    'nav_products': ['Products', 'பொருட்கள்', 'Products', 'ഉൽപ്പന്നങ്ങൾ', 'ಉತ್ಪನ್ನಗಳು', 'ఉత్పత్తులు', 'उत्पाद'],
    'nav_billing': ['Billing', 'பில்லிங்', 'Billing', 'ബില്ലിംഗ്', 'ಬಿಲ್ಲಿಂಗ್', 'బిల్లింగ్', 'बिलिंग'],
    'nav_history': ['History', 'வரலாறு', 'History', 'ചരിത്രം', 'ಇತಿಹಾಸ', 'చరిత్ర', 'इतिहास'],
    'nav_settings': ['Settings', 'அமைப்புகள்', 'Settings', 'ക്രമീകരണങ്ങൾ', 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು', 'సెట్టింగ్‌లు', 'सेटिंग्स'],
    'talk_title': ['Talk to Your Shop Assistant', 'உங்கள் கடையுடன் பேசுங்கள்', 'Ungal kadaiyoda pesunga', 'നിങ്ങളുടെ കടയുമായി സംസാരിക്കൂ', 'ನಿಮ್ಮ ಅಂಗಡಿಯೊಂದಿಗೆ ಮಾತನಾಡಿ', 'మీ దుకాణంతో మాట్లాడండి', 'अपनी दुकान से बात करें'],
    'listening': ['Listening…', 'கேட்கிறேன்…', 'Kekkuren…', 'കേൾക്കുന്നു…', 'ಕೇಳುತ್ತಿದ್ದೇನೆ…', 'వింటున్నాను…', 'सुन रहा हूँ…'],
    'processing': ['Processing…', 'செயலாக்குகிறது…', 'Process aagudhu…', 'പ്രോസസ് ചെയ്യുന്നു…', 'ಪ್ರಕ್ರಿಯೆಯಲ್ಲಿದೆ…', 'ప్రాసెస్ చేస్తోంది…', 'प्रोसेस हो रहा है…'],
    'offline': ['Offline', 'ஆஃப்லைன்', 'Offline', 'ഓഫ്‌ലൈൻ', 'ಆಫ್‌ಲೈನ್', 'ఆఫ్‌లైన్', 'ऑफ़लाइन'],
    'online': ['Online', 'ஆன்லைன்', 'Online', 'ഓൺലൈൻ', 'ಆನ್‌ಲೈನ್', 'ఆన్‌లైన్', 'ऑनलाइन'],
    'today_sales': ["Today's sales", 'இன்றைய விற்பனை', 'Inniku sales', 'ഇന്നത്തെ വിൽപ്പന', 'ಇಂದಿನ ಮಾರಾಟ', 'ఈ రోజు అమ్మకాలు', 'आज की बिक्री'],
    'bills': ['Bills', 'பில்கள்', 'Bills', 'ബില്ലുകൾ', 'ಬಿಲ್‌ಗಳು', 'బిల్లులు', 'बिल'],
    'low_stock': ['Low stock', 'குறைந்த இருப்பு', 'Low stock', 'സ്റ്റോക്ക് കുറവ്', 'ಕಡಿಮೆ ಸ್ಟಾಕ್', 'తక్కువ స్టాక్', 'कम स्टॉक'],
    'recent': ['Recent activity', 'சமீப செயல்பாடுகள்', 'Recent activity', 'സമീപകാല പ്രവർത്തനങ്ങൾ', 'ಇತ್ತೀಚಿನ ಚಟುವಟಿಕೆ', 'ఇటీవలి కార్యకలాపాలు', 'हाल की गतिविधि'],
    'confirm': ['Confirm', 'உறுதி', 'Confirm', 'സ്ഥിരീകരിക്കുക', 'ದೃಢೀಕರಿಸಿ', 'నిర్ధారించు', 'पक्का करें'],
    'cancel': ['Cancel', 'ரத்து', 'Cancel', 'റദ്ദാക്കുക', 'ರದ್ದು', 'రద్దు', 'रद्द करें'],
    'save': ['Save', 'சேமி', 'Save', 'സേവ്', 'ಉಳಿಸಿ', 'సేవ్', 'सेव करें'],
    'add': ['Add', 'சேர்', 'Add', 'ചേർക്കുക', 'ಸೇರಿಸಿ', 'చేర్చు', 'जोड़ें'],
    'delete': ['Delete', 'நீக்கு', 'Delete', 'ഇല്ലാതാക്കുക', 'ಅಳಿಸಿ', 'తొలగించు', 'हटाएं'],
    'search': ['Search', 'தேடு', 'Search', 'തിരയുക', 'ಹುಡುಕಿ', 'వెతుకు', 'खोजें'],
    'total': ['Total', 'மொத்தம்', 'Total', 'ആകെ', 'ಒಟ್ಟು', 'మొత్తం', 'कुल'],
    'type_hint': ['Type your command…', 'கட்டளையை டைப் செய்யுங்கள்…', 'Command type pannunga…', 'കമാൻഡ് ടൈപ്പ് ചെയ്യൂ…', 'ಆದೇಶ ಟೈಪ್ ಮಾಡಿ…', 'ఆదేశం టైప్ చేయండి…', 'कमांड टाइप करें…'],
    'w_retail': ['Retail', 'சில்லறை', 'Retail', 'റീട്ടെയിൽ', 'ಚಿಲ್ಲರೆ', 'రిటైల్', 'खुदरा'],
    'w_wholesale': ['Wholesale', 'மொத்த', 'Wholesale', 'ഹോൾസെയിൽ', 'ಸಗಟು', 'హోల్‌సేల్', 'थोक'],
    'w_today': ['Today', 'இன்றைய', 'Inniku', 'ഇന്നത്തെ', 'ಇಂದಿನ', 'ఈ రోజు', 'आज की'],
    'w_week': ['This week', 'இந்த வார', 'Indha vaara', 'ഈ ആഴ്ചത്തെ', 'ಈ ವಾರದ', 'ఈ వారం', 'इस सप्ताह की'],
    'w_month': ['This month', 'இந்த மாத', 'Indha maatha', 'ഈ മാസത്തെ', 'ಈ ತಿಂಗಳ', 'ఈ నెల', 'इस महीने की'],
    'w_none': ['not set', 'அமைக்கப்படவில்லை', 'set pannala', 'സജ്ജമാക്കിയിട്ടില്ല', 'ಹೊಂದಿಸಿಲ್ಲ', 'సెట్ చేయలేదు', 'सेट नहीं'],

    // ---------- assistant replies ----------
    'a_greet': ['Hello! Ask me about prices, stock or bills.', 'வணக்கம்! விலை, இருப்பு, பில் பற்றி கேளுங்கள்.', 'Vanakkam! Vilai, stock, bill pathi kelunga.', 'നമസ്കാരം! വില, സ്റ്റോക്ക്, ബിൽ എന്നിവയെക്കുറിച്ച് ചോദിക്കൂ.', 'ನಮಸ್ಕಾರ! ಬೆಲೆ, ಸ್ಟಾಕ್, ಬಿಲ್ ಬಗ್ಗೆ ಕೇಳಿ.', 'నమస్కారం! ధర, స్టాక్, బిల్లు గురించి అడగండి.', 'नमस्ते! कीमत, स्टॉक या बिल के बारे में पूछें.'],
    'a_price': ['{p} retail price is {price} per {unit}.', '{p} விலை ஒரு {unit} {price}.', '{p} vilai {unit}-ku {price}.', '{p} വില {unit}-ന് {price}.', '{p} ಬೆಲೆ ಪ್ರತಿ {unit}ಗೆ {price}.', '{p} ధర {unit}కి {price}.', '{p} की कीमत {price} प्रति {unit} है.'],
    'a_wholesale': ['{p} wholesale price is {price} per {unit}.', '{p} மொத்த விலை {unit}க்கு {price}.', '{p} wholesale vilai {unit}-ku {price}.', '{p} ഹോൾസെയിൽ വില {unit}-ന് {price}.', '{p} ಸಗಟು ಬೆಲೆ ಪ್ರತಿ {unit}ಗೆ {price}.', '{p} హోల్‌సేల్ ధర {unit}కి {price}.', '{p} की थोक कीमत {price} प्रति {unit} है.'],
    'a_not_found': ['I could not find “{q}” in your products.', 'உங்கள் பொருட்களில் “{q}” கிடைக்கவில்லை.', 'Ungal products-la “{q}” kidaikkala.', 'നിങ്ങളുടെ ഉൽപ്പന്നങ്ങളിൽ “{q}” കണ്ടെത്താനായില്ല.', 'ನಿಮ್ಮ ಉತ್ಪನ್ನಗಳಲ್ಲಿ “{q}” ಸಿಗಲಿಲ್ಲ.', 'మీ ఉత్పత్తులలో “{q}” దొరకలేదు.', 'आपके उत्पादों में “{q}” नहीं मिला.'],
    'a_no_price': ['{p} has no {type} price saved. Please enter it.', '{p}க்கு {type} விலை சேமிக்கப்படவில்லை. தயவுசெய்து உள்ளிடுங்கள்.', '{p}-ku {type} vilai save pannala. Please enter pannunga.', '{p}-ന് {type} വില സേവ് ചെയ്തിട്ടില്ല. ദയവായി നൽകുക.', '{p}ಗೆ {type} ಬೆಲೆ ಉಳಿಸಿಲ್ಲ. ದಯವಿಟ್ಟು ನಮೂದಿಸಿ.', '{p}కి {type} ధర సేవ్ చేయలేదు. దయచేసి నమోదు చేయండి.', '{p} की {type} कीमत सेव नहीं है. कृपया दर्ज करें.'],
    'a_stock': ['{p} stock is {qty} {unit}.', '{p} இருப்பு {qty} {unit}.', '{p} stock {qty} {unit} irukku.', '{p} സ്റ്റോക്ക് {qty} {unit} ഉണ്ട്.', '{p} ಸ್ಟಾಕ್ {qty} {unit} ಇದೆ.', '{p} స్టాక్ {qty} {unit} ఉంది.', '{p} का स्टॉक {qty} {unit} है.'],
    'a_low_none': ['No products are low on stock.', 'குறைந்த இருப்பு உள்ள பொருட்கள் இல்லை.', 'Low stock products illa.', 'സ്റ്റോക്ക് കുറവുള്ള ഉൽപ്പന്നങ്ങളില്ല.', 'ಕಡಿಮೆ ಸ್ಟಾಕ್ ಇರುವ ಉತ್ಪನ್ನಗಳಿಲ್ಲ.', 'తక్కువ స్టాక్ ఉన్న ఉత్పత్తులు లేవు.', 'कम स्टॉक वाला कोई उत्पाद नहीं है.'],
    'a_low_list': ['Low stock: {list}.', 'குறைந்த இருப்பு: {list}.', 'Low stock: {list}.', 'സ്റ്റോക്ക് കുറവ്: {list}.', 'ಕಡಿಮೆ ಸ್ಟಾಕ್: {list}.', 'తక్కువ స్టాక్: {list}.', 'कम स्टॉक: {list}.'],
    'a_added_bill': ['{qty} {unit} {p} added. Amount {amt}. Bill total {total}.', '{qty} {unit} {p} சேர்க்கப்பட்டது. தொகை {amt}. மொத்த பில் {total}.', '{qty} {unit} {p} add aachu. Amount {amt}. Bill total {total}.', '{qty} {unit} {p} ചേർത്തു. തുക {amt}. ആകെ ബിൽ {total}.', '{qty} {unit} {p} ಸೇರಿಸಲಾಗಿದೆ. ಮೊತ್ತ {amt}. ಒಟ್ಟು ಬಿಲ್ {total}.', '{qty} {unit} {p} చేర్చబడింది. మొత్తం {amt}. బిల్లు మొత్తం {total}.', '{qty} {unit} {p} जोड़ा गया. राशि {amt}. कुल बिल {total}.'],
    'a_bill_confirm': ['Your total is {total}. Confirm?', 'மொத்தம் {total}. உறுதி செய்யவா?', 'Total {total}. Confirm pannalama?', 'ആകെ {total}. സ്ഥിരീകരിക്കട്ടെ?', 'ಒಟ್ಟು {total}. ದೃಢೀಕರಿಸಲೇ?', 'మొత్తం {total}. నిర్ధారించాలా?', 'कुल {total}. पक्का करें?'],
    'a_bill_saved': ['Bill {no} saved. Total {total}.', 'பில் {no} சேமிக்கப்பட்டது. மொத்தம் {total}.', 'Bill {no} save aachu. Total {total}.', 'ബിൽ {no} സേവ് ചെയ്തു. ആകെ {total}.', 'ಬಿಲ್ {no} ಉಳಿಸಲಾಗಿದೆ. ಒಟ್ಟು {total}.', 'బిల్లు {no} సేవ్ అయింది. మొత్తం {total}.', 'बिल {no} सेव हो गया. कुल {total}.'],
    'a_bill_empty': ['The bill is empty.', 'பில் காலியாக உள்ளது.', 'Bill empty-a irukku.', 'ബിൽ ശൂന്യമാണ്.', 'ಬಿಲ್ ಖಾಲಿಯಾಗಿದೆ.', 'బిల్లు ఖాళీగా ఉంది.', 'बिल खाली है.'],
    'a_price_change': ['{p} current {type} price {old}. New price {new}. Confirm?', '{p} தற்போதைய {type} விலை {old}. புதிய விலை {new}. உறுதி செய்யவா?', '{p} current {type} price {old}. New price {new}. Confirm pannalama?', '{p} നിലവിലെ {type} വില {old}. പുതിയ വില {new}. സ്ഥിരീകരിക്കട്ടെ?', '{p} ಪ್ರಸ್ತುತ {type} ಬೆಲೆ {old}. ಹೊಸ ಬೆಲೆ {new}. ದೃಢೀಕರಿಸಲೇ?', '{p} ప్రస్తుత {type} ధర {old}. కొత్త ధర {new}. నిర్ధారించాలా?', '{p} की मौजूदा {type} कीमत {old}. नई कीमत {new}. पक्का करें?'],
    'a_price_updated': ['{p} {type} price is now {new}.', '{p} {type} விலை இப்போது {new}.', '{p} {type} price ippo {new}.', '{p} {type} വില ഇപ്പോൾ {new}.', '{p} {type} ಬೆಲೆ ಈಗ {new}.', '{p} {type} ధర ఇప్పుడు {new}.', '{p} की {type} कीमत अब {new} है.'],
    'a_ask_type': ['Do you mean retail or wholesale price?', 'சில்லறை விலையா அல்லது மொத்த விலையா?', 'Retail price-a illa wholesale price-a?', 'റീട്ടെയിൽ വിലയോ ഹോൾസെയിൽ വിലയോ?', 'ಚಿಲ್ಲರೆ ಬೆಲೆಯೋ ಸಗಟು ಬೆಲೆಯೋ?', 'రిటైల్ ధరా లేదా హోల్‌సేల్ ధరా?', 'खुदरा कीमत या थोक कीमत?'],
    'a_ask_amount': ['By how much? Please say the amount.', 'எவ்வளவு? தொகையை சொல்லுங்கள்.', 'Evlo? Amount sollunga.', 'എത്ര? തുക പറയൂ.', 'ಎಷ್ಟು? ಮೊತ್ತ ಹೇಳಿ.', 'ఎంత? మొత్తం చెప్పండి.', 'कितना? राशि बताएं.'],
    'a_need_owner': ['Only the owner can do this.', 'இதை உரிமையாளர் மட்டுமே செய்ய முடியும்.', 'Idhai owner mattum than pannalam.', 'ഇത് ഉടമയ്ക്ക് മാത്രമേ ചെയ്യാനാകൂ.', 'ಇದನ್ನು ಮಾಲೀಕರು ಮಾತ್ರ ಮಾಡಬಹುದು.', 'దీన్ని యజమాని మాత్రమే చేయగలరు.', 'यह केवल मालिक कर सकते हैं.'],
    'a_not_allowed': ['You do not have permission for this.', 'இதற்கு உங்களுக்கு அனுமதி இல்லை.', 'Ithukku ungalukku permission illa.', 'ഇതിന് നിങ്ങൾക്ക് അനുമതി ഇല്ല.', 'ಇದಕ್ಕೆ ನಿಮಗೆ ಅನುಮತಿ ಇಲ್ಲ.', 'దీనికి మీకు అనుమతి లేదు.', 'इसके लिए आपको अनुमति नहीं है.'],
    'a_sales': ['{period} sales: {amt} from {n} bills.', '{period} விற்பனை {amt}, {n} பில்கள்.', '{period} sales {amt}, {n} bills.', '{period} വിൽപ്പന {amt}, {n} ബില്ലുകൾ.', '{period} ಮಾರಾಟ {amt}, {n} ಬಿಲ್‌ಗಳು.', '{period} అమ్మకాలు {amt}, {n} బిల్లులు.', '{period} की बिक्री {amt}, {n} बिल.'],
    'a_stockin_confirm': ['Add {qty} {unit} to {p} stock? Current stock {cur}.', '{p} இருப்பில் {qty} {unit} சேர்க்கவா? தற்போதைய இருப்பு {cur}.', '{p} stock-la {qty} {unit} add pannalama? Ippo stock {cur}.', '{p} സ്റ്റോക്കിൽ {qty} {unit} ചേർക്കട്ടെ? നിലവിലെ സ്റ്റോക്ക് {cur}.', '{p} ಸ್ಟಾಕ್‌ಗೆ {qty} {unit} ಸೇರಿಸಲೇ? ಪ್ರಸ್ತುತ ಸ್ಟಾಕ್ {cur}.', '{p} స్టాక్‌కు {qty} {unit} చేర్చాలా? ప్రస్తుత స్టాక్ {cur}.', '{p} के स्टॉक में {qty} {unit} जोड़ें? मौजूदा स्टॉक {cur}.'],
    'a_stock_updated': ['{p} stock is now {qty} {unit}.', '{p} இருப்பு இப்போது {qty} {unit}.', '{p} stock ippo {qty} {unit}.', '{p} സ്റ്റോക്ക് ഇപ്പോൾ {qty} {unit}.', '{p} ಸ್ಟಾಕ್ ಈಗ {qty} {unit}.', '{p} స్టాక్ ఇప్పుడు {qty} {unit}.', '{p} का स्टॉक अब {qty} {unit} है.'],
    'a_owner_name': ['Your name is {v}.', 'உங்கள் பெயர் {v}.', 'Ungal peyar {v}.', 'നിങ്ങളുടെ പേര് {v}.', 'ನಿಮ್ಮ ಹೆಸರು {v}.', 'మీ పేరు {v}.', 'आपका नाम {v} है.'],
    'a_shop_name': ['Your shop name is {v}.', 'உங்கள் கடை பெயர் {v}.', 'Ungal kadai peyar {v}.', 'നിങ്ങളുടെ കടയുടെ പേര് {v}.', 'ನಿಮ್ಮ ಅಂಗಡಿಯ ಹೆಸರು {v}.', 'మీ దుకాణం పేరు {v}.', 'आपकी दुकान का नाम {v} है.'],
    'a_shop_addr': ['Your shop address is {v}.', 'உங்கள் கடை முகவரி {v}.', 'Ungal kadai address {v}.', 'നിങ്ങളുടെ കടയുടെ വിലാസം {v}.', 'ನಿಮ್ಮ ಅಂಗಡಿಯ ವಿಳಾಸ {v}.', 'మీ దుకాణం చిరునామా {v}.', 'आपकी दुकान का पता {v} है.'],
    'a_phone': ['Your phone number is {v}.', 'உங்கள் தொலைபேசி எண் {v}.', 'Ungal phone number {v}.', 'നിങ്ങളുടെ ഫോൺ നമ്പർ {v}.', 'ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆ {v}.', 'మీ ఫోన్ నంబర్ {v}.', 'आपका फोन नंबर {v} है.'],
    'a_not_saved': ['That information is not saved.', 'அந்த தகவல் சேமிக்கப்படவில்லை.', 'Andha information save pannala.', 'ആ വിവരം സേവ് ചെയ്തിട്ടില്ല.', 'ಆ ಮಾಹಿತಿ ಉಳಿಸಿಲ್ಲ.', 'ఆ సమాచారం సేవ్ చేయలేదు.', 'वह जानकारी सेव नहीं है.'],
    'a_prod_preview': ['Add product {p}: retail {r}, wholesale {w}, unit {u}. Confirm?', 'பொருள் {p} சேர்க்கவா: சில்லறை {r}, மொத்தம் {w}, அலகு {u}. உறுதி செய்யவா?', 'Product {p} add pannalama: retail {r}, wholesale {w}, unit {u}. Confirm?', 'ഉൽപ്പന്നം {p} ചേർക്കട്ടെ: റീട്ടെയിൽ {r}, ഹോൾസെയിൽ {w}, യൂണിറ്റ് {u}. സ്ഥിരീകരിക്കട്ടെ?', 'ಉತ್ಪನ್ನ {p} ಸೇರಿಸಲೇ: ಚಿಲ್ಲರೆ {r}, ಸಗಟು {w}, ಘಟಕ {u}. ದೃಢೀಕರಿಸಲೇ?', 'ఉత్పత్తి {p} చేర్చాలా: రిటైల్ {r}, హోల్‌సేల్ {w}, యూనిట్ {u}. నిర్ధారించాలా?', 'उत्पाद {p} जोड़ें: खुदरा {r}, थोक {w}, इकाई {u}. पक्का करें?'],
    'a_prod_saved': ['Product {p} saved.', 'பொருள் {p} சேமிக்கப்பட்டது.', 'Product {p} save aachu.', 'ഉൽപ്പന്നം {p} സേവ് ചെയ്തു.', 'ಉತ್ಪನ್ನ {p} ಉಳಿಸಲಾಗಿದೆ.', 'ఉత్పత్తి {p} సేవ్ అయింది.', 'उत्पाद {p} सेव हो गया.'],
    'a_cancelled': ['Cancelled.', 'ரத்து செய்யப்பட்டது.', 'Cancel aachu.', 'റദ്ദാക്കി.', 'ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.', 'రద్దు చేయబడింది.', 'रद्द किया गया.'],
    'a_unclear': ['I did not understand. Please say it again or type it.', 'புரியவில்லை. மீண்டும் சொல்லுங்கள் அல்லது டைப் செய்யுங்கள்.', 'Puriyala. Marubadiyum sollunga illa type pannunga.', 'മനസ്സിലായില്ല. വീണ്ടും പറയൂ അല്ലെങ്കിൽ ടൈപ്പ് ചെയ്യൂ.', 'ಅರ್ಥವಾಗಲಿಲ್ಲ. ಮತ್ತೆ ಹೇಳಿ ಅಥವಾ ಟೈಪ್ ಮಾಡಿ.', 'అర్థం కాలేదు. మళ్ళీ చెప్పండి లేదా టైప్ చేయండి.', 'समझ नहीं आया. फिर से बोलें या टाइप करें.'],
    'a_ask_qty': ['How much {p}?', '{p} எவ்வளவு?', '{p} evlo?', '{p} എത്ര?', '{p} ಎಷ್ಟು?', '{p} ఎంత?', '{p} कितना?'],
    'a_open_bills': ["Showing today's bills.", 'இன்றைய பில்களை காட்டுகிறேன்.', 'Inniku bills kaattren.', 'ഇന്നത്തെ ബില്ലുകൾ കാണിക്കുന്നു.', 'ಇಂದಿನ ಬಿಲ್‌ಗಳನ್ನು ತೋರಿಸುತ್ತಿದ್ದೇನೆ.', 'ఈ రోజు బిల్లులు చూపిస్తున్నాను.', 'आज के बिल दिखा रहा हूँ.'],
    'a_prev_price': ['{p} {type} price was {old} before; now {new}.', '{p} {type} விலை முன்பு {old}, இப்போது {new}.', '{p} {type} price munnadi {old}, ippo {new}.', '{p} {type} വില മുമ്പ് {old}, ഇപ്പോൾ {new}.', '{p} {type} ಬೆಲೆ ಹಿಂದೆ {old}, ಈಗ {new}.', '{p} {type} ధర ముందు {old}, ఇప్పుడు {new}.', '{p} की {type} कीमत पहले {old} थी, अब {new}.'],
    'a_no_history': ['No price changes recorded for {p}.', '{p}க்கு விலை மாற்றம் பதிவாகவில்லை.', '{p}-ku price change record illa.', '{p}-ന് വില മാറ്റം രേഖപ്പെടുത്തിയിട്ടില്ല.', '{p}ಗೆ ಬೆಲೆ ಬದಲಾವಣೆ ದಾಖಲಾಗಿಲ್ಲ.', '{p}కి ధర మార్పులు నమోదు కాలేదు.', '{p} के लिए कीमत बदलाव दर्ज नहीं है.'],
    'a_insufficient': ['Not enough stock for {p}. Available {qty} {unit}.', '{p} இருப்பு போதாது. உள்ளது {qty} {unit}.', '{p} stock pothaathu. Irukku {qty} {unit}.', '{p} സ്റ്റോക്ക് മതിയാകില്ല. ലഭ്യം {qty} {unit}.', '{p} ಸ್ಟಾಕ್ ಸಾಕಾಗುವುದಿಲ್ಲ. ಲಭ್ಯ {qty} {unit}.', '{p} స్టాక్ సరిపోదు. అందుబాటులో {qty} {unit}.', '{p} का स्टॉक कम है. उपलब्ध {qty} {unit}.'],
    'a_unit_bad': ['{unit} cannot be used for {p}.', '{p}க்கு {unit} பயன்படுத்த முடியாது.', '{p}-ku {unit} use panna mudiyaadhu.', '{p}-ന് {unit} ഉപയോഗിക്കാനാകില്ല.', '{p}ಗೆ {unit} ಬಳಸಲಾಗುವುದಿಲ್ಲ.', '{p}కి {unit} ఉపయోగించలేరు.', '{p} के लिए {unit} उपयोग नहीं हो सकता.'],
    'a_error': ['Something went wrong: {e}', 'ஏதோ தவறு நடந்தது: {e}', 'Edho thappu nadandhuchu: {e}', 'എന്തോ പിശക് സംഭവിച്ചു: {e}', 'ಏನೋ ತಪ್ಪಾಗಿದೆ: {e}', 'ఏదో తప్పు జరిగింది: {e}', 'कुछ गलत हो गया: {e}'],
    'a_pin_needed': ['Please enter your PIN to confirm.', 'உறுதி செய்ய உங்கள் PIN உள்ளிடுங்கள்.', 'Confirm panna PIN enter pannunga.', 'സ്ഥിരീകരിക്കാൻ PIN നൽകുക.', 'ದೃಢೀಕರಿಸಲು PIN ನಮೂದಿಸಿ.', 'నిర్ధారించడానికి PIN నమోదు చేయండి.', 'पक्का करने के लिए PIN दर्ज करें.'],
    'a_pin_wrong': ['Wrong PIN.', 'தவறான PIN.', 'PIN thappu.', 'തെറ്റായ PIN.', 'ತಪ್ಪು PIN.', 'తప్పు PIN.', 'गलत PIN.'],
    'a_pending_ask': ['Please confirm or cancel.', 'உறுதி செய்யுங்கள் அல்லது ரத்து செய்யுங்கள்.', 'Confirm illa cancel pannunga.', 'സ്ഥിരീകരിക്കുക അല്ലെങ്കിൽ റദ്ദാക്കുക.', 'ದೃಢೀಕರಿಸಿ ಅಥವಾ ರದ್ದುಗೊಳಿಸಿ.', 'నిర్ధారించండి లేదా రద్దు చేయండి.', 'पक्का करें या रद्द करें.'],
    'a_which_product': ['Which product do you mean?', 'எந்த பொருள்?', 'Entha product?', 'ഏത് ഉൽപ്പന്നം?', 'ಯಾವ ಉತ್ಪನ್ನ?', 'ఏ ఉత్పత్తి?', 'कौन सा उत्पाद?'],
  };
}
