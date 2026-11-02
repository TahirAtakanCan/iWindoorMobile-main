import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/project.dart';
import '../models/cost_summary.dart';
import 'api_service.dart';

class PdfService {
  final ApiService _apiService = ApiService();

  Future<void> generateAndPrintProjectReport(Project project) async {
    final pdf = pw.Document();
    
    // 1. Maliyet Verilerini Çek (MEO4 verisi)
    final costSummary = await _apiService.getCostSummary(project.id);
    
    // 2. Fontu Yükle (Türkçe karakterler için gerekli)
    // Standart Helvetica Türkçe karakterlerde sorun çıkarabilir.
    // Printing paketi ile gelen varsayılan fontları kullanacağız.
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // 3. PDF Sayfası Oluştur
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        
        // Üst Bilgi (Header)
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              "iWindoor Teklif Formu",
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
        
        // İçerik
        build: (pw.Context context) => [
          _buildTitle(project),
          pw.SizedBox(height: 20),
          _buildProjectInfo(project),
          pw.SizedBox(height: 20),
          _buildWindowsList(project),
          pw.SizedBox(height: 20),
          if (costSummary != null) _buildCostTable(costSummary),
          pw.SizedBox(height: 20),
          _buildTotal(project),
        ],
        
        // Alt Bilgi (Footer)
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              "Bu belge iWindoor Mobil Uygulaması ile oluşturulmuştur.",
              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
            ),
          );
        },
      ),
    );

    // 4. Paylaş / Yazdır
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Teklif_${project.name}.pdf',
    );
  }

  // --- YARDIMCI WIDGETLAR ---

  pw.Widget _buildTitle(Project project) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("TEKLİF FORMU", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.Divider(color: PdfColors.blue800),
      ],
    );
  }

  pw.Widget _buildProjectInfo(Project project) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Müşteri / Proje:", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(project.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(project.description, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Tarih: ${DateTime.now().toString().split(' ')[0]}", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Pencere Sayısı: ${project.windowUnits.length}", style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildWindowsList(Project project) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("Pencere Listesi", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Table.fromTextArray(
          headers: ['Poz Adı', 'Genişlik (mm)', 'Yükseklik (mm)'],
          data: project.windowUnits.map((unit) => [
            unit.name,
            unit.width.toStringAsFixed(0),
            unit.height.toStringAsFixed(0),
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildCostTable(ProjectCostSummary summary) {
    // Verileri gruplayalım (MEO4 mantığı)
    final data = <List<String>>[];
    
    // Profil ve Camları ayır
    for (var item in summary.items) {
      data.add([
        item.category,
        item.name,
        "${item.quantity.toStringAsFixed(2)} ${item.unit}",
        "${item.price.toStringAsFixed(2)} TL"
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("Maliyet Detayı (Malzeme Listesi)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Table.fromTextArray(
          headers: ['Kategori', 'Malzeme', 'Miktar', 'Tutar'],
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          cellStyle: const pw.TextStyle(fontSize: 10),
          border: null,
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        ),
      ],
    );
  }

  pw.Widget _buildTotal(Project project) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text("GENEL TOPLAM", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Text(
            "${project.totalPrice.toStringAsFixed(2)} TL",
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
          ),
        ],
      ),
    );
  }
}