import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/company.dart';
import '../models/payment.dart';
import '../models/project.dart';
import '../utils/amount_words.dart';
import '../utils/format.dart';
import 'pdf_fonts.dart';

class ReceiptPdf {
  Future<Uint8List> build({
    required CompanyProfile company,
    required Project project,
    required Payment payment,
    required double balanceAfter,
  }) async {
    final fonts = await PdfFonts.load();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2));
    final words = amountToWordsTr(payment.signedAmount);
    final isRefund = payment.isRefund;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(company.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if ((company.address ?? '').isNotEmpty)
              pw.Text(company.address!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            if ((company.phone ?? '').isNotEmpty)
              pw.Text('Tel: ${company.phone}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
            pw.Text(isRefund ? 'İADE MAKBUZU' : 'TAHSİLAT MAKBUZU',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Makbuz no: ${payment.id}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Tarih: ${formatDate(payment.paidAt)}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Text('Müşteri: ${project.customerName ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Proje: ${project.name}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    formatMoney(payment.amount.abs()),
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(words, style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 6),
                  pw.Text('Yöntem: ${paymentMethodTr(payment.method)}', style: const pw.TextStyle(fontSize: 10)),
                  if ((payment.note ?? '').isNotEmpty)
                    pw.Text('Not: ${payment.note}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Kalan bakiye: ${formatMoney(balanceAfter)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Container(
                    width: 120,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Müşteri imza', style: const pw.TextStyle(fontSize: 8)),
                ]),
                pw.Column(children: [
                  pw.Container(
                    width: 120,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Firma imza', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> share({
    required CompanyProfile company,
    required Project project,
    required Payment payment,
    required double balanceAfter,
  }) async {
    final bytes = await build(company: company, project: project, payment: payment, balanceAfter: balanceAfter);
    final name = 'Makbuz_${payment.id}.pdf';
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Printing.sharePdf(bytes: bytes, filename: name);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
    }
  }
}
