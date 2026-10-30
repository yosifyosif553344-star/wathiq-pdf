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
  });

  final List<String> outputFilePaths;
  final int originalSizeBytes;
  final int finalSizeBytes;
  final int pageCount;
  final int durationMs;

  String get primaryPath => outputFilePaths.first;
}

/// خدمة معالجة الـ PDF داخل خيوط خلفية منفصلة (Dart Isolates) لضمان بقاء الواجهة بسرعة 60/120 إطاراً في الثانية.
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
          section.pageSettings.rotate = _mapRotationAngle(instruction.rotationDegrees);

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

  /// يضغط ملف PDF وفق المستوى المختار داخل Isolate ويعيد الحجم الدقيق قبل وبعد الضغط.
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

  /// يحول مجموعة صور من المعرض أو الماسح الضوئي إلى ملف PDF مع تطبيق القص والفلتر والهوامش داخل Isolate.
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
