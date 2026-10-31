import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/compression_preset.dart';
import '../../domain/models/page_instruction.dart';
import '../../domain/models/pdf_operation_type.dart';
import '../../domain/models/processed_file_record.dart';
import '../../domain/models/scanner_options.dart';
import '../services/pdf_isolate_service.dart';
import '../services/platform_storage.dart';
import '../services/temp_cache_cleanup_service.dart';
import 'local_history_repository.dart';

/// مستودع تنفيذ جميع عمليات الـ PDF المحلية مع تفريغ الكاش وتحديث السجل تلقائياً.
class PdfOperationsRepository {
  PdfOperationsRepository({
    required PdfIsolateService isolateService,
    required TempCacheCleanupService cacheCleanupService,
    required LocalHistoryRepository historyRepository,
  })  : _isolateService = isolateService,
        _cacheCleanupService = cacheCleanupService,
        _historyRepository = historyRepository;

  final PdfIsolateService _isolateService;
  final TempCacheCleanupService _cacheCleanupService;
  final LocalHistoryRepository _historyRepository;

  PdfIsolateService get isolateService => _isolateService;

  Future<String> _resolveOutputDirectory() {
    return PlatformStorage.resolveOutputDirPath();
  }

  Future<ProcessedFileRecord> _saveToHistory({
    required String fileName,
    required PdfOperationType operationType,
    required IsolatePdfOutput result,
  }) async {
    final record = ProcessedFileRecord(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      fileName: fileName,
      filePath: result.primaryPath,
      operationType: operationType,
      originalSizeBytes: result.originalSizeBytes,
      finalSizeBytes: result.finalSizeBytes,
      pageCount: result.pageCount,
      processedAt: DateTime.now(),
      durationMs: result.durationMs,
    );
    await _historyRepository.addRecord(record);
    return record;
  }

  Future<ProcessedFileRecord> mergeFiles({
    required List<String> inputPaths,
    required String desiredOutputName,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'مدمج');
      final result = await _isolateService.mergePdfs(
        inputPaths: inputPaths,
        outputPath: '${outDir}/$cleanName',
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.merge,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> splitFile({
    required String inputPath,
    required String desiredOutputName,
    required List<int> selectedPages,
    required bool burstEachPageIntoSeparateFile,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final baseName = _stripExtension(desiredOutputName, fallback: 'مقسم');
      final result = await _isolateService.splitPdf(
        inputPath: inputPath,
        outputDirectory: outDir,
        baseOutputFileName: baseName,
        oneBasedPages: selectedPages,
        burstEachPageIntoSeparateFile: burstEachPageIntoSeparateFile,
      );
      final displayFileName = burstEachPageIntoSeparateFile
          ? '${baseName}_(${result.outputFilePaths.length}_ملفات).pdf'
          : '$baseName.pdf';
      return _saveToHistory(
        fileName: displayFileName,
        operationType: PdfOperationType.split,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> organizeFilePages({
    required String inputPath,
    required String desiredOutputName,
    required List<PdfPageInstruction> instructions,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'منظم');
      final result = await _isolateService.organizePages(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        instructions: instructions,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.organize,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> rotateFile({
    required String inputPath,
    required String desiredOutputName,
    required int rotationDegrees,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'مدور');
      final result = await _isolateService.rotateAllPages(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        rotationDegrees: rotationDegrees,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.rotatePdf,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> compressFile({
    required String inputPath,
    required String desiredOutputName,
    required CompressionLevel level,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'مضغوط');
      final result = await _isolateService.compressPdf(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        level: level,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.compress,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> convertImagesToPdf({
    required List<String> imagePaths,
    required String desiredOutputName,
    required ScannerToPdfOptions options,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'صور_PDF');
      final result = await _isolateService.convertImagesToPdf(
        imagePaths: imagePaths,
        outputPath: '${outDir}/$cleanName',
        options: options,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.imagesToPdf,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles(trackedPaths: imagePaths);
    }
  }

  Future<ProcessedFileRecord> addPageNumbers({
    required String inputPath,
    required String desiredOutputName,
    required PageNumberPosition position,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'مرقم');
      final result = await _isolateService.addPageNumbers(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        position: position,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.pageNumbers,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> stampTextOrSignatureOnPdf({
    required String inputPath,
    required String desiredOutputName,
    required PdfOperationType operationType,
    required Uint8List overlayPngBytes,
    required double opacity,
    required bool allPages,
    required bool centerDiagonal,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'معدل');
      final result = await _isolateService.stampOverlayOnPdf(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        overlayPngBytes: overlayPngBytes,
        opacity: opacity,
        allPages: allPages,
        centerDiagonal: centerDiagonal,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: operationType,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> protectFile({
    required String inputPath,
    required String desiredOutputName,
    required String password,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'محمي');
      final result = await _isolateService.protectPdf(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        password: password,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.protectPdf,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> unlockFile({
    required String inputPath,
    required String desiredOutputName,
    required String password,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'مفتوح');
      final result = await _isolateService.unlockPdf(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
        password: password,
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.unlockPdf,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> repairFile({
    required String inputPath,
    required String desiredOutputName,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'مصلح');
      final result = await _isolateService.repairPdf(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.repairPdf,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> extractText({
    required String inputPath,
    required String desiredOutputName,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.txt', 'نص');
      final result = await _isolateService.extractPdfText(
        inputPath: inputPath,
        outputPath: '${outDir}/$cleanName',
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: PdfOperationType.extractText,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  Future<ProcessedFileRecord> createOrConvertTextToPdf({
    required String title,
    required String bodyText,
    required String desiredOutputName,
    required PdfOperationType operationType,
    int originalBytesHint = 0,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizeExt(desiredOutputName, '.pdf', 'جديد');
      final pageBitmaps = await _renderTextDocumentToPagePngs(
        title: title,
        bodyText: bodyText,
      );
      final result = await _isolateService.buildPdfFromRenderedPages(
        pagePngList: pageBitmaps,
        outputPath: '$outDir/$cleanName',
        originalBytesHint: originalBytesHint,
        embeddedPlainText: '$title\n\n$bodyText',
      );
      return _saveToHistory(
        fileName: cleanName,
        operationType: operationType,
        result: result,
      );
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles();
    }
  }

  /// يحول نصاً (عربياً أو إنجليزياً) أو مسار توقيع مرسوم إلى صورة PNG شفافة لطباعتها على الـ PDF.
  Future<Uint8List> renderOverlayPng({
    required String text,
    List<Offset?> signaturePoints = const [],
    bool diagonal = false,
  }) async {
    const width = 700.0;
    const height = 280.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    if (signaturePoints.isNotEmpty) {
      final paint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < signaturePoints.length - 1; i++) {
        final p1 = signaturePoints[i];
        final p2 = signaturePoints[i + 1];
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    } else {
      if (diagonal) {
        canvas.translate(width / 2, height / 2);
        canvas.rotate(-0.35);
        canvas.translate(-width / 2, -height / 2);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: text.trim().isEmpty ? 'وثيق PDF' : text,
          style: TextStyle(
            color: diagonal
                ? const Color(0xFF475569)
                : const Color(0xFF0F172A),
            fontSize: diagonal ? 54 : 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: width - 40);

      tp.paint(
        canvas,
        Offset((width - tp.width) / 2, (height - tp.height) / 2),
      );
    }

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<List<Uint8List>> _renderTextDocumentToPagePngs({
    required String title,
    required String bodyText,
  }) async {
    const pageW = 1190.0;
    const pageH = 1684.0;
    const margin = 90.0;

    final lines = bodyText.split('\n');
    final chunks = <String>[];
    final buf = StringBuffer();
    var lineCount = 0;

    for (final line in lines) {
      buf.writeln(line);
      lineCount++;
      if (lineCount >= 32) {
        chunks.add(buf.toString());
        buf.clear();
        lineCount = 0;
      }
    }
    if (buf.isNotEmpty || chunks.isEmpty) {
      chunks.add(buf.toString());
    }

    final result = <Uint8List>[];
    for (var i = 0; i < chunks.length; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, pageW, pageH));

      canvas.drawRect(
        const Rect.fromLTWH(0, 0, pageW, pageH),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      var yOffset = margin;
      if (i == 0 && title.trim().isNotEmpty) {
        final titlePainter = TextPainter(
          text: TextSpan(
            text: title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 38,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: pageW - (margin * 2));
        titlePainter.paint(
          canvas,
          Offset(pageW - margin - titlePainter.width, yOffset),
        );
        yOffset += titlePainter.height + 36;
      }

      final bodyPainter = TextPainter(
        text: TextSpan(
          text: chunks[i],
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 24,
            height: 1.6,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: pageW - (margin * 2));

      bodyPainter.paint(
        canvas,
        Offset(pageW - margin - bodyPainter.width, yOffset),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(pageW.toInt(), pageH.toInt());
      final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      result.add(pngBytes!.buffer.asUint8List());
    }
    return result;
  }

  String _sanitizeExt(String input, String ext, String fallback) {
    final base = _stripExtension(input, fallback: fallback);
    return '$base$ext';
  }

  String _stripExtension(String input, {required String fallback}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return fallback;
    final dotIdx = trimmed.lastIndexOf('.');
    if (dotIdx > 0) {
      return trimmed.substring(0, dotIdx);
    }
    return trimmed;
  }
}
