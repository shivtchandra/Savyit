// lib/services/pdf_service.dart
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  /// Extracts plain text from a PDF file.
  static Future<String> extractText(File file) async {
    try {
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }
}
