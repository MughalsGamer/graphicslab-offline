import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models.dart';
import '../utils.dart';

/// PDF generation (Urdu supported through Noto Naskh Arabic, downloaded once
/// via the `printing` package – needs internet the first time; falls back to
/// the default font if offline).
class PdfService {
  static pw.ThemeData? _theme;
  static final _rtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F]');

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    try {
      final base = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      final urdu = await PdfGoogleFonts.notoNaskhArabicRegular();
      final urduBold = await PdfGoogleFonts.notoNaskhArabicBold();
      _theme = pw.ThemeData.withFont(
        base: base,
        bold: bold,
        fontFallback: [urdu, urduBold],
      );
    } catch (_) {
      _theme = pw.ThemeData.base();
    }
    return _theme!;
  }

  static pw.Widget _t(String s,
      {double size = 8,
      bool bold = false,
      PdfColor? color,
      pw.TextAlign? align}) {
    return pw.Text(
      s,
      textAlign: align,
      textDirection:
          _rtl.hasMatch(s) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  static pw.Widget _cell(String s,
      {bool bold = false,
      bool right = false,
      PdfColor? color,
      double size = 7.5}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: _t(s, size: size, bold: bold, color: color),
    );
  }

  static pw.Widget _footer(pw.Context c) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _t('© Developed by Ali Haider | 0300-7465064',
                size: 7, color: PdfColors.grey700),
            _t('Page ${c.pageNumber} of ${c.pagesCount}',
                size: 7, color: PdfColors.grey700),
          ],
        ),
      );

  static String _safe(String s) => s.replaceAll(RegExp(r'[^\w\-]+'), '_');

  // ───────────────────────── Ledger ─────────────────────────
  static Future<void> ledgerPdf({
    required Party party,
    required List<LedgerEntry> entries,
    required double opening,
    required double closing,
    DateTime? start,
    DateTime? end,
  }) async {
    final doc = pw.Document(theme: await _loadTheme());
    final totalDebit = entries.fold(0.0, (s, e) => s + e.debit);
    final totalCredit = entries.fold(0.0, (s, e) => s + e.credit);

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('Date', bold: true, size: 8),
          _cell('Description', bold: true, size: 8),
          _cell('Note', bold: true, size: 8),
          _cell('Debit (Rs.)', bold: true, right: true, size: 8),
          _cell('Credit (Rs.)', bold: true, right: true, size: 8),
          _cell('Balance (Rs.)', bold: true, right: true, size: 8),
        ],
      ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cell(''),
          _cell('Opening Balance', bold: true),
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(money(opening), bold: true, right: true),
        ],
      ),
    ];

    for (final e in entries) {
      if (e.type == 'closed') {
        rows.add(pw.TableRow(
          decoration:
              pw.BoxDecoration(color: PdfColor.fromHex('#FFF8E1')),
          children: [
            _cell(fmtShort(e.date), size: 6.5, color: PdfColor.fromHex('#E65100')),
            _cell('LEDGER CLOSED',
                bold: true, color: PdfColor.fromHex('#E65100')),
            _cell('Balance cleared',
                size: 6.5, color: PdfColor.fromHex('#E65100')),
            _cell(''),
            _cell(''),
            _cell('Rs. 0.00',
                bold: true, right: true, color: PdfColor.fromHex('#E65100')),
          ],
        ));
        continue;
      }
      rows.add(pw.TableRow(children: [
        _cell(fmtShort(e.date)),
        _cell(e.description, bold: e.type == 'bill'),
        _cell(e.note),
        _cell(e.debit > 0 ? money(e.debit) : '',
            right: true, color: PdfColors.red700),
        _cell(e.credit > 0 ? money(e.credit) : '',
            right: true, color: PdfColors.green700),
        _cell(money(e.balance), right: true, bold: true),
      ]));
    }

    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell(''),
        _cell('TOTAL', bold: true, size: 8),
        _cell(''),
        _cell(totalDebit > 0 ? money(totalDebit) : '',
            bold: true, right: true, size: 8, color: PdfColors.red800),
        _cell(totalCredit > 0 ? money(totalCredit) : '',
            bold: true, right: true, size: 8, color: PdfColors.green800),
        _cell(''),
      ],
    ));
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _cell(''),
        _cell('Closing Balance', bold: true, size: 8),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(money(closing),
            bold: true, right: true, size: 8, color: PdfColors.blue900),
      ],
    ));

    final period = (start != null && end != null)
        ? '${fmtDate(start)} to ${fmtDate(end)}'
        : 'All transactions';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (c) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _t('CUSTOMER LEDGER', size: 15, bold: true),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _t('Customer: ${party.name}', size: 9, bold: true),
              if (party.categoryName.isNotEmpty)
                _t('Category: ${party.categoryName}', size: 8),
              if (party.phone.isNotEmpty) _t('Phone: ${party.phone}', size: 8),
              if (party.address.isNotEmpty)
                _t('Address: ${party.address}', size: 8),
            ]),
          ),
          pw.SizedBox(height: 5),
          pw.Row(children: [
            _t('Period: $period', size: 8),
            pw.Spacer(),
            _t('Generated: ${fmtDate(DateTime.now())}',
                size: 7, color: PdfColors.grey600),
          ]),
        ]),
      ),
      footer: _footer,
      build: (c) => [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(2.4),
            2: pw.FlexColumnWidth(2.0),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FlexColumnWidth(1.2),
            5: pw.FlexColumnWidth(1.3),
          },
          children: rows,
        ),
      ],
    ));

    await Printing.layoutPdf(
      name: 'Ledger_${_safe(party.name)}.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  // ───────────────────────── Bill ─────────────────────────
  static Future<void> billPdf(Bill bill) async {
    final doc = pw.Document(theme: await _loadTheme());

    pw.Widget kv(String k, String v,
            {bool bold = false, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _t(k, size: 9, bold: bold),
                _t(v, size: 9, bold: bold, color: color),
              ]),
        );

    final widgets = <pw.Widget>[
      pw.Row(children: [
        _t('BILL ${bill.number}', size: 18, bold: true),
        pw.Spacer(),
        _t(fmtDate(bill.date), size: 10),
      ]),
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _t('Customer: ${bill.partyName}', size: 10, bold: true),
          if (bill.categoryName.isNotEmpty)
            _t('Category: ${bill.categoryName}', size: 8.5),
        ]),
      ),
      pw.SizedBox(height: 12),
    ];

    if (bill.items.isNotEmpty) {
      widgets.add(_t('Items', size: 11, bold: true));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(0.5),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(0.8),
          3: pw.FlexColumnWidth(1.1),
          4: pw.FlexColumnWidth(1.1),
          5: pw.FlexColumnWidth(1.3),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _cell('#', bold: true),
              _cell('Description', bold: true),
              _cell('Qty', bold: true, right: true),
              _cell('Rate', bold: true, right: true),
              _cell('Discount', bold: true, right: true),
              _cell('Amount', bold: true, right: true),
            ],
          ),
          for (int i = 0; i < bill.items.length; i++)
            pw.TableRow(children: [
              _cell('${i + 1}'),
              _cell(bill.items[i].description),
              _cell(numText(bill.items[i].qty), right: true),
              _cell(money(bill.items[i].rate), right: true),
              _cell(bill.items[i].discAmount > 0
                  ? money(bill.items[i].discAmount)
                  : '-', right: true),
              _cell(money(bill.items[i].amount), right: true, bold: true),
            ]),
        ],
      ));
      widgets.add(pw.SizedBox(height: 12));
    }

    for (final r in bill.rooms) {
      widgets.add(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _t(r.name, size: 10.5, bold: true),
          pw.SizedBox(height: 4),
          if (r.walls.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Wall', bold: true),
                    _cell('W (ft)', bold: true, right: true),
                    _cell('H (ft)', bold: true, right: true),
                    _cell('Qty', bold: true, right: true),
                    _cell('Sq.ft', bold: true, right: true),
                  ],
                ),
                for (final w in r.walls)
                  pw.TableRow(children: [
                    _cell(w.description),
                    _cell(numText(w.width), right: true),
                    _cell(numText(w.height), right: true),
                    _cell(numText(w.qty), right: true),
                    _cell(w.sqft.toStringAsFixed(2), right: true),
                  ]),
              ],
            ),
          pw.SizedBox(height: 4),
          kv('Walls (${r.wallSqFt.toStringAsFixed(1)} sq.ft × Rs. ${numText(r.wallRate)})',
              money(r.wallTotal)),
          if (r.hasCeiling && r.ceilings.isNotEmpty) ...[
            for (final e in r.ceilings)
              kv('Ceiling: ${e.description} (${numText(e.length)}×${numText(e.width)}×${numText(e.qty)} @ ${numText(e.rate)})',
                  money(e.total)),
          ],
          if (r.hasRoof && r.roofs.isNotEmpty) ...[
            for (final e in r.roofs)
              kv('Roof: ${e.description} (${numText(e.length)}×${numText(e.width)}×${numText(e.qty)} @ ${numText(e.rate)})',
                  money(e.total)),
          ],
          if (r.additional > 0) kv('Additional charges', money(r.additional)),
          pw.Divider(color: PdfColors.grey400, height: 8),
          kv('Room Total', money(r.total), bold: true),
        ]),
      ));
    }

    widgets.add(pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey500),
          borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(children: [
        if (bill.additionalCharges > 0)
          kv('Additional charges', money(bill.additionalCharges)),
        kv('Total', money(bill.totalAmount), bold: true),
        if (bill.totalDiscount > 0)
          kv('Discount', '- ${money(bill.totalDiscount)}',
              color: PdfColors.green800),
        kv('Net Amount', money(bill.net), bold: true),
        if (bill.paidAmount > 0)
          kv('Advance paid', money(bill.paidAmount), color: PdfColors.orange800),
        pw.Divider(color: PdfColors.grey500, height: 8),
        kv('Remaining Balance', money(bill.remaining),
            bold: true,
            color: bill.remaining > 0 ? PdfColors.red800 : PdfColors.green800),
      ]),
    ));

    if (bill.notes.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(_t('Notes: ${bill.notes}', size: 9));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (c) => widgets,
    ));

    await Printing.layoutPdf(
      name: 'Bill_${bill.id ?? 'new'}_${_safe(bill.partyName)}.pdf',
      onLayout: (_) async => doc.save(),
    );
  }
}
