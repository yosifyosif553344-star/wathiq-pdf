import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/processed_file_record.dart';

/// مستودع سجل العمليات الأخيرة المحفوظ محلياً داخل الجهاز.
class LocalHistoryRepository {
  LocalHistoryRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String _storageKey = 'wathiq_pdf_recent_history_v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPrefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// يسترجع قائمة العمليات الأخيرة مرتبة من الأحدث إلى الأقدم.
  Future<List<ProcessedFileRecord>> loadRecentRecords() async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_storageKey);
    if (rawList == null || rawList.isEmpty) {
      return const [];
    }

    final records = <ProcessedFileRecord>[];
    for (final item in rawList) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        records.add(ProcessedFileRecord.fromJson(decoded));
      } on FormatException {
        // تجاهل السجلات التالفة دون إيقاف التطبيق.
      }
    }

    records.sort((a, b) => b.processedAt.compareTo(a.processedAt));
    return records;
  }

  /// يضيف سجل عملية جديدة في أعلى القائمة المحلية.
  Future<List<ProcessedFileRecord>> addRecord(ProcessedFileRecord record) async {
    final current = await loadRecentRecords();
    final updated = [
      record,
      ...current.where((item) => item.id != record.id),
    ].take(50).toList();
    await _persist(updated);
    return updated;
  }

  /// يعيد تسمية الملف على ذاكرة الجهاز وفي سجل العمليات الأخيرة.
  Future<List<ProcessedFileRecord>> renameRecord({
    required String id,
    required String newFileName,
  }) async {
    final sanitized = newFileName.trim().endsWith('.pdf')
        ? newFileName.trim()
        : '${newFileName.trim()}.pdf';

    final current = await loadRecentRecords();
    final updated = <ProcessedFileRecord>[];

    for (final item in current) {
      if (item.id == id) {
        var targetPath = item.filePath;
        final existingFile = File(item.filePath);
        if (await existingFile.exists()) {
          final parentDir = existingFile.parent.path;
          final candidatePath = '$parentDir/$sanitized';
          try {
            final renamedFile = await existingFile.rename(candidatePath);
            targetPath = renamedFile.path;
          } on FileSystemException {
            // إذا تعذر نقل الملف الفعلي نحتفظ بالمسار مع تحديث الاسم المعروض.
          }
        }
        updated.add(item.copyWith(fileName: sanitized, filePath: targetPath));
      } else {
        updated.add(item);
      }
    }

    await _persist(updated);
    return updated;
  }

  /// يحذف السجل من القائمة مع خيار حذف الملف الفعلي من ذاكرة الجهاز.
  Future<List<ProcessedFileRecord>> deleteRecord({
    required String id,
    bool deleteFileFromDisk = false,
  }) async {
    final current = await loadRecentRecords();
    if (deleteFileFromDisk) {
      for (final item in current.where((e) => e.id == id)) {
        final file = File(item.filePath);
        if (await file.exists()) {
          try {
            await file.delete();
          } on FileSystemException {
            // تجاهل أخطاء الحذف إذا نُقل الملف خارجياً.
          }
        }
      }
    }

    final updated = current.where((item) => item.id != id).toList();
    await _persist(updated);
    return updated;
  }

  Future<void> _persist(List<ProcessedFileRecord> records) async {
    final prefs = await _getPrefs();
    final encoded = records.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }
}
