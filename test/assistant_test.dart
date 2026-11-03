import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localbiz_ai/ai/conversation/assistant_engine.dart';
import 'package:localbiz_ai/ai/intent/intent_parser.dart';
import 'package:localbiz_ai/ai/intent/intent_validator.dart';
import 'package:localbiz_ai/ai/intent/product_matcher.dart';
import 'package:localbiz_ai/ai/intent/text_normalizer.dart';
import 'package:localbiz_ai/core/database/app_database.dart';

import 'helpers.dart';

List<ProductRef> refs() => ProductMatcher.build([
      {'id': 1, 'name': 'Rice', 'alt_names': '', 'unit': 'kg'},
      {'id': 2, 'name': 'Sugar', 'alt_names': 'cheeni', 'unit': 'kg'},
      {'id': 3, 'name': 'Salt', 'alt_names': '', 'unit': 'kg'},
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Text normalisation', () {
    test('native digits, symbols and number words', () {
      expect(Norm.normalize('அரிசி ௫ கிலோ'), 'அரிசி 5 கிலோ');
      expect(Norm.normalize('₹65!'), 'rs 65');
      expect(Norm.normalize('half kilo'), '0.5 kilo');
      expect(Norm.normalize('Rice, 5kg.'), 'rice 5 kg');
      expect(Norm.normalize('1.5 kilo'), '1.5 kilo');
    });
  });

  group('Intent extraction (no database)', () {
    ParsedIntent p(String s) => IntentParser.parse(s, refs());

    test('price queries in all supported languages', () {
      for (final q in [
        'Rice price enna?',
        'Arisi vilai enna?',
        'What is the price of rice?',
        'அரிசி விலை என்ன?',
        'അരിയുടെ വില എത്രയാണ്?',
        'ಅಕ್ಕಿಯ ಬೆಲೆ ಎಷ್ಟು?',
        'బియ్యం ధర ఎంత?',
        'चावल की कीमत कितनी है?',
        'Arisi price enna?',
      ]) {
        final r = p(q);
        expect(r.type, IntentType.priceQuery, reason: q);
        expect(r.product?.name, 'Rice', reason: q);
        expect(r.priceType, isNull, reason: q);
      }
    });
    test('wholesale query', () {
      final r = p('Rice wholesale price enna?');
      expect(r.type, IntentType.priceQuery);
      expect(r.priceType, 'wholesale');
      expect(p('Wholesale rate sollu').product, isNull);
    });
    test('add to bill with quantity and unit', () {
      final r = p('Arisi 5 kilo add pannu');
      expect(r.type, IntentType.addToBill);
      expect(r.qtyMilli, 5000);
      expect(r.unit, 'kg');
      expect(p('Add 2 kg sugar').qtyMilli, 2000);
      expect(p('Add 10 packets of sugar').unit, 'packet');
      expect(p('rice half kilo').qtyMilli, 500);
    });
    test('stock intents', () {
      expect(p('Sugar stock evlo?').type, IntentType.stockQuery);
      expect(p('How much sugar stock?').type, IntentType.stockQuery);
      final r = p('Rice stock 20 kilo add pannu');
      expect(r.type, IntentType.stockIn);
      expect(r.qtyMilli, 20000);
      expect(p('Show low stock products').type, IntentType.lowStock);
    });
    test('price update intents', () {
      final r = p('Arisi price 65 rupees ah change pannu');
      expect(r.type, IntentType.priceSet);
      expect(r.amountPaise, 6500);
      final w = p('Rice wholesale price 48 rupees ah update pannu');
      expect(w.type, IntentType.priceSet);
      expect(w.priceType, 'wholesale');
      expect(w.amountPaise, 4800);
      expect(p('Rice retail price 65 rupees ah change pannu').priceType, 'retail');
      final inc = p('increase price');
      expect(inc.type, IntentType.priceAdjust);
      expect(inc.sign, 1);
      expect(p('rice price decrease 5 rupees').sign, -1);
    });
    test('bills, sales and profile', () {
      expect(p('Bill complete pannu').type, IntentType.completeBill);
      expect(p("Show today's bills").type, IntentType.showBills);
      expect(p('Today sales evlo?').type, IntentType.salesQuery);
      expect(p('What is my name?').type, IntentType.profileOwner);
      expect(p('What is my shop name?').type, IntentType.profileShop);
      expect(p('Where is my shop located?').type, IntentType.profileAddress);
      expect(p('What is my phone number?').type, IntentType.profilePhone);
    });
    test('voice product registration', () {
      final r = p('Add salt. Wholesale price 18 rupees. Retail price 22 rupees. Unit kilogram.');
      expect(r.type, IntentType.addProduct);
      expect(r.newName, 'salt');
      expect(r.wholesalePaise, 1800);
      expect(r.retailPaise, 2200);
      expect(r.unit, 'kg');
    });
    test('spelling slips and command words do not match products', () {
      expect(p('rise price').product?.name, 'Rice');
      expect(p('price').product, isNull); // "price" must not fuzzy-match "rice"
    });
    test('invalid commands stay unknown', () {
      expect(p('blah blah').type, IntentType.unknown);
      expect(p('').type, IntentType.unknown);
      expect(p('5 kilo').type, IntentType.unknown);
    });
  });

  group('LLM intent validation', () {
    final r = refs();
    test('accepts a well-formed intent', () {
      final v = IntentValidator.fromMap(
          {'intent': 'add_to_bill', 'product_id': 1, 'qty': 5, 'unit': 'kg'}, r);
      expect(v!.type, IntentType.addToBill);
      expect(v.qtyMilli, 5000);
    });
    test('rejects unknown intents, invented products and bad numbers', () {
      expect(IntentValidator.fromMap({'intent': 'delete_everything'}, r), isNull);
      expect(IntentValidator.fromMap({'intent': 'price_query', 'product_id': 99}, r), isNull);
      expect(IntentValidator.fromMap({'intent': 'add_to_bill', 'product_id': 1, 'qty': -3}, r), isNull);
      expect(IntentValidator.fromMap({'intent': 'price_set', 'product_id': 1, 'amount': 'lots'}, r), isNull);
      expect(IntentValidator.fromMap({'intent': 'price_set', 'price_type': 'secret'}, r), isNull);
    });
  });

  group('Assistant end to end (real database)', () {
    late Fixture f;
    setUp(() async {
      f = await Fixture.create();
      await f.seedBasics();
    });
    tearDown(() async => f.close());

    test('normal price question returns ONLY the retail price', () async {
      final e = f.engine();
      for (final q in ['Rice price enna?', 'Arisi vilai enna?', 'What is the price of rice?']) {
        final r = await e.handle(q);
        expect(r.text, contains('₹60'), reason: q);
        expect(r.text.contains('45'), isFalse, reason: q);
      }
    });
    test('replies in the language of the question', () async {
      final e = f.engine();
      expect((await e.handle('चावल की कीमत कितनी है?')).text, contains('₹60'));
      expect((await e.handle('அரிசி விலை என்ன?')).text, contains('விலை'));
    });
    test('wholesale: owner gets it, employee is refused', () async {
      expect((await f.engine().handle('Rice wholesale price enna?')).text, contains('₹45'));
      final emp = await f.employee();
      final r = await f.engine(session: emp).handle('Rice wholesale price enna?');
      expect(r.text.contains('45'), isFalse);
      expect(r.text, contains('owner'));
      final r2 = await f.engine(session: emp).handle('Rice wholesale price 10 rupees update pannu');
      expect(r2.pending, isNull);
    });
    test('retail price update with confirmation', () async {
      final e = f.engine();
      final r = await e.handle('Arisi price 65 rupees ah change pannu');
      expect(r.text, 'Rice current retail price ₹60. New price ₹65. Confirm?');
      expect(r.pending, isNotNull);
      expect(await f.pricing.getRetail(1), 6000); // nothing saved before confirm
      final c = await e.handle('yes');
      expect(c.text, contains('₹65'));
      expect(await f.pricing.getRetail(1), 6500);
    });
    test('cancel leaves price untouched', () async {
      final e = f.engine();
      await e.handle('Rice price 70 rupees change pannu');
      final c = await e.handle('cancel');
      expect(c.text, 'Cancelled.');
      expect(await f.pricing.getRetail(1), 6000);
    });
    test('wholesale update needs the owner PIN', () async {
      final e = f.engine();
      final r = await e.handle('Rice wholesale price 48 rupees ah update pannu');
      expect(r.pending!.needsPin, isTrue);
      final noPin = await e.confirm();
      expect(noPin.needsPin, isTrue);
      expect(await f.pricing.getWholesale(f.owner, 1), 4500);
      final bad = await e.confirm(pin: '0000');
      expect(bad.needsPin, isTrue);
      expect(await f.pricing.getWholesale(f.owner, 1), 4500);
      final ok = await e.confirm(pin: '1234');
      expect(ok.text, contains('₹48'));
      expect(await f.pricing.getWholesale(f.owner, 1), 4800);
    });
    test('clarification: increase price -> product -> type -> amount', () async {
      final e = f.engine();
      expect((await e.handle('increase price')).text, 'Which product do you mean?');
      expect((await e.handle('rice')).text, 'Do you mean retail or wholesale price?');
      expect((await e.handle('retail')).text, 'By how much? Please say the amount.');
      final r = await e.handle('5');
      expect(r.text, 'Rice current retail price ₹60. New price ₹65. Confirm?');
    });
    test('voice billing from the specification', () async {
      final e = f.engine();
      expect((await e.handle('Arisi 5 kilo add pannu')).text,
          '5 kg Rice added. Amount ₹300. Bill total ₹300.');
      expect((await e.handle('Add 2 kg sugar')).text,
          '2 kg Sugar added. Amount ₹100. Bill total ₹400.');
      final done = await e.handle('Bill complete pannu');
      expect(done.text, 'Your total is ₹400. Confirm?');
      final saved = await e.handle('yes');
      expect(saved.text, startsWith('Bill B-'));
      expect(saved.savedBillId, isNotNull);
      expect(f.draft.lines, isEmpty);
      expect((await f.products.getById(f.owner, 1))!.stockMilli, 15000);
      expect((await f.products.getById(f.owner, 2))!.stockMilli, 8000);
      expect((await e.handle('Today sales evlo?')).text, contains('₹400'));
    });
    test('billing refuses more than the stock', () async {
      final e = f.engine();
      await e.handle('Sugar 50 kg add pannu');
      await e.handle('bill complete pannu');
      final r = await e.handle('yes');
      expect(r.text, contains('Not enough stock'));
      expect((await f.products.getById(f.owner, 2))!.stockMilli, 10000);
    });
    test('stock questions and stock in', () async {
      final e = f.engine();
      expect((await e.handle('Sugar stock evlo?')).text, 'Sugar stock is 10 kg.');
      final r = await e.handle('Rice stock 20 kilo add pannu');
      expect(r.text, 'Add 20 kg to Rice stock? Current stock 20 kg.');
      expect((await e.handle('yes')).text, 'Rice stock is now 40 kg.');
    });
    test('low stock list', () async {
      await f.addProduct('Oil', retail: 15000, stock: 1000, min: 2000);
      final r = await f.engine().handle('Show low stock products');
      expect(r.text, contains('Oil'));
    });
    test('profile answers use only saved data', () async {
      final e = f.engine();
      expect((await e.handle('What is my name?')).text, 'Your name is Ravi.');
      expect((await e.handle('What is my shop name?')).text, 'Your shop name is Ravi Stores.');
      expect((await e.handle('Where is my shop located?')).text, 'Your shop address is 12 Main Road.');
      expect((await e.handle('What is my phone number?')).text, 'That information is not saved.');
    });
    test('owner details are not shared with employees', () async {
      final emp = await f.employee();
      final r = await f.engine(session: emp).handle('What is my phone number?');
      expect(r.text, contains('owner'));
    });
    test('unknown product and invalid commands', () async {
      final e = f.engine();
      expect((await e.handle('Banana price enna')).text, contains('banana'));
      expect((await e.handle('blah blah')).text, contains('did not understand'));
      expect((await e.handle('')).text, contains('did not understand'));
      // product with no price
      await f.addProduct('Mystery', stock: 1000);
      expect((await e.handle('Mystery price enna')).text, contains('no retail price'));
      // incompatible unit
      expect((await e.handle('Rice 2 litre add pannu')).text, contains('cannot be used'));
    });
    test('price history question', () async {
      await f.pricing.setPrice(f.owner, 1, 'retail', 6500);
      final r = await f.engine().handle('Rice previous price');
      expect(r.text, 'Rice retail price was ₹60 before; now ₹65.');
    });
    test('voice product registration with preview', () async {
      final e = f.engine();
      final r = await e.handle('Add salt. Wholesale price 18 rupees. Retail price 22 rupees. Unit kilogram.');
      expect(r.text, 'Add product Salt: retail ₹22, wholesale ₹18, unit kg. Confirm?');
      expect(await f.products.list(f.owner, query: 'Salt'), isEmpty);
      await e.handle('yes');
      final salt = (await f.products.list(f.owner, query: 'Salt')).single;
      expect(salt.retail, 2200);
      expect(salt.wholesale, 1800);
      expect(salt.unit, 'kg');
    });
    test('pending action blocks unrelated chatter', () async {
      final e = f.engine();
      await e.handle('Rice price 70 rupees change pannu');
      final r = await e.handle('hmm');
      expect(r.text, 'Please confirm or cancel.');
      expect(r.pending, isNotNull);
    });
    test('permission failures are explained, never silent', () async {
      final emp = await f.employee();
      final r = await f.engine(session: emp).handle('Rice price 70 rupees change pannu');
      expect(r.text, 'You do not have permission for this.');
      expect(await f.pricing.getRetail(1), 6000);
    });
  });

  test('offline architecture: no network packages or HTTP clients', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    for (final banned in ['http:', 'dio:', 'firebase_', 'cloud_firestore', 'openai', 'google_generative_ai']) {
      expect(pubspec.contains(banned), isFalse, reason: banned);
    }
    final libFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in libFiles) {
      final text = await file.readAsString();
      expect(text.contains('HttpClient'), isFalse, reason: file.path);
      expect(text.contains('package:http/'), isFalse, reason: file.path);
      expect(text.contains('api.openai.com'), isFalse, reason: file.path);
    }
    expect(AppDatabase.schemaVersion, greaterThanOrEqualTo(1));
  });
}
