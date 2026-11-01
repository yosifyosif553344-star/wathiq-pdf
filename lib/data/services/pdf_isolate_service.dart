import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../domain/models/compression_preset.dart';
import '../../domain/models/page_instruction.dart';
import '../../domain/models/scanner_options.dart';
import 'platform_storage.dart';

/// مخرجات العملية المنفذة داخل الخيط الخلفي (Dart Isolate أو Web Task).
class IsolatePdfOutput {
  const IsolatePdfOutput({
    required this.outputFilePaths,
    required this.originalSizeBytes,
    required this.finalSizeBytes,
    required this.pageCount,
    required this.durationMs,
  });

  final List<String> outputFilePaths;
  final int originalSizeBytes;
  final int finalSizeBytes;
  final int pageCount;
  final int durationMs;

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

/// خدمة معالجة الـ PDF داخل خيوط خلفية منفصلة على الأندرويد/iOS أو محلياً داخل المتصفح.
class PdfIsolateService {
  const PdfIsolateService();

  /// يدمج ملفين أو أكثر في ملف PDF موحد.
  Future<IsolatePdfOutput> mergePdfs({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final outputDocument = PdfDocument();
      outputDocument.pageSettings.margins.all = 0;

      var totalOriginalBytes = 0;
      var totalPages = 0;

      try {
        for (final path in inputPaths) {
          final bytes = PlatformStorage.readBytesSync(path);
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
        PlatformStorage.writeBytesSync(outputPath, savedBytes);
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

  /// يستخرج صفحات محددة في ملف جديد أو يفصل كل صفحة في ملف PDF مستقل.
  Future<IsolatePdfOutput> splitPdf({
    required String inputPath,
    required String outputDirectory,
    required String baseOutputFileName,
    required List<int> oneBasedPages,
    required bool burstEachPageIntoSeparateFile,
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
              PlatformStorage.writeBytesSync(outPath, outBytes);
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
            PlatformStorage.writeBytesSync(outPath, outBytes);
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

  /// يعيد ترتيب الصفحات ويطبق التدوير (90°/180°/270°) ويحذف الصفحات المستبعدة.
  Future<IsolatePdfOutput> organizePages({
    required String inputPath,
    required String outputPath,
    required List<PdfPageInstruction> instructions,
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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

  /// يضغط ملف PDF وفق المستوى المختار.
  Future<IsolatePdfOutput> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionLevel level,
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
      final sourceDoc = PdfDocument(inputBytes: inputBytes);

      try {
        final totalPages = sourceDoc.pages.count;
        final syncCompression = switch (level) {
          CompressionLevel.light => PdfCompressionLevel.aboveNormal,
          CompressionLevel.medium => PdfCompressionLevel.best,
          CompressionLevel.extreme => PdfCompressionLevel.best,
        };

        var bestBytes = inputBytes;
        Uint8List? standardTableBytes;

        // 1. إعادة بناء الوثيقة بجدول مراجع نصي قياسي (crossReferenceTable) لتسهيل ضغط الصور وتيارات البيانات
        final rebuiltDoc = PdfDocument();
        try {
          rebuiltDoc.compressionLevel = syncCompression;
          rebuiltDoc.fileStructure.crossReferenceType =
              PdfCrossReferenceType.crossReferenceTable;
          rebuiltDoc.fileStructure.incrementalUpdate = false;
          for (var i = 0; i < totalPages; i++) {
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
          final rebuiltBytes = Uint8List.fromList(rebuiltDoc.saveSync());
          if (rebuiltBytes.isNotEmpty) {
            standardTableBytes = rebuiltBytes;
            if (rebuiltBytes.length < bestBytes.length) {
              bestBytes = rebuiltBytes;
            }
          }
        } catch (_) {
          // في حال تعذر نسخ القوالب لبعض الصفحات المعقدة نحتفظ بالنسخة الأصلية للمرحلة التالية
        } finally {
          rebuiltDoc.dispose();
        }

        // 2. محاولة ضغط تيارات الكائنات مباشرة عبر حفظ الوثيقة بأعلى مستوى ضغط
        try {
          sourceDoc.compressionLevel = syncCompression;
          final directBytes = Uint8List.fromList(sourceDoc.saveSync());
          if (directBytes.isNotEmpty && directBytes.length < bestBytes.length) {
            bestBytes = directBytes;
          }
        } catch (_) {
          // تجاهل أي خطأ في جدول المراجع المتقاطعة لبعض الملفات القديمة
        }

        // 3. ضغط جميع الصور المضمنة (JPEG + FlateDecode Bitmaps) وتيارات البيانات في النسخة القياسية والأصلية
        if (standardTableBytes != null) {
          final compressedRebuilt = _recompressEmbeddedJpegsInPdf(
            pdfBytes: standardTableBytes,
            level: level,
            expectedPages: totalPages,
          );
          if (compressedRebuilt.length < bestBytes.length) {
            bestBytes = compressedRebuilt;
          }
        }

        final imageCompressedBytes = _recompressEmbeddedJpegsInPdf(
          pdfBytes: bestBytes,
          level: level,
          expectedPages: totalPages,
        );
        if (imageCompressedBytes.length < bestBytes.length) {
          bestBytes = imageCompressedBytes;
        }

        PlatformStorage.writeBytesSync(outputPath, bestBytes);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: bestBytes.length,
          pageCount: totalPages,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        sourceDoc.dispose();
      }
    });
  }

  /// يحول مجموعة صور إلى ملف PDF.
  Future<IsolatePdfOutput> convertImagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
    required ScannerToPdfOptions options,
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final document = PdfDocument();
      var totalOriginalBytes = 0;

      try {
        for (final imgPath in imagePaths) {
          final rawBytes = PlatformStorage.readBytesSync(imgPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        document.security.userPassword = password;
        document.security.ownerPassword = password;

        final outBytes = Uint8List.fromList(document.saveSync());
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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

  /// يستخرج نصوص ملف الـ PDF ويحفظها في ملف TXT بترميز UTF-8 مع BOM لدعم العربية بالكامل.
  Future<IsolatePdfOutput> extractPdfText({
    required String inputPath,
    required String outputPath,
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final inputBytes = PlatformStorage.readBytesSync(inputPath);
      final document = PdfDocument(inputBytes: inputBytes);

      try {
        final extractor = PdfTextExtractor(document);
        final totalPages = document.pages.count;
        final buffer = StringBuffer();

        // التحقق مما إذا كان الملف منشأً داخل التطبيق مع نص عربي مضمّن
        final embeddedKw = document.documentInformation.keywords;
        String? embeddedFullText;
        if (embeddedKw.startsWith('WATHIQ_TEXT_B64:')) {
          try {
            final b64 = embeddedKw.substring('WATHIQ_TEXT_B64:'.length);
            embeddedFullText = utf8.decode(base64Decode(b64));
          } catch (_) {
            embeddedFullText = null;
          }
        }

        var hasExtractedAnyText = false;
        for (var i = 0; i < totalPages; i++) {
          final rawPageText = extractor
              .extractText(startPageIndex: i, endPageIndex: i)
              .trim();
          final normalizedPageText = _normalizeExtractedArabicText(rawPageText);
          if (normalizedPageText.isNotEmpty) {
            hasExtractedAnyText = true;
          }
          buffer
            ..writeln('--- صفحة ${i + 1} ---')
            ..writeln(normalizedPageText)
            ..writeln();
        }

        if (!hasExtractedAnyText &&
            embeddedFullText != null &&
            embeddedFullText.trim().isNotEmpty) {
          buffer
            ..clear()
            ..writeln('--- النص المستخرج ---')
            ..writeln(embeddedFullText.trim())
            ..writeln();
        }

        final utf8Content = utf8.encode(buffer.toString());
        // إضافة علامة ترتيب البايتات UTF-8 BOM (0xEF, 0xBB, 0xBF) لضمان قراءة العربية بشكل سليم في المتصفح والهاتف
        final encodedBytes = Uint8List(3 + utf8Content.length)
          ..[0] = 0xEF
          ..[1] = 0xBB
          ..[2] = 0xBF
          ..setRange(3, 3 + utf8Content.length, utf8Content);

        PlatformStorage.writeBytesSync(outputPath, encodedBytes);
        stopwatch.stop();

        return IsolatePdfOutput(
          outputFilePaths: [outputPath],
          originalSizeBytes: inputBytes.length,
          finalSizeBytes: encodedBytes.length,
          pageCount: totalPages,
          durationMs: stopwatch.elapsedMilliseconds,
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
    String embeddedPlainText = '',
  }) async {
    return PlatformStorage.runTask(() {
      final stopwatch = Stopwatch()..start();
      final document = PdfDocument();
      document.pageSettings.margins.all = 0;

      try {
        if (embeddedPlainText.trim().isNotEmpty) {
          document.documentInformation.keywords =
              'WATHIQ_TEXT_B64:${base64Encode(utf8.encode(embeddedPlainText))}';
        }
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
        PlatformStorage.writeBytesSync(outputPath, outBytes);
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

  /// يضغط تيارات الصور المضمنة (DCTDecode + FlateDecode Images) وتيارات البيانات داخل الـ PDF ويعيد بناء جدول المراجع (xref).
  static Uint8List _recompressEmbeddedJpegsInPdf({
    required Uint8List pdfBytes,
    required CompressionLevel level,
    required int expectedPages,
  }) {
    try {
      final rawText = latin1.decode(pdfBytes);
      final startXrefIdx = rawText.lastIndexOf('startxref');
      if (startXrefIdx <= 0) return pdfBytes;
      final trailerIdx = rawText.lastIndexOf('trailer', startXrefIdx);
      if (trailerIdx <= 0) return pdfBytes;
      final xrefPos = rawText.lastIndexOf(RegExp(r'\bxref\b'), trailerIdx);
      if (xrefPos <= 0) return pdfBytes;

      final maxDim = switch (level) {
        CompressionLevel.light => 1800,
        CompressionLevel.medium => 1200,
        CompressionLevel.extreme => 780,
      };

      final streamPattern = RegExp(r'stream\r?\n');
      final endStreamEndObjPattern = RegExp(r'endstream[\r\n\s]*endobj');
      final lengthPattern = RegExp(r'/Length\s+\d+(?:\s+0\s+R)?');
      final widthPattern = RegExp(r'/Width\s+(\d+)');
      final heightPattern = RegExp(r'/Height\s+(\d+)');
      final objHeaderPattern = RegExp(r'(\d+)\s+0\s+obj\b');

      final outBuffer = BytesBuilder(copy: false);
      var cursor = 0;
      var changedAny = false;

      for (final match in objHeaderPattern.allMatches(rawText)) {
        if (match.start < cursor || match.start >= xrefPos) continue;
        final streamMatch = streamPattern.firstMatch(
          rawText.substring(
            match.end,
            (match.end + 1200).clamp(0, xrefPos),
          ),
        );
        if (streamMatch == null) continue;

        final dictHeader = rawText.substring(
          match.start,
          match.end + streamMatch.end,
        );
        final lenMatch = lengthPattern.firstMatch(dictHeader);
        if (lenMatch == null) continue;

        final streamDataStart = match.end + streamMatch.end;
        final endMatch = endStreamEndObjPattern.firstMatch(
          rawText.substring(streamDataStart, xrefPos),
        );
        if (endMatch == null) continue;

        final objEnd = streamDataStart + endMatch.end;
        var streamDataEnd = streamDataStart + endMatch.start;
        if (streamDataEnd > streamDataStart &&
            pdfBytes[streamDataEnd - 1] == 0x0A) {
          streamDataEnd--;
          if (streamDataEnd > streamDataStart &&
              pdfBytes[streamDataEnd - 1] == 0x0D) {
            streamDataEnd--;
          }
        }
        if (streamDataEnd <= streamDataStart + 16) continue;

        final origStreamBytes = Uint8List.sublistView(
          pdfBytes,
          streamDataStart,
          streamDataEnd,
        );

        final isImageObj = dictHeader.contains('/DCTDecode') ||
            dictHeader.contains('/Subtype /Image') ||
            dictHeader.contains('/Subtype/Image');

        if (isImageObj && !dictHeader.contains('/ImageMask')) {
          img.Image? decodedImg;

          var unpacked = origStreamBytes;
          if (dictHeader.contains('/FlateDecode') &&
              !(origStreamBytes.length > 2 &&
                  origStreamBytes[0] == 0xFF &&
                  origStreamBytes[1] == 0xD8)) {
            try {
              unpacked = Uint8List.fromList(
                const ZLibDecoder().decodeBytes(origStreamBytes),
              );
            } catch (_) {
              unpacked = origStreamBytes;
            }
          }

          if ((unpacked.length > 2 &&
                  unpacked[0] == 0xFF &&
                  unpacked[1] == 0xD8) ||
              dictHeader.contains('/DCTDecode')) {
            decodedImg = img.decodeJpg(unpacked) ?? img.decodeImage(unpacked);
          } else if (dictHeader.contains('/FlateDecode') &&
              !dictHeader.contains('/DeviceCMYK')) {
            final wMatch = widthPattern.firstMatch(dictHeader);
            final hMatch = heightPattern.firstMatch(dictHeader);
            final w = wMatch != null ? int.tryParse(wMatch.group(1)!) : null;
            final h = hMatch != null ? int.tryParse(hMatch.group(1)!) : null;
            final channels = dictHeader.contains('/DeviceGray') ? 1 : 3;

            if (w != null && h != null && w > 0 && h > 0) {
              decodedImg = _decodeRawOrPngPredictedBitmap(
                unpacked: unpacked,
                width: w,
                height: h,
                channels: channels,
              );
            }
          }

          if (decodedImg != null) {
            var working = decodedImg;
            if (working.width > maxDim || working.height > maxDim) {
              working = working.width >= working.height
                  ? img.copyResize(working, width: maxDim)
                  : img.copyResize(working, height: maxDim);
            }

            final reencoded = Uint8List.fromList(
              img.encodeJpg(working, quality: level.imageQuality),
            );

            if (reencoded.length + 16 < origStreamBytes.length) {
              var newDict = dictHeader.replaceFirst(
                lengthPattern,
                '/Length ${reencoded.length}',
              );
              newDict = newDict.replaceAll(
                RegExp(r'/Filter\s*\[[^\]]*\]'),
                '/Filter /DCTDecode',
              );
              newDict = newDict.replaceAll(
                RegExp(r'/Filter\s*/FlateDecode'),
                '/Filter /DCTDecode',
              );
              newDict = newDict.replaceAll(
                RegExp(r'/DecodeParms\s*(?:<<[^>]*>>|\[[^\]]*\])'),
                '',
              );
              if (working.width != decodedImg.width ||
                  working.height != decodedImg.height) {
                newDict = newDict
                    .replaceFirst(widthPattern, '/Width ${working.width}')
                    .replaceFirst(heightPattern, '/Height ${working.height}');
              }
              if (dictHeader.contains('/DeviceGray') &&
                  !newDict.contains('/DeviceRGB')) {
                newDict = newDict.replaceFirst('/DeviceGray', '/DeviceRGB');
              }

              outBuffer.add(
                Uint8List.sublistView(pdfBytes, cursor, match.start),
              );
              outBuffer.add(latin1.encode(newDict));
              outBuffer.add(reencoded);
              outBuffer.add(latin1.encode('\r\nendstream\r\nendobj'));
              cursor = objEnd;
              changedAny = true;
            }
          }
        } else if (dictHeader.contains('/FlateDecode') &&
            !dictHeader.contains('/DecodeParms') &&
            origStreamBytes.length > 512) {
          // إعادة ضغط تيارات الخطوط والنصوص بأقصى مستوى (ZLib Level 9)
          try {
            final unpacked = const ZLibDecoder().decodeBytes(origStreamBytes);
            final recompressed = Uint8List.fromList(
              const ZLibEncoder().encode(unpacked, level: 9),
            );
            if (recompressed.length + 12 < origStreamBytes.length) {
              final newDict = dictHeader.replaceFirst(
                lengthPattern,
                '/Length ${recompressed.length}',
              );
              outBuffer.add(
                Uint8List.sublistView(pdfBytes, cursor, match.start),
              );
              outBuffer.add(latin1.encode(newDict));
              outBuffer.add(recompressed);
              outBuffer.add(latin1.encode('\r\nendstream\r\nendobj'));
              cursor = objEnd;
              changedAny = true;
            }
          } catch (_) {
            // نتجاوز التيارات غير القياسية
          }
        }
      }

      if (!changedAny) return pdfBytes;

      outBuffer.add(Uint8List.sublistView(pdfBytes, cursor, xrefPos));
      final bodyBytes = outBuffer.toBytes();
      final bodyText = latin1.decode(bodyBytes);

      final offsets = <int, int>{};
      var maxObjNum = 0;
      for (final m in objHeaderPattern.allMatches(bodyText)) {
        final id = int.tryParse(m.group(1)!);
        if (id != null) {
          offsets[id] = m.start;
          if (id > maxObjNum) maxObjNum = id;
        }
      }

      final trailerDict = rawText.substring(trailerIdx, startXrefIdx);

      final newXrefOffset = bodyBytes.length;
      final xrefBuf = StringBuffer()
        ..write('xref\r\n')
        ..write('0 ${maxObjNum + 1}\r\n')
        ..write('0000000000 65535 f \r\n');

      for (var i = 1; i <= maxObjNum; i++) {
        final off = offsets[i];
        if (off != null) {
          xrefBuf.write('${off.toString().padLeft(10, '0')} 00000 n \r\n');
        } else {
          xrefBuf.write('0000000000 65535 f \r\n');
        }
      }

      xrefBuf
        ..write(trailerDict)
        ..write('startxref\r\n$newXrefOffset\r\n%%EOF\r\n');

      final finalBuilder = BytesBuilder(copy: false)
        ..add(bodyBytes)
        ..add(latin1.encode(xrefBuf.toString()));
      final candidate = finalBuilder.toBytes();

      final verifyDoc = PdfDocument(inputBytes: candidate);
      final validCount = verifyDoc.pages.count;
      verifyDoc.dispose();
      if (validCount == expectedPages) {
        return candidate;
      }
    } catch (_) {
      // في حال وجود تشفير أو تيارات معقدة نعود للنسخة الآمنة
    }
    return pdfBytes;
  }

  /// يحول بيانات البكسل الخام أو المفلترة بـ PNG Predictor داخل FlateDecode إلى كائن صورة قابل للضغط.
  static img.Image? _decodeRawOrPngPredictedBitmap({
    required Uint8List unpacked,
    required int width,
    required int height,
    required int channels,
  }) {
    final rowBytes = width * channels;
    final expectedRawLen = rowBytes * height;
    final expectedPredictedLen = (rowBytes + 1) * height;

    Uint8List? rawPixels;
    if (unpacked.length == expectedRawLen) {
      rawPixels = unpacked;
    } else if (unpacked.length == expectedPredictedLen) {
      rawPixels = Uint8List(expectedRawLen);
      var srcOffset = 0;
      var dstOffset = 0;
      for (var y = 0; y < height; y++) {
        final filter = unpacked[srcOffset++];
        for (var x = 0; x < rowBytes; x++) {
          final raw = unpacked[srcOffset++];
          final left = x >= channels ? rawPixels[dstOffset + x - channels] : 0;
          final up = y > 0 ? rawPixels[dstOffset - rowBytes + x] : 0;
          final upLeft = (y > 0 && x >= channels)
              ? rawPixels[dstOffset - rowBytes + x - channels]
              : 0;
          final val = switch (filter) {
            0 => raw,
            1 => (raw + left) & 0xFF,
            2 => (raw + up) & 0xFF,
            3 => (raw + ((left + up) >> 1)) & 0xFF,
            4 => (raw + _paethPredictor(left, up, upLeft)) & 0xFF,
            _ => raw,
          };
          rawPixels[dstOffset + x] = val;
        }
        dstOffset += rowBytes;
      }
    }

    if (rawPixels == null) return null;

    final image = img.Image(width: width, height: height);
    var idx = 0;
    if (channels == 1) {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final v = rawPixels[idx++];
          image.setPixelRgb(x, y, v, v, v);
        }
      }
    } else {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final r = rawPixels[idx++];
          final g = rawPixels[idx++];
          final b = rawPixels[idx++];
          image.setPixelRgb(x, y, r, g, b);
        }
      }
    }
    return image;
  }

  static int _paethPredictor(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  /// يعالج النصوص العربية المستخرجة من الـ PDF (تطبيع الحروف الموصولة وإصلاح الانعكاس البصري).
  static String _normalizeExtractedArabicText(String input) {
    if (input.isEmpty) return '';

    final rawLines = input.split(RegExp(r'\r?\n'));
    final processedLines = <String>[];

    for (final rawLine in rawLines) {
      if (rawLine.trim().isEmpty) {
        processedLines.add('');
        continue;
      }

      final presentationOrderScore = _scorePresentationFormVisualOrder(rawLine);
      final normalizedChars = _replaceArabicPresentationForms(rawLine);
      final reversedScore = _scoreReversedArabicHeuristic(normalizedChars);

      if (presentationOrderScore > 0 || reversedScore > 0) {
        processedLines.add(_reverseVisualArabicLine(normalizedChars));
      } else {
        processedLines.add(normalizedChars);
      }
    }

    return processedLines.join('\n');
  }

  /// يفحص ما إذا كانت أشكال الحروف العربية الموصولة (Presentation Forms-B) مرتبة بصرياً من اليسار لليمين.
  static int _scorePresentationFormVisualOrder(String line) {
    var visualCount = 0;
    var logicalCount = 0;
    final words = line.trim().split(RegExp(r'\s+'));
    for (final w in words) {
      if (w.length < 2) continue;
      final firstForm = _presentationFormKind(w.codeUnitAt(0));
      final lastForm = _presentationFormKind(w.codeUnitAt(w.length - 1));
      // في الترتيب المنطقي تبدأ الكلمة بحرف ابتدائي وتنتهي بحرف نهائي، والعكس في الترتيب البصري المعكوس
      if (firstForm == 1 && lastForm == 2) {
        visualCount += 2;
      } else if (firstForm == 1) {
        visualCount += 1;
      } else if (lastForm == 2) {
        visualCount += 1;
      } else if (firstForm == 2 && lastForm == 1) {
        logicalCount += 2;
      } else if (firstForm == 2 || lastForm == 1) {
        logicalCount += 1;
      }
    }
    return visualCount - logicalCount;
  }

  /// 1 = Final (نهائي), 2 = Initial (ابتدائي), 0 = غير ذلك.
  static int _presentationFormKind(int code) {
    // الحروف التي لها 4 أشكال في النطاق FE8D..FEFC
    const fourFormBases = <int>[
      0xFE8F, 0xFE95, 0xFE99, 0xFE9D, 0xFEA1, 0xFEA5,
      0xFEB1, 0xFEB5, 0xFEB9, 0xFEBD, 0xFEC1, 0xFEC5,
      0xFEC9, 0xFECD, 0xFED1, 0xFED5, 0xFED9, 0xFEDD,
      0xFEE1, 0xFEE5, 0xFEE9, 0xFEF1,
    ];
    for (final base in fourFormBases) {
      if (code == base + 1) return 1; // Final
      if (code == base + 2) return 2; // Initial
    }
    // الحروف التي لها شكلان فقط (منفصل + نهائي): ا، أ، إ، آ، ة، د، ذ، ر، ز، و، ى
    const twoFormFinals = <int>[
      0xFE82, 0xFE84, 0xFE88, 0xFE8E, 0xFE94,
      0xFEAA, 0xFEAC, 0xFEAE, 0xFEB0, 0xFEEE, 0xFEF0,
      0xFEF6, 0xFEF8, 0xFEFA, 0xFEFC,
    ];
    if (twoFormFinals.contains(code)) return 1;
    return 0;
  }

  /// يفحص الكلمات العربية بعد التطبيع لاكتشاف الانعكاس البصري (مثل: "ةحفص" بدل "صفحة" أو "ملاسلا" بدل "السلام").
  static int _scoreReversedArabicHeuristic(String line) {
    var reversedScore = 0;
    var logicalScore = 0;
    final words = line.trim().split(RegExp(r'\s+'));

    for (final rawWord in words) {
      final w = rawWord.replaceAll(
        RegExp(r'[^\u0621-\u064A]'),
        '',
      );
      if (w.length < 2) continue;

      // التاء المربوطة (ة) والألف المقصورة (ى) لا تأتيان في بداية الكلمة العربية أبداً
      if (w.startsWith('ة') || w.startsWith('ى')) {
        reversedScore += 3;
      }
      if (w.endsWith('ة') || w.endsWith('ى')) {
        logicalScore += 3;
      }
      // "ال" التعريف في بداية الكلمة مقابل "لا..." في نهاية الكلمة المعكوسة
      if (w.length >= 4 && w.startsWith('ال')) {
        logicalScore += 2;
      }
      if (w.length >= 4 &&
          w.endsWith('لا') &&
          w != 'إلا' &&
          w != 'ألا' &&
          w != 'كلا' &&
          w != 'بلا' &&
          w != 'حالا' &&
          w != 'فعلا' &&
          w != 'مثلا' &&
          w != 'أولا') {
        reversedScore += 2;
      }
      if (w == 'يف' || w == 'نم' || w == 'ىلع' || w == 'ىلإ' || w == 'نع' || w == 'مسب' || w == 'هللا') {
        reversedScore += 3;
      }
      if (w == 'في' || w == 'من' || w == 'على' || w == 'إلى' || w == 'عن' || w == 'بسم' || w == 'الله') {
        logicalScore += 3;
      }
    }
    return reversedScore - logicalScore;
  }

  /// يعكس السطر العربي المعكوس بصرياً مع الحفاظ على ترتيب الأرقام والكلمات الإنجليزية.
  static String _reverseVisualArabicLine(String line) {
    final reversedChars = line.runes.toList().reversed;
    final reversedString = String.fromCharCodes(reversedChars);
    // إعادة عكس الأرقام والكلمات اللاتينية حتى لا تنقلب (مثل 2026 أو PDF)
    return reversedString.replaceAllMapped(
      RegExp(r'[A-Za-z0-9]+(?:[./:-][A-Za-z0-9]+)*'),
      (m) => String.fromCharCodes(m.group(0)!.runes.toList().reversed),
    );
  }

  /// يحول رموز Arabic Presentation Forms (FE70..FEFC & FB50..FDFF) إلى حروف عربية قياسية (0600..06FF).
  static String _replaceArabicPresentationForms(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      switch (rune) {
        case 0xFEF5 || 0xFEF6:
          sb.write('لآ');
        case 0xFEF7 || 0xFEF8:
          sb.write('لأ');
        case 0xFEF9 || 0xFEFA:
          sb.write('لإ');
        case 0xFEFB || 0xFEFC:
          sb.write('لا');
        case 0xFDF2:
          sb.write('الله');
        default:
          final mapped = _presentationRuneToStandard[rune];
          if (mapped != null) {
            sb.writeCharCode(mapped);
          } else {
            sb.writeCharCode(rune);
          }
      }
    }
    return sb.toString();
  }

  static const Map<int, int> _presentationRuneToStandard = <int, int>{
    0xFE80: 0x0621, // ء
    0xFE81: 0x0622, 0xFE82: 0x0622, // آ
    0xFE83: 0x0623, 0xFE84: 0x0623, // أ
    0xFE85: 0x0624, 0xFE86: 0x0624, // ؤ
    0xFE87: 0x0625, 0xFE88: 0x0625, // إ
    0xFE89: 0x0626, 0xFE8A: 0x0626, 0xFE8B: 0x0626, 0xFE8C: 0x0626, // ئ
    0xFE8D: 0x0627, 0xFE8E: 0x0627, // ا
    0xFE8F: 0x0628, 0xFE90: 0x0628, 0xFE91: 0x0628, 0xFE92: 0x0628, // ب
    0xFE93: 0x0629, 0xFE94: 0x0629, // ة
    0xFE95: 0x062A, 0xFE96: 0x062A, 0xFE97: 0x062A, 0xFE98: 0x062A, // ت
    0xFE99: 0x062B, 0xFE9A: 0x062B, 0xFE9B: 0x062B, 0xFE9C: 0x062B, // ث
    0xFE9D: 0x062C, 0xFE9E: 0x062C, 0xFE9F: 0x062C, 0xFEA0: 0x062C, // ج
    0xFEA1: 0x062D, 0xFEA2: 0x062D, 0xFEA3: 0x062D, 0xFEA4: 0x062D, // ح
    0xFEA5: 0x062E, 0xFEA6: 0x062E, 0xFEA7: 0x062E, 0xFEA8: 0x062E, // خ
    0xFEA9: 0x062F, 0xFEAA: 0x062F, // د
    0xFEAB: 0x0630, 0xFEAC: 0x0630, // ذ
    0xFEAD: 0x0631, 0xFEAE: 0x0631, // ر
    0xFEAF: 0x0632, 0xFEB0: 0x0632, // ز
    0xFEB1: 0x0633, 0xFEB2: 0x0633, 0xFEB3: 0x0633, 0xFEB4: 0x0633, // س
    0xFEB5: 0x0634, 0xFEB6: 0x0634, 0xFEB7: 0x0634, 0xFEB8: 0x0634, // ش
    0xFEB9: 0x0635, 0xFEBA: 0x0635, 0xFEBB: 0x0635, 0xFEBC: 0x0635, // ص
    0xFEBD: 0x0636, 0xFEBE: 0x0636, 0xFEBF: 0x0636, 0xFEC0: 0x0636, // ض
    0xFEC1: 0x0637, 0xFEC2: 0x0637, 0xFEC3: 0x0637, 0xFEC4: 0x0637, // ط
    0xFEC5: 0x0638, 0xFEC6: 0x0638, 0xFEC7: 0x0638, 0xFEC8: 0x0638, // ظ
    0xFEC9: 0x0639, 0xFECA: 0x0639, 0xFECB: 0x0639, 0xFECC: 0x0639, // ع
    0xFECD: 0x063A, 0xFECE: 0x063A, 0xFECF: 0x063A, 0xFED0: 0x063A, // غ
    0xFED1: 0x0641, 0xFED2: 0x0641, 0xFED3: 0x0641, 0xFED4: 0x0641, // ف
    0xFED5: 0x0642, 0xFED6: 0x0642, 0xFED7: 0x0642, 0xFED8: 0x0642, // ق
    0xFED9: 0x0643, 0xFEDA: 0x0643, 0xFEDB: 0x0643, 0xFEDC: 0x0643, // ك
    0xFEDD: 0x0644, 0xFEDE: 0x0644, 0xFEDF: 0x0644, 0xFEE0: 0x0644, // ل
    0xFEE1: 0x0645, 0xFEE2: 0x0645, 0xFEE3: 0x0645, 0xFEE4: 0x0645, // م
    0xFEE5: 0x0646, 0xFEE6: 0x0646, 0xFEE7: 0x0646, 0xFEE8: 0x0646, // ن
    0xFEE9: 0x0647, 0xFEEA: 0x0647, 0xFEEB: 0x0647, 0xFEEC: 0x0647, // ه
    0xFEED: 0x0648, 0xFEEE: 0x0648, // و
    0xFEEF: 0x0649, 0xFEF0: 0x0649, // ى
    0xFEF1: 0x064A, 0xFEF2: 0x064A, 0xFEF3: 0x064A, 0xFEF4: 0x064A, // ي
  };

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
