import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

/// Comprehensive Dual-Engine OCR & Document Text Extraction Service:
/// 1. On-Device Pure Dart PDF Parser with ZLib FlateDecode decompression.
/// 2. Google ML Kit Latin Text Recognition for camera shots & photos on mobile.
/// 3. Hybrid Cloud Fallback to Render FastAPI (PyPDF + RapidOCR ONNX) for Web & complex scans.
class ClientOCRService {
  static final ClientOCRService _instance = ClientOCRService._internal();
  factory ClientOCRService() => _instance;
  ClientOCRService._internal();

  /// Extract text from image bytes using Google ML Kit on-device OCR with Backend fallback
  Future<String> extractTextFromImage(
    Uint8List imageBytes,
    String filename, {
    String? imagePath,
  }) async {
    // 1. If running on Mobile, attempt on-device Google ML Kit Text Recognition
    if (!kIsWeb) {
      File? tempFile;
      try {
        final InputImage inputImage;
        if (imagePath != null && File(imagePath).existsSync()) {
          inputImage = InputImage.fromFilePath(imagePath);
        } else {
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
          if (cleaned.trim().isNotEmpty) {
            debugPrint('ML Kit OCR extracted ${cleaned.length} chars from $filename');
            return cleaned;
          }
        } finally {
          await textRecognizer.close();
        }
      } catch (e) {
        debugPrint('ML Kit OCR error on $filename: $e');
      } finally {
        try {
          await tempFile?.delete();
        } catch (_) {}
      }
    }

    // 2. High-Accuracy Cloud Backend OCR Fallback (PyPDF / RapidOCR / Tesseract)
    return await _fallbackBackendExtract(imageBytes, filename);
  }

  /// Master text extraction method for all document types
  Future<String> extractText(
    Uint8List fileBytes,
    String filename, {
    String? filePath,
  }) async {
    final ext = filename.toLowerCase().split('.').last;

    // 1. Plain text and tabular data — direct decode
    if (['txt', 'csv', 'json', 'md', 'log', 'xml', 'html'].contains(ext)) {
      try {
        final raw = utf8.decode(fileBytes, allowMalformed: true);
        return _cleanExtractedText(raw);
      } catch (_) {
        return _cleanExtractedText(String.fromCharCodes(fileBytes));
      }
    }

    // 2. Image formats — ML Kit with Backend Fallback
    if (['png', 'jpg', 'jpeg', 'bmp', 'webp', 'tiff'].contains(ext)) {
      return await extractTextFromImage(fileBytes, filename, imagePath: filePath);
    }

    // 3. PDF files — On-Device FlateStream Decompression + Backend PyPDF Fallback
    if (ext == 'pdf') {
      String localText = _extractTextFromPdfBytes(fileBytes);
      if (localText.trim().length >= 20) {
        debugPrint('PDF on-device extracted ${localText.length} characters');
        return _cleanExtractedText(localText);
      }

      // If on-device stream parsing extracted minimal text, invoke backend PyPDF/OCR parser
      debugPrint('PDF on-device yielded low text ($localText), querying backend OCR engine...');
      final backendText = await _fallbackBackendExtract(fileBytes, filename);
      if (backendText.trim().isNotEmpty) {
        return _cleanExtractedText(backendText);
      }

      return _cleanExtractedText(localText);
    }

    return '';
  }

  /// High-accuracy Backend OCR fallback
  Future<String> _fallbackBackendExtract(Uint8List bytes, String filename) async {
    try {
      final backendText = await ApiService().extractTextFromBackend(bytes, filename);
      if (backendText.trim().isNotEmpty) {
        return _cleanExtractedText(backendText);
      }
    } catch (e) {
      debugPrint('Backend OCR fallback error: $e');
    }
    return '';
  }

  /// Comprehensive on-device PDF text extractor:
  /// - Locates and decompresses all ZLib / FlateDecode streams using pure Dart
  /// - Extracts text operators (Tj, TJ, hex byte strings, literal strings, BT/ET blocks)
  String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final textParts = <String>[];
      final pdfRaw = String.fromCharCodes(bytes);

      // Pass 1: Parse uncompressed text operators
      _parsePdfTextOperators(pdfRaw, textParts);

      // Pass 2: Locate and decompress all FlateDecode streams
      final streamPattern = RegExp(r'stream\r?\n', caseSensitive: false);
      final streamMatches = streamPattern.allMatches(pdfRaw).toList();

      for (final match in streamMatches) {
        final streamStartIndex = match.end;
        // Check header before stream for /FlateDecode
        final headerStart = streamStartIndex > 350 ? streamStartIndex - 350 : 0;
        final headerSegment = pdfRaw.substring(headerStart, match.start);

        final endStreamIndex = pdfRaw.indexOf('endstream', streamStartIndex);
        if (endStreamIndex == -1 || endStreamIndex <= streamStartIndex) continue;

        // Extract binary slice for the stream
        final streamBytes = bytes.sublist(streamStartIndex, endStreamIndex);

        if (headerSegment.contains('FlateDecode')) {
          try {
            final decompressed = ZLibDecoder().decodeBytes(streamBytes, verify: false);
            final decompressedStr = String.fromCharCodes(decompressed);
            _parsePdfTextOperators(decompressedStr, textParts);
          } catch (_) {
            // Stream decompression failed or wasn't standard zlib, continue
          }
        } else {
          // Plain ASCII stream
          final plainStream = String.fromCharCodes(streamBytes);
          _parsePdfTextOperators(plainStream, textParts);
        }
      }

      final joined = textParts.join(' ');
      return _cleanExtractedText(joined);
    } catch (e) {
      debugPrint('PDF text extraction error: $e');
      return '';
    }
  }

  /// Parse standard PDF layout and text operators: Tj, TJ, `<hex>` Tj, BT...ET
  void _parsePdfTextOperators(String content, List<String> textParts) {
    // 1. Literal strings in Tj: (Hello World) Tj
    final tjLiteral = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
    for (final match in tjLiteral.allMatches(content)) {
      final raw = match.group(1) ?? '';
      final unescaped = _unescapePdfString(raw);
      if (unescaped.trim().isNotEmpty) textParts.add(unescaped.trim());
    }

    // 2. Hexadecimal byte strings in Tj: <48656c6c6f> Tj
    final tjHex = RegExp(r'<([0-9a-fA-F\s]+)>\s*Tj');
    for (final match in tjHex.allMatches(content)) {
      final hex = match.group(1) ?? '';
      final decodedHex = _decodeHexPdfString(hex);
      if (decodedHex.trim().isNotEmpty) textParts.add(decodedHex.trim());
    }

    // 3. Strings inside TJ array operator: [ (Hello) 10 (World) <4142> ] TJ
    final tjArray = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    for (final match in tjArray.allMatches(content)) {
      final inner = match.group(1) ?? '';
      final innerLiteral = RegExp(r'\((.*?)\)');
      for (final m in innerLiteral.allMatches(inner)) {
        final t = _unescapePdfString(m.group(1) ?? '');
        if (t.trim().isNotEmpty) textParts.add(t.trim());
      }
      final innerHex = RegExp(r'<([0-9a-fA-F\s]+)>');
      for (final m in innerHex.allMatches(inner)) {
        final t = _decodeHexPdfString(m.group(1) ?? '');
        if (t.trim().isNotEmpty) textParts.add(t.trim());
      }
    }

    // 4. BT ... ET blocks
    final btEt = RegExp(r'BT\s*(.*?)\s*ET', dotAll: true);
    for (final match in btEt.allMatches(content)) {
      final block = match.group(1) ?? '';
      final blockLiterals = RegExp(r'\((.*?)\)');
      for (final m in blockLiterals.allMatches(block)) {
        final t = _unescapePdfString(m.group(1) ?? '');
        if (t.trim().isNotEmpty && t.length > 1) textParts.add(t.trim());
      }
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
