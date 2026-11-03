import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/money.dart';
import '../../shared/models/models.dart';

/// Draws the receipt with Flutter's text engine (so Tamil, Hindi, ₹ etc. render
/// with the phone's system fonts, fully offline) and wraps it into a PDF.
class ReceiptService {
  static Future<Uint8List> renderPng(
      ShopProfile shop, BillRec bill, List<BillItemRec> items) async {
    const width = 520.0;
    const pad = 22.0;
    final lines = <_Line>[];

    lines.add(_Line.center(shop.shopName, 26, bold: true));
    if (shop.address.isNotEmpty) lines.add(_Line.center(shop.address, 15));
    if (shop.phone.isNotEmpty) lines.add(_Line.center('Phone: ${shop.phone}', 15));
    lines.add(_Line.rule());
    lines.add(_Line.two('Bill: ${bill.billNo}', '', 16));
    lines.add(_Line.two('Date: ${_fmt(bill.createdAt)}', '', 15));
    if (bill.customer.isNotEmpty) lines.add(_Line.two('Customer: ${bill.customer}', '', 15));
    lines.add(_Line.rule());
    for (final it in items) {
      lines.add(_Line.two(it.name, Money.format(it.finalAmount, sym: shop.currency), 17, bold: true));
      lines.add(_Line.two(
          '${Qty.format(it.qtyMilli)} ${it.unit} × ${Money.format(it.unitPrice, sym: shop.currency)}',
          '', 14));
    }
    lines.add(_Line.rule());
    lines.add(_Line.two('Subtotal', Money.format(bill.subtotal, sym: shop.currency), 16));
    if (bill.discount > 0) {
      lines.add(_Line.two('Discount', '-${Money.format(bill.discount, sym: shop.currency)}', 16));
    }
    if (bill.tax > 0) {
      lines.add(_Line.two('Tax', Money.format(bill.tax, sym: shop.currency), 16));
    }
    lines.add(_Line.two('TOTAL', Money.format(bill.total, sym: shop.currency), 22, bold: true));
    lines.add(_Line.two('Paid by: ${bill.paymentMethod.toUpperCase()}', '', 15));
    lines.add(_Line.rule());
    lines.add(_Line.center('Thank you! Visit again.', 16));

    // layout
    var y = pad;
    final painters = <_Placed>[];
    for (final l in lines) {
      if (l.isRule) {
        painters.add(_Placed.rule(y + 6));
        y += 16;
        continue;
      }
      final style = TextStyle(
          color: const Color(0xFF000000),
          fontSize: l.size,
          fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400);
      final left = TextPainter(
        text: TextSpan(text: l.left, style: style),
        textDirection: TextDirection.ltr,
        textAlign: l.centered ? TextAlign.center : TextAlign.left,
      )..layout(maxWidth: l.right.isEmpty ? width - pad * 2 : width - pad * 2 - 130);
      TextPainter? right;
      if (l.right.isNotEmpty) {
        right = TextPainter(
          text: TextSpan(text: l.right, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
      }
      painters.add(_Placed(left, right, y, l.centered));
      y += left.height + 6;
    }
    final height = y + pad;

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()..color = const Color(0xFFFFFFFF));
    for (final p in painters) {
      if (p.rule) {
        canvas.drawLine(ui.Offset(pad, p.y), ui.Offset(width - pad, p.y),
            ui.Paint()..color = const Color(0xFF888888)..strokeWidth = 1);
        continue;
      }
      if (p.centered) {
        p.left!.paint(canvas, ui.Offset((width - p.left!.width) / 2, p.y));
      } else {
        p.left!.paint(canvas, ui.Offset(pad, p.y));
      }
      if (p.right != null) {
        p.right!.paint(canvas, ui.Offset(width - pad - p.right!.width, p.y));
      }
    }
    final img = await rec.endRecording().toImage(width.toInt(), height.ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static String _fmt(String iso) {
    if (iso.length >= 16) {
      return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)} ${iso.substring(11, 16)}';
    }
    return iso;
  }

  static Future<Uint8List> buildPdf(Uint8List png, double imgW, double imgH) async {
    final doc = pw.Document(title: 'Receipt');
    const pageW = 300.0;
    final pageH = pageW * imgH / imgW;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(pageW, pageH, marginAll: 0),
      build: (ctx) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
    ));
    return doc.save();
  }

  /// Convenience: render + wrap. Image size is read back from the PNG header.
  static Future<Uint8List> pdfFor(
      ShopProfile shop, BillRec bill, List<BillItemRec> items) async {
    final png = await renderPng(shop, bill, items);
    final bd = ByteData.sublistView(png);
    final w = bd.getUint32(16).toDouble();
    final h = bd.getUint32(20).toDouble();
    return buildPdf(png, w, h);
  }
}

class _Line {
  final String left;
  final String right;
  final double size;
  final bool bold;
  final bool centered;
  final bool isRule;
  _Line(this.left, this.right, this.size, this.bold, this.centered, this.isRule);
  factory _Line.center(String t, double s, {bool bold = false}) =>
      _Line(t, '', s, bold, true, false);
  factory _Line.two(String l, String r, double s, {bool bold = false}) =>
      _Line(l, r, s, bold, false, false);
  factory _Line.rule() => _Line('', '', 1, false, false, true);
}

class _Placed {
  final TextPainter? left;
  final TextPainter? right;
  final double y;
  final bool centered;
  final bool rule;
  _Placed(this.left, this.right, this.y, this.centered) : rule = false;
  _Placed.rule(this.y)
      : left = null,
        right = null,
        centered = false,
        rule = true;
}
