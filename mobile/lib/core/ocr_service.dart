import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// On-device OCR Service using Google ML Kit Text Recognition.
/// Extracts text from images (camera/gallery) and basic PDF text streams.
/// No backend server or internet required for OCR processing.
class ClientOCRService {
  static final ClientOCRService _instance = ClientOCRService._internal();
  factory ClientOCRService() => _instance;
  ClientOCRService._internal();

  /// Extract text from image bytes using Google ML Kit on-device OCR
  Future<String> extractTextFromImage(
    Uint8List imageBytes,
    String filename, {
    String? imagePath,
  }) async {
    if (kIsWeb) return '';

    File? tempFile;
    try {
      final InputImage inputImage;
      if (imagePath != null && File(imagePath).existsSync()) {
        inputImage = InputImage.fromFilePath(imagePath);
      } else {
        // Write bytes to temp file with valid image extension for ML Kit InputImage
        final tempDir = await getTemporaryDirectory();
        final lower = filename.toLowerCase();
        final ext = lower.endsWith('.png') ? 'png' : 'jpg';
        tempFile = File(
          '${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}_${filename.hashCode.abs()}.$ext',
        );
        await tempFile.writeAsBytes(imageBytes);
        inputImage = InputImage.fromFilePath(tempFile.path);
      }

      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        final rawText = recognizedText.text;
        final cleaned = _cleanExtractedText(rawText);
        debugPrint('ML Kit OCR extracted ${cleaned.length} chars from $filename');
        return cleaned;
      } finally {
        await textRecognizer.close();
      }
    } catch (e) {
      debugPrint('ML Kit OCR error on $filename: $e');
      return '';
    } finally {
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  /// Extract text from file bytes based on file type
  Future<String> extractText(
    Uint8List fileBytes,
    String filename, {
    String? filePath,
  }) async {
    final ext = filename.toLowerCase().split('.').last;

    // 1. Plain text files — direct decode
    if (['txt', 'csv', 'json', 'md', 'log', 'xml', 'html'].contains(ext)) {
      try {
        final raw = utf8.decode(fileBytes, allowMalformed: true);
        return _cleanExtractedText(raw);
      } catch (_) {
        return _cleanExtractedText(String.fromCharCodes(fileBytes));
      }
    }

    // 2. Image files — ML Kit on-device OCR
    if (['png', 'jpg', 'jpeg', 'bmp', 'webp', 'tiff'].contains(ext)) {
      return await extractTextFromImage(fileBytes, filename, imagePath: filePath);
    }

    // 3. PDF files — extract text streams from PDF binary
    if (ext == 'pdf') {
      return _extractTextFromPdfBytes(fileBytes);
    }

    return '';
  }

  /// Basic PDF text extraction by finding text streams in the PDF binary.
  /// Decodes literal strings and hexadecimal byte strings from Tj and TJ operators.
  String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final decoded = String.fromCharCodes(bytes);
      final textParts = <String>[];

      // Method 1: Literal strings in Tj operator: (Hello World) Tj
      final tjLiteralPattern = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
      for (final match in tjLiteralPattern.allMatches(decoded)) {
        final raw = match.group(1) ?? '';
        final unescaped = _unescapePdfString(raw);
        if (unescaped.trim().isNotEmpty) {
          textParts.add(unescaped.trim());
        }
      }

      // Method 2: Hexadecimal strings in Tj operator: <48656c6c6f> Tj
      final tjHexPattern = RegExp(r'<([0-9a-fA-F\s]+)>\s*Tj');
      for (final match in tjHexPattern.allMatches(decoded)) {
        final hex = match.group(1) ?? '';
        final decodedHex = _decodeHexPdfString(hex);
        if (decodedHex.trim().isNotEmpty) {
          textParts.add(decodedHex.trim());
        }
      }

      // Method 3: Strings inside TJ array operator: [ (Hello) 10 (World) <4142> ] TJ
      final tjArrayPattern = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
      for (final match in tjArrayPattern.allMatches(decoded)) {
        final inner = match.group(1) ?? '';
        // Extract literal strings
        final innerLiteral = RegExp(r'\((.*?)\)');
        for (final m in innerLiteral.allMatches(inner)) {
          final t = _unescapePdfString(m.group(1) ?? '');
          if (t.trim().isNotEmpty) {
            textParts.add(t.trim());
          }
        }
        // Extract hex strings inside TJ
        final innerHex = RegExp(r'<([0-9a-fA-F\s]+)>');
        for (final m in innerHex.allMatches(inner)) {
          final t = _decodeHexPdfString(m.group(1) ?? '');
          if (t.trim().isNotEmpty) {
            textParts.add(t.trim());
          }
        }
      }

      // Method 4: Look for stream content between BT/ET markers if Tj/TJ didn't yield text
      if (textParts.isEmpty) {
        final btEtPattern = RegExp(r'BT\s*(.*?)\s*ET', dotAll: true);
        for (final match in btEtPattern.allMatches(decoded)) {
          final block = match.group(1) ?? '';
          final stringsInBlock = RegExp(r'\((.*?)\)');
          for (final m in stringsInBlock.allMatches(block)) {
            final t = _unescapePdfString(m.group(1) ?? '');
            if (t.trim().isNotEmpty && t.trim().length > 1) {
              textParts.add(t.trim());
            }
          }
        }
      }

      if (textParts.isNotEmpty) {
        final rawJoined = textParts.join(' ');
        final cleaned = _cleanExtractedText(rawJoined);
        debugPrint('PDF text extraction: ${cleaned.length} chars');
        return cleaned;
      }

      return '';
    } catch (e) {
      debugPrint('PDF text extraction error: $e');
      return '';
    }
  }

  /// Unescape standard PDF escaped characters
  String _unescapePdfString(String raw) {
    return raw
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
  }

  /// Decode hexadecimal PDF byte string (e.g. "48656c6c6f" -> "Hello")
  String _decodeHexPdfString(String hex) {
    try {
      final cleanHex = hex.replaceAll(RegExp(r'\s+'), '');
      if (cleanHex.isEmpty || cleanHex.length % 2 != 0) return '';
      final buffer = StringBuffer();
      for (int i = 0; i < cleanHex.length; i += 2) {
        final byteStr = cleanHex.substring(i, i + 2);
        final charCode = int.tryParse(byteStr, radix: 16);
        if (charCode != null && charCode >= 32 && charCode <= 126) {
          buffer.writeCharCode(charCode);
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Clean, normalize, and format extracted OCR / document text
  String _cleanExtractedText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
