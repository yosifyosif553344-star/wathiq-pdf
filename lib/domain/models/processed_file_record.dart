import 'pdf_operation_type.dart';

/// سجل عملية معالجة محفوظة محلياً في جهاز المستخدم.
class ProcessedFileRecord {
  const ProcessedFileRecord({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.operationType,
    required this.originalSizeBytes,
    required this.finalSizeBytes,
    required this.pageCount,
    required this.processedAt,
    required this.durationMs,
    this.tempCacheCleared = true,
  });

  final String id;
  final String fileName;
  final String filePath;
  final PdfOperationType operationType;
  final int originalSizeBytes;
  final int finalSizeBytes;
  final int pageCount;
  final DateTime processedAt;
  final int durationMs;
  final bool tempCacheCleared;

  /// نسبة التوفير في الحجم عند تنفيذ عملية ضغط.
  int get savedPercentage {
    if (originalSizeBytes <= 0 || finalSizeBytes >= originalSizeBytes) {
      return 0;
    }
    final ratio = 1.0 - (finalSizeBytes / originalSizeBytes);
    return (ratio * 100).round().clamp(0, 99);
  }

  String get formattedOriginalSize => formatBytes(originalSizeBytes);
  String get formattedFinalSize => formatBytes(finalSizeBytes);

  String get sizeComparisonLabel {
    if (operationType == PdfOperationType.compress && savedPercentage > 0) {
      return '$formattedOriginalSize -> $formattedFinalSize (وفر $savedPercentage%)';
    }
    return formattedFinalSize;
  }

  ProcessedFileRecord copyWith({
    String? fileName,
    String? filePath,
  }) {
    return ProcessedFileRecord(
      id: id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      operationType: operationType,
      originalSizeBytes: originalSizeBytes,
      finalSizeBytes: finalSizeBytes,
      pageCount: pageCount,
      processedAt: processedAt,
      durationMs: durationMs,
      tempCacheCleared: tempCacheCleared,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'operationType': operationType.id,
      'originalSizeBytes': originalSizeBytes,
      'finalSizeBytes': finalSizeBytes,
      'pageCount': pageCount,
      'processedAt': processedAt.toIso8601String(),
      'durationMs': durationMs,
      'tempCacheCleared': tempCacheCleared,
    };
  }

  factory ProcessedFileRecord.fromJson(Map<String, dynamic> json) {
    return ProcessedFileRecord(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      operationType: PdfOperationType.fromId(json['operationType'] as String? ?? 'merge'),
      originalSizeBytes: (json['originalSizeBytes'] as num?)?.toInt() ?? 0,
      finalSizeBytes: (json['finalSizeBytes'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
      processedAt: DateTime.tryParse(json['processedAt'] as String? ?? '') ?? DateTime.now(),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 450,
      tempCacheCleared: json['tempCacheCleared'] as bool? ?? true,
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }
}
