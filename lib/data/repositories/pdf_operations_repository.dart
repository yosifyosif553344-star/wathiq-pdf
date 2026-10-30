import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/compression_preset.dart';
import '../../domain/models/page_instruction.dart';
import '../../domain/models/pdf_operation_type.dart';
import '../../domain/models/processed_file_record.dart';
import '../../domain/models/scanner_options.dart';
import '../services/pdf_isolate_service.dart';
import '../services/temp_cache_cleanup_service.dart';
import 'local_history_repository.dart';

/// مستودع تنفيذ عمليات الـ PDF المحلية مع ضمان تفريغ الكاش وتحديث السجل تلقائياً.
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

  Future<Directory> _resolveOutputDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final wathiqDir = Directory('${docsDir.path}/Wathiq_PDF');
    if (!await wathiqDir.exists()) {
      await wathiqDir.create(recursive: true);
    }
    return wathiqDir;
  }

  Future<ProcessedFileRecord> mergeFiles({
    required List<String> inputPaths,
    required String desiredOutputName,
  }) async {
    try {
      final outDir = await _resolveOutputDirectory();
      final cleanName = _sanitizePdfName(desiredOutputName, fallback: 'وثيقة_مدمجة');
      final outputPath = '${outDir.path}/$cleanName';

      final result = await _isolateService.mergePdfs(
        inputPaths: inputPaths,
        outputPath: outputPath,
      );

      final record = ProcessedFileRecord(
        id: 'op_${DateTime.now().microsecondsSinceEpoch}',
        fileName: cleanName,
        filePath: result.primaryPath,
        operationType: PdfOperationType.merge,
        originalSizeBytes: result.originalSizeBytes,
        finalSizeBytes: result.finalSizeBytes,
        pageCount: result.pageCount,
        processedAt: DateTime.now(),
        durationMs: result.durationMs,
      );

      await _historyRepository.addRecord(record);
      return record;
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
      final baseName = _stripPdfExtension(desiredOutputName);

      final result = await _isolateService.splitPdf(
        inputPath: inputPath,
        outputDirectory: outDir.path,
        baseOutputFileName: baseName,
        oneBasedPages: selectedPages,
        burstEachPageIntoSeparateFile: burstEachPageIntoSeparateFile,
      );

      final displayFileName = burstEachPageIntoSeparateFile
          ? '${baseName}_(${result.outputFilePaths.length}_ملفات_مستقلة).pdf'
          : '$baseName.pdf';

      final record = ProcessedFileRecord(
        id: 'op_${DateTime.now().microsecondsSinceEpoch}',
        fileName: displayFileName,
        filePath: result.primaryPath,
        operationType: PdfOperationType.split,
        originalSizeBytes: result.originalSizeBytes,
        finalSizeBytes: result.finalSizeBytes,
        pageCount: result.pageCount,
        processedAt: DateTime.now(),
        durationMs: result.durationMs,
      );

      await _historyRepository.addRecord(record);
      return record;
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
      final cleanName = _sanitizePdfName(desiredOutputName, fallback: 'وثيقة_منظمة');
      final outputPath = '${outDir.path}/$cleanName';

      final result = await _isolateService.organizePages(
        inputPath: inputPath,
        outputPath: outputPath,
        instructions: instructions,
      );

      final record = ProcessedFileRecord(
        id: 'op_${DateTime.now().microsecondsSinceEpoch}',
        fileName: cleanName,
        filePath: result.primaryPath,
        operationType: PdfOperationType.organize,
        originalSizeBytes: result.originalSizeBytes,
        finalSizeBytes: result.finalSizeBytes,
        pageCount: result.pageCount,
        processedAt: DateTime.now(),
        durationMs: result.durationMs,
      );

      await _historyRepository.addRecord(record);
      return record;
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
      final cleanName = _sanitizePdfName(desiredOutputName, fallback: 'وثيقة_مضغوطة');
      final outputPath = '${outDir.path}/$cleanName';

      final result = await _isolateService.compressPdf(
        inputPath: inputPath,
        outputPath: outputPath,
        level: level,
      );

      final record = ProcessedFileRecord(
        id: 'op_${DateTime.now().microsecondsSinceEpoch}',
        fileName: cleanName,
        filePath: result.primaryPath,
        operationType: PdfOperationType.compress,
        originalSizeBytes: result.originalSizeBytes,
        finalSizeBytes: result.finalSizeBytes,
        pageCount: result.pageCount,
        processedAt: DateTime.now(),
        durationMs: result.durationMs,
      );

      await _historyRepository.addRecord(record);
      return record;
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
      final cleanName = _sanitizePdfName(desiredOutputName, fallback: 'مسح_ضوئي');
      final outputPath = '${outDir.path}/$cleanName';

      final result = await _isolateService.convertImagesToPdf(
        imagePaths: imagePaths,
        outputPath: outputPath,
        options: options,
      );

      final record = ProcessedFileRecord(
        id: 'op_${DateTime.now().microsecondsSinceEpoch}',
        fileName: cleanName,
        filePath: result.primaryPath,
        operationType: PdfOperationType.imagesToPdf,
        originalSizeBytes: result.originalSizeBytes,
        finalSizeBytes: result.finalSizeBytes,
        pageCount: result.pageCount,
        processedAt: DateTime.now(),
        durationMs: result.durationMs,
      );

      await _historyRepository.addRecord(record);
      return record;
    } finally {
      await _cacheCleanupService.purgeTemporaryFiles(trackedPaths: imagePaths);
    }
  }

  String _sanitizePdfName(String input, {required String fallback}) {
    final trimmed = input.trim();
    final base = trimmed.isEmpty ? fallback : trimmed;
    return base.toLowerCase().endsWith('.pdf') ? base : '$base.pdf';
  }

  String _stripPdfExtension(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'وثيقة_مقسمة';
    if (trimmed.toLowerCase().endsWith('.pdf')) {
      return trimmed.substring(0, trimmed.length - 4);
    }
    return trimmed;
  }
}
