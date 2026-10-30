import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../domain/models/compression_preset.dart';
import '../../domain/models/page_instruction.dart';
import '../../domain/models/scanner_options.dart';

/// مخرجات العملية المنفذة داخل الخيط الخلفي (Dart Isolate).
class IsolatePdfOutput {
  const IsolatePdfOutput({
    required this.outputFilePaths,
    required this.originalSizeBytes,
    required this.finalSizeBytes,
    required this.pageCount,
    required this.durationMs,
    this.extractedTextPreview,
  });

  final List<String> outputFilePaths;
  final int originalSizeBytes;
  final int finalSizeBytes;
  final int pageCount;
  final int durationMs;
  final String? extractedTextPreview;

  String get primaryPath => outputFilePaths.first;
}

/// موضع ترقيم الصفحات في الوثيقة.
enum PageNumberPosition {
  bottomCenter('أسفل الوسط'),
  bottomRight('أسفل اليمين'),
  bottomLeft('أسفل اليسار'),
  topCenter('أعلى الوسط');

  const PageNumberPosition(this.title);
  final String title;
}

/// خدمة معالجة الـ PDF والأوفيس والصور داخل خيوط خلفية منفصلة (Dart Isolates).
class PdfIsolateService {
  const PdfIsolateService();

  /// يدمج ملفين أو أكثر في ملف PDF موحد داخل Isolate مستقل.
  Future<IsolatePdfOutput> mergePdfs({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final outputDocument = PdfDocument();
      outputDocument.pageSettings.margins.all = 0;

      var totalOriginalBytes = 0;
      var totalPages = 0;

      try {
        for (final path in inputPaths) {
          final bytes = File(path).readAsBytesSync();
          totalOriginalBytes += bytes.length;
          final sourceDoc = PdfDocument(inputBytes: bytes);
          try {
            for (var i = 0; i < sourceDoc.pages.count; i++) {
              final sourcePage = sourceDoc.pages[i];
              final template = sourcePage.createTemplate();
              final section = outputDocument.sections!.add();
              section.pageSettings.size = sourcePage.size;
              section.pageSettings.margins.all = 0;
              final newPage = section.pages.add();
              newPage.graphics.drawPdfTemplate(template, Offset.zero);
              totalPages++;
            }
          } finally {
            sourceDoc.dispose();
          }
        }

        final savedBytes = Uint8List.fromList(outputDocument.saveSync());
        File(outputPath).writeAsBytesSync(savedBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: totalOriginalBytes,
          finalSizeBytes: savedBytes.length,
          pageCount: totalPages,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        outputDocument.dispose();
      }
    });
  }

  /// يستخرج صفحات محددة في ملف جديد أو يفصل كل صفحة في ملف PDF مستقل داخل Isolate.
  Future<IsolatePdfOutput> splitPdf({
    required String inputPath,
    required String outputDirectory,
    required String baseOutputFileName,
    required List<int> oneBasedPages,
    required bool burstEachPageIntoSeparateFile,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final sourceDoc = PdfDocument(inputBytes: inputBytes);

      try {
        if (burstEachPageIntoSeparateFile) {
          final generatedPaths = <String>[];
          var totalFinalBytes = 0;

          for (var i = 0; i < sourceDoc.pages.count; i++) {
            final singleDoc = PdfDocument();
            try {
              final sourcePage = sourceDoc.pages[i];
              singleDoc.pageSettings.size = sourcePage.size;
              singleDoc.pageSettings.margins.all = 0;
              final newPage = singleDoc.pages.add();
              newPage.graphics.drawPdfTemplate(
                sourcePage.createTemplate(),
                Offset.zero,
              );
              final outPath =
                  '$outputDirectory/${baseOutputFileName}_page_${(i + 1).toString().padLeft(2, '0')}.pdf';
              final outBytes = Uint8List.fromList(singleDoc.saveSync());
              File(outPath).writeAsBytesSync(outBytes, flush: true);
              generatedPaths.add(outPath);
              totalFinalBytes += outBytes.length;
            } finally {
              singleDoc.dispose();
            }
          }

          stopwatch.stop();
          return IsolatePdfOutput(
            outputFilePaths: generatedPaths,
            originalSizeBytes: inputBytes.length,
            finalSizeBytes: totalFinalBytes,
            pageCount: sourceDoc.pages.count,
            durationMs: stopwatch.elapsedMilliseconds,
          );
        } else {
          final extractedDoc = PdfDocument();
          try {
            var count = 0;
            for (final pageNum in oneBasedPages) {
              final index = pageNum - 1;
              if (index < 0 || index >= sourceDoc.pages.count) continue;
              final sourcePage = sourceDoc.pages[index];
              final section = extractedDoc.sections!.add();
              section.pageSettings.size = sourcePage.size;
              section.pageSettings.margins.all = 0;
              final newPage = section.pages.add();
              newPage.graphics.drawPdfTemplate(
                sourcePage.createTemplate(),
                Offset.zero,
              );
              count++;
            }

            final outPath = '$outputDirectory/$baseOutputFileName.pdf';
            final outBytes = Uint8List.fromList(extractedDoc.saveSync());
            File(outPath).writeAsBytesSync(outBytes, flush: true);
            stopwatch.stop();

            return IsolatePdfOutput(
              outputFilePaths: [outPath],
              originalSizeBytes: inputBytes.length,
              finalSizeBytes: outBytes.length,
              pageCount: count,
              durationMs: stopwatch.elapsedMilliseconds,
            );
          } finally {
            extractedDoc.dispose();
          }
        }
      } finally {
        sourceDoc.dispose();
      }
    });
  }

  /// يعيد ترتيب الصفحات ويطبق التدوير (90°/180°/270°) ويحذف الصفحات المستبعدة داخل Isolate.
  Future<IsolatePdfOutput> organizePages({
    required String inputPath,
    required String outputPath,
    required List<PdfPageInstruction> instructions,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final sourceDoc = PdfDocument(inputBytes: inputBytes);
      final targetDoc = PdfDocument();

      try {
        var addedPages = 0;
        for (final instruction in instructions) {
          final index = instruction.originalPageNumber - 1;
          if (index < 0 || index >= sourceDoc.pages.count) continue;

          final sourcePage = sourceDoc.pages[index];
          final section = targetDoc.sections!.add();
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;
          section.pageSettings.rotate =
              _mapRotationAngle(instruction.rotationDegrees);

          final newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(
            sourcePage.createTemplate(),
            Offset.zero,
          );
          addedPages++;
        }

        final outBytes = Uint8List.fromList(targetDoc.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: addedPages,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        targetDoc.dispose();
        sourceDoc.dispose();
      }
    });
  }

  /// يدور جميع صفحات ملف الـ PDF بزاوية محددة (90° / 180° / 270°).
  Future<IsolatePdfOutput> rotateAllPages({
    required String inputPath,
    required String outputPath,
    required int rotationDegrees,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final sourceDoc = PdfDocument(inputBytes: inputBytes);
      final targetDoc = PdfDocument();

      try {
        final angle = _mapRotationAngle(rotationDegrees);
        for (var i = 0; i < sourceDoc.pages.count; i++) {
          final sourcePage = sourceDoc.pages[i];
          final section = targetDoc.sections!.add();
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;
          section.pageSettings.rotate = angle;
          final newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(
            sourcePage.createTemplate(),
            Offset.zero,
          );
        }

        final outBytes = Uint8List.fromList(targetDoc.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: sourceDoc.pages.count,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        targetDoc.dispose();
        sourceDoc.dispose();
      }
    });
  }

  /// يضغط ملف PDF وفق المستوى المختار داخل Isolate.
  Future<IsolatePdfOutput> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionLevel level,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        document.compressionLevel = switch (level) {
          CompressionLevel.light => PdfCompressionLevel.aboveNormal,
          CompressionLevel.medium => PdfCompressionLevel.best,
          CompressionLevel.extreme => PdfCompressionLevel.best,
        };

        document.fileStructure.incrementalUpdate = false;

        final outBytes = Uint8List.fromList(document.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: document.pages.count,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// يحول مجموعة صور إلى ملف PDF داخل Isolate.
  Future<IsolatePdfOutput> convertImagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
    required ScannerToPdfOptions options,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final document = PdfDocument();
      var totalOriginalBytes = 0;

      try {
        for (final imgPath in imagePaths) {
          final rawBytes = File(imgPath).readAsBytesSync();
          totalOriginalBytes += rawBytes.length;

          final processedImageBytes = _applyDocumentFilterAndCrop(
            rawBytes: rawBytes,
            options: options,
          );
          final bitmap = PdfBitmap(processedImageBytes);

          final section = document.sections!.add();
          section.pageSettings.margins.all = options.margin.points;

          if (options.paperSize == PdfPaperSize.a4) {
            section.pageSettings.size = PdfPageSize.a4;
          } else {
            section.pageSettings.size = Size(
              bitmap.width.toDouble() + (options.margin.points * 2),
              bitmap.height.toDouble() + (options.margin.points * 2),
            );
          }

          final page = section.pages.add();
          final bounds = page.getClientSize();
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          );
        }

        final outBytes = Uint8List.fromList(document.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: totalOriginalBytes,
          finalSizeBytes: outBytes.length,
          pageCount: imagePaths.length,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// يضيف أرقام الصفحات إلى جميع صفحات ملف الـ PDF.
  Future<IsolatePdfOutput> addPageNumbers({
    required String inputPath,
    required String outputPath,
    required PageNumberPosition position,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        final font = PdfStandardFont(
          PdfFontFamily.helvetica,
          11,
          style: PdfFontStyle.bold,
        );
        final brush = PdfSolidBrush(PdfColor(60, 65, 75));
        final total = document.pages.count;

        for (var i = 0; i < total; i++) {
          final page = document.pages[i];
          final size = page.getClientSize();
          final label = '${i + 1} / $total';
          final x = switch (position) {
            PageNumberPosition.bottomCenter ||
            PageNumberPosition.topCenter =>
              (size.width / 2) - 20,
            PageNumberPosition.bottomRight => size.width - 65,
            PageNumberPosition.bottomLeft => 28.0,
          };
          final y = position == PageNumberPosition.topCenter
              ? 20.0
              : size.height - 28.0;

          page.graphics.drawString(
            label,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(x, y, 80, 20),
          );
        }

        final outBytes = Uint8List.fromList(document.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: total,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// يطبع صورة شفافة (علامة مائية، أو توقيع، أو نص تعديل) على صفحات الـ PDF.
  Future<IsolatePdfOutput> stampOverlayOnPdf({
    required String inputPath,
    required String outputPath,
    required Uint8List overlayPngBytes,
    required double opacity,
    required bool allPages,
    required bool centerDiagonal,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        final bitmap = PdfBitmap(overlayPngBytes);
        final total = document.pages.count;
        final indices = allPages
            ? List<int>.generate(total, (i) => i)
            : <int>[total - 1];

        for (final idx in indices) {
          if (idx < 0 || idx >= total) continue;
          final page = document.pages[idx];
          final size = page.getClientSize();
          final state = page.graphics.save();
          page.graphics.setTransparency(opacity.clamp(0.1, 1.0));

          if (centerDiagonal) {
            final drawW = size.width * 0.65;
            final drawH = drawW * (bitmap.height / bitmap.width);
            final dx = (size.width - drawW) / 2;
            final dy = (size.height - drawH) / 2;
            page.graphics.drawImage(
              bitmap,
              Rect.fromLTWH(dx, dy, drawW, drawH),
            );
          } else {
            final drawW = (size.width * 0.35).clamp(110.0, 220.0);
            final drawH = drawW * (bitmap.height / bitmap.width);
            final dx = size.width - drawW - 32;
            final dy = size.height - drawH - 42;
            page.graphics.drawImage(
              bitmap,
              Rect.fromLTWH(dx, dy, drawW, drawH),
            );
          }

          page.graphics.restore(state);
        }

        final outBytes = Uint8List.fromList(document.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: total,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// يحمي ملف الـ PDF بكلمة مرور سرية.
  Future<IsolatePdfOutput> protectPdf({
    required String inputPath,
    required String outputPath,
    required String password,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        document.security.userPassword = password;
        document.security.ownerPassword = password;

        final outBytes = Uint8List.fromList(document.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: document.pages.count,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// يزيل قفل كلمة المرور من ملف PDF محمي.
  Future<IsolatePdfOutput> unlockPdf({
    required String inputPath,
    required String outputPath,
    required String password,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final sourceDoc = PdfDocument(
        inputBytes: inputBytes,
        password: password.isEmpty ? null : password,
      );
      final cleanDoc = PdfDocument();

      try {
        for (var i = 0; i < sourceDoc.pages.count; i++) {
          final srcPage = sourceDoc.pages[i];
          final section = cleanDoc.sections!.add();
          section.pageSettings.size = srcPage.size;
          section.pageSettings.margins.all = 0;
          final page = section.pages.add();
          page.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero);
        }

        final outBytes = Uint8List.fromList(cleanDoc.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: sourceDoc.pages.count,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        cleanDoc.dispose();
        sourceDoc.dispose();
      }
    });
  }

  /// يصلح هيكل ملف الـ PDF ويعيد بناء جداول الكائنات.
  Future<IsolatePdfOutput> repairPdf({
    required String inputPath,
    required String outputPath,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final sourceDoc = PdfDocument(inputBytes: inputBytes);
      final rebuiltDoc = PdfDocument();

      try {
        rebuiltDoc.fileStructure.incrementalUpdate = false;
        rebuiltDoc.compressionLevel = PdfCompressionLevel.normal;

        for (var i = 0; i < sourceDoc.pages.count; i++) {
          final srcPage = sourceDoc.pages[i];
          final section = rebuiltDoc.sections!.add();
          section.pageSettings.size = srcPage.size;
          section.pageSettings.margins.all = 0;
          final newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(
            srcPage.createTemplate(),
            Offset.zero,
          );
        }

        final outBytes = Uint8List.fromList(rebuiltDoc.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: sourceDoc.pages.count,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        rebuiltDoc.dispose();
        sourceDoc.dispose();
      }
    });
  }

  /// يستخرج النصوص من ملف PDF ويحفظها بالصيغة المطلوبة (TXT / DOC / XLS / PPT).
  Future<IsolatePdfOutput> extractOrConvertPdfText({
    required String inputPath,
    required String outputPath,
    required String targetFormat, // 'txt', 'doc', 'csv', 'ppt'
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = File(inputPath).readAsBytesSync();
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        final extractor = PdfTextExtractor(document);
        final totalPages = document.pages.count;
        final pageTexts = <String>[];

        for (var i = 0; i < totalPages; i++) {
          final pageText = extractor
              .extractText(startPageIndex: i, endPageIndex: i)
              .trim();
          pageTexts.add(
            pageText.isEmpty ? '[صفحة ${i + 1}]' : pageText,
          );
        }

        final fullPlainText = pageTexts.join('\n\n--- صفحة ---\n\n');
        late final List<int> encodedBytes;

        switch (targetFormat) {
          case 'doc':
            final htmlDoc = StringBuffer()
              ..writeln(
                '<html xmlns:o="urn:schemas-microsoft-com:office:office" '
                'xmlns:w="urn:schemas-microsoft-com:office:word" '
                'xmlns="http://www.w3.org/TR/REC-html40" dir="rtl">',
              )
              ..writeln('<head><meta charset="utf-8"><title>Document</title></head>')
              ..writeln('<body style="font-family:Arial,sans-serif;direction:rtl;">');
            for (var i = 0; i < pageTexts.length; i++) {
              htmlDoc.writeln('<h3>صفحة ${i + 1}</h3>');
              for (final line in pageTexts[i].split('\n')) {
                final escaped = const HtmlEscape().convert(line);
                htmlDoc.writeln('<p>$escaped</p>');
              }
              if (i < pageTexts.length - 1) {
                htmlDoc.writeln('<br style="page-break-before:always">');
              }
            }
            htmlDoc.writeln('</body></html>');
            encodedBytes = utf8.encode(htmlDoc.toString());

          case 'ppt':
            final pptHtml = StringBuffer()
              ..writeln('<!DOCTYPE html><html dir="rtl"><head><meta charset="utf-8"></head><body>');
            for (var i = 0; i < pageTexts.length; i++) {
              pptHtml.writeln(
                '<div style="border:1px solid #888;padding:24px;margin:16px 0;">'
                '<h2>شريحة ${i + 1}</h2><pre style="white-space:pre-wrap;font-family:sans-serif;">'
                '${const HtmlEscape().convert(pageTexts[i])}</pre></div>',
              );
            }
            pptHtml.writeln('</body></html>');
            encodedBytes = utf8.encode(pptHtml.toString());

          case 'csv':
            final csv = StringBuffer('\uFEFFرقم الصفحة,السطر,المحتوى\n');
            for (var i = 0; i < pageTexts.length; i++) {
              final lines = pageTexts[i].split('\n');
              for (var l = 0; l < lines.length; l++) {
                final clean = lines[l].replaceAll('"', '""').trim();
                if (clean.isNotEmpty) {
                  csv.writeln('${i + 1},${l + 1},"$clean"');
                }
              }
            }
            encodedBytes = utf8.encode(csv.toString());

          default:
            encodedBytes = utf8.encode(fullPlainText);
        }

        File(outputPath).writeAsBytesSync(encodedBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: encodedBytes.length,
          pageCount: totalPages,
          durationMs: stopwatch.elapsedMilliseconds,
          extractedTextPreview: fullPlainText.length > 600
              ? '${fullPlainText.substring(0, 600)}...'
              : fullPlainText,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// ينشئ ملف PDF من صور صفحات مرسومة مسبقاً (يدعم العربية والإنجليزية والجداول).
  Future<IsolatePdfOutput> buildPdfFromRenderedPages({
    required List<Uint8List> pagePngList,
    required String outputPath,
    int originalBytesHint = 0,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final document = PdfDocument();
      document.pageSettings.margins.all = 0;

      try {
        for (final pngBytes in pagePngList) {
          final bitmap = PdfBitmap(pngBytes);
          final section = document.sections!.add();
          section.pageSettings.size = PdfPageSize.a4;
          section.pageSettings.margins.all = 0;
          final page = section.pages.add();
          final bounds = page.getClientSize();
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          );
        }

        final outBytes = Uint8List.fromList(document.saveSync());
        File(outputPath).writeAsBytesSync(outBytes, flush: true);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes:
              originalBytesHint > 0 ? originalBytesHint : outBytes.length,
          finalSizeBytes: outBytes.length,
          pageCount: pagePngList.length,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        document.dispose();
      }
    });
  }

  /// يستخرج النص المقروء من ملفات الأوفيس (DOCX / XLSX / PPTX / TXT / CSV) محلياً.
  Future<String> extractReadableTextFromOfficeFile(String filePath) async {
    return Isolate.run(() {
      final bytes = File(filePath).readAsBytesSync();
      final lower = filePath.toLowerCase();

      if (lower.endsWith('.txt') ||
          lower.endsWith('.csv') ||
          lower.endsWith('.rtf')) {
        return utf8.decode(bytes, allowMalformed: true);
      }

      // فك ضغط XML الداخلي لملفات أوفيس (DOCX / XLSX / PPTX) المبنية على ZIP
      if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        final extractedXmlChunks = <String>[];
        var offset = 0;
        while (offset + 30 <= bytes.length) {
          if (bytes[offset] != 0x50 ||
              bytes[offset + 1] != 0x4B ||
              bytes[offset + 2] != 0x03 ||
              bytes[offset + 3] != 0x04) {
            offset++;
            continue;
          }
          final compressionMethod =
              bytes[offset + 8] | (bytes[offset + 9] << 8);
          final compressedSize = bytes[offset + 18] |
              (bytes[offset + 19] << 8) |
              (bytes[offset + 20] << 16) |
              (bytes[offset + 21] << 24);
          final fileNameLen = bytes[offset + 26] | (bytes[offset + 27] << 8);
          final extraLen = bytes[offset + 28] | (bytes[offset + 29] << 8);
          final nameStart = offset + 30;
          final dataStart = nameStart + fileNameLen + extraLen;
          if (dataStart + compressedSize > bytes.length || compressedSize < 0) {
            break;
          }
          final entryName = utf8.decode(
            bytes.sublist(nameStart, nameStart + fileNameLen),
            allowMalformed: true,
          );
          if (entryName.endsWith('.xml') &&
              (entryName.contains('document') ||
                  entryName.contains('sharedStrings') ||
                  entryName.contains('sheet') ||
                  entryName.contains('slide'))) {
            try {
              final rawSlice =
                  bytes.sublist(dataStart, dataStart + compressedSize);
              final decompressed = compressionMethod == 8
                  ? ZLibCodec(raw: true).decode(rawSlice)
                  : rawSlice;
              final xmlStr = utf8.decode(decompressed, allowMalformed: true);
              final stripped = xmlStr
                  .replaceAll(RegExp(r'</w:p>|</a:p>|</row>'), '\n')
                  .replaceAll(RegExp(r'<[^>]+>'), ' ')
                  .replaceAll(RegExp(r'[ \t]+'), ' ')
                  .trim();
              if (stripped.isNotEmpty) {
                extractedXmlChunks.add(stripped);
              }
            } catch (_) {}
          }
          offset = dataStart + compressedSize;
        }
        if (extractedXmlChunks.isNotEmpty) {
          return extractedXmlChunks.join('\n\n');
        }
      }

      final fallback = utf8
          .decode(bytes, allowMalformed: true)
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .trim();
      return fallback.isEmpty ? 'محتوى المستند: ${filePath.split('/').last}' : fallback;
    });
  }

  /// يعالج الصور (ضغط الصورة، التحويل إلى JPG، أو التحويل من JPG إلى PNG).
  Future<IsolatePdfOutput> processImageFile({
    required String inputImagePath,
    required String outputPath,
    required String mode, // 'compress', 'to_jpg', 'from_jpg'
    CompressionLevel level = CompressionLevel.medium,
  }) async {
    return Isolate.run(() {
      final stopwatch = Stopwatch()..start();
      final rawBytes = File(inputImagePath).readAsBytesSync();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        throw const FormatException('تعذر قراءة ملف الصورة المختار.');
      }

      late final Uint8List outBytes;
      if (mode == 'from_jpg') {
        outBytes = Uint8List.fromList(img.encodePng(decoded));
      } else if (mode == 'to_jpg') {
        outBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      } else {
        final quality = switch (level) {
          CompressionLevel.light => 80,
          CompressionLevel.medium => 55,
          CompressionLevel.extreme => 30,
        };
        var working = decoded;
        if (level == CompressionLevel.extreme && working.width > 1400) {
          working = img.copyResize(working, width: 1400);
        }
        outBytes = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      }

      File(outputPath).writeAsBytesSync(outBytes, flush: true);
      stopwatch.stop();

      return IsolatePdfOutput(
        outputFilePaths: [outputPath],
        originalSizeBytes: rawBytes.length,
        finalSizeBytes: outBytes.length,
        pageCount: 1,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    });
  }

  static PdfPageRotateAngle _mapRotationAngle(int degrees) {
    final normalized = degrees % 360;
    return switch (normalized) {
      90 => PdfPageRotateAngle.rotateAngle90,
      180 => PdfPageRotateAngle.rotateAngle180,
      270 => PdfPageRotateAngle.rotateAngle270,
      _ => PdfPageRotateAngle.rotateAngle0,
    };
  }

  static Uint8List _applyDocumentFilterAndCrop({
    required Uint8List rawBytes,
    required ScannerToPdfOptions options,
  }) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    var working = decoded;

    if (options.autoCropEdges && working.width > 120 && working.height > 120) {
      final trimX = (working.width * 0.02).round();
      final trimY = (working.height * 0.02).round();
      working = img.copyCrop(
        working,
        x: trimX,
        y: trimY,
        width: working.width - (trimX * 2),
        height: working.height - (trimY * 2),
      );
    }

    switch (options.colorFilter) {
      case DocumentColorFilter.highContrastBw:
        working = img.grayscale(working);
        working = img.contrast(working, contrast: 145);
      case DocumentColorFilter.grayscale:
        working = img.grayscale(working);
      case DocumentColorFilter.originalColor:
        break;
    }

    return Uint8List.fromList(img.encodeJpg(working, quality: 88));
  }
}
