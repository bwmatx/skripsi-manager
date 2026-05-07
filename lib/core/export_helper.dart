import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:open_file/open_file.dart';
import 'package:skripsi_manager/features/history/data/analysis_history_repository.dart';

class ExportHelper {
  static Future<String> _getExportDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    return dir!.path;
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day}-${dt.month}-${dt.year}_${dt.hour}-${dt.minute}';
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static Future<void> exportToTxt(AnalysisHistory history) async {
    final dir = await _getExportDirectory();
    final filename = '${_sanitizeFileName(history.title)}_${_formatDate(history.createdAt)}.txt';
    final path = '$dir/$filename';

    final text = '''
======================================
${history.title}
Tipe: ${history.type}
Tanggal: ${history.createdAt.toString()}
======================================

${history.content}
''';

    final file = File(path);
    await file.writeAsString(text);
    await OpenFile.open(path);
  }

  static Future<void> exportToPdf(AnalysisHistory history) async {
    final document = PdfDocument();
    
    // Add page
    final page = document.pages.add();
    final graphics = page.graphics;
    final bounds = page.getClientSize();

    // Fonts
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.italic);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    double yPos = 0;

    // Title
    graphics.drawString(history.title, titleFont,
        bounds: Rect.fromLTWH(0, yPos, bounds.width, bounds.height),
        format: PdfStringFormat(wordWrap: PdfWordWrapType.word));
    
    yPos += titleFont.height * 2;

    // Header
    graphics.drawString('Tipe: ${history.type}\nTanggal: ${history.createdAt.toString()}', headerFont,
        bounds: Rect.fromLTWH(0, yPos, bounds.width, bounds.height));
    
    yPos += headerFont.height * 3;

    // Divider line
    graphics.drawLine(
        PdfPen(PdfColor(150, 150, 150), width: 1),
        Offset(0, yPos),
        Offset(bounds.width, yPos));
    
    yPos += 10;

    // Body text (handle pagination)
    final textElement = PdfTextElement(
      text: history.content,
      font: bodyFont,
    );
    
    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, yPos, bounds.width, bounds.height - yPos),
    );

    // Save
    final bytes = await document.save();
    document.dispose();

    final dir = await _getExportDirectory();
    final filename = '${_sanitizeFileName(history.title)}_${_formatDate(history.createdAt)}.pdf';
    final path = '$dir/$filename';

    final file = File(path);
    await file.writeAsBytes(bytes);
    await OpenFile.open(path);
  }

  static Future<void> copyToClipboard(AnalysisHistory history) async {
    final text = '''${history.title}
Tipe: ${history.type}

${history.content}''';
    await Clipboard.setData(ClipboardData(text: text));
  }
}
