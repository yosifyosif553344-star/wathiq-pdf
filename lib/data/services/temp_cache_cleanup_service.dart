import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// خدمة تفريغ الملفات المؤقتة والكاش فور انتهاء كل عملية معالجة PDF.
class TempCacheCleanupService {
  const TempCacheCleanupService();

  /// يحذف الملفات المؤقتة التي تم إنشاؤها أثناء الفحص أو المسح الضوئي ويعيد عدد البايتات المحررة.
  Future<int> purgeTemporaryFiles({List<String> trackedPaths = const []}) async {
    var freedBytes = 0;

    for (final rawPath in trackedPaths) {
      if (rawPath.isEmpty) continue;
      final file = File(rawPath);
      if (await file.exists()) {
        try {
          freedBytes += await file.length();
          await file.delete();
        } on FileSystemException {
          // قد يكون الملف محذوفاً مسبقاً من نظام التشغيل.
        }
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: false)) {
          if (entity is File &&
              (entity.path.endsWith('.tmp') ||
                  entity.path.contains('wathiq_work_') ||
                  entity.path.contains('cunning_scanner'))) {
            try {
              freedBytes += await entity.length();
              await entity.delete();
            } on FileSystemException {
              // نتجاوز الملفات المقفلة من النظام.
            }
          }
        }
      }
    } on MissingPlatformDirectoryException {
      // في بيئة الاختبار قد لا يتوفر مجلد مؤقت للنظام.
    }

    return freedBytes;
  }
}
