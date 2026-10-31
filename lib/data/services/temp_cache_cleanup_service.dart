import 'platform_storage.dart';

/// خدمة تفريغ الملفات المؤقتة والكاش فور انتهاء كل عملية معالجة PDF.
class TempCacheCleanupService {
  const TempCacheCleanupService();

  /// يحذف الملفات المؤقتة التي تم إنشاؤها أثناء الفحص أو المسح الضوئي ويعيد عدد البايتات المحررة.
  Future<int> purgeTemporaryFiles({List<String> trackedPaths = const []}) {
    return PlatformStorage.purgeTemporaryFiles(trackedPaths: trackedPaths);
  }
}
