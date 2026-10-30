/// أنواع عمليات معالجة الـ PDF الأساسية المدعومة محلياً على الجهاز.
enum PdfOperationType {
  merge(
    id: 'merge',
    arabicTitle: 'دمج الملفات',
    englishCode: 'MERGE_PDF',
    shortActionLabel: 'دمج الملفات',
    description: 'جمع ملفين أو أكثر بترتيب مخصص في وثيقة PDF موحدة بجودتها الأصلية.',
  ),
  compress(
    id: 'compress',
    arabicTitle: 'ضغط حجم الملف',
    englishCode: 'COMPRESS_PDF',
    shortActionLabel: 'ضغط الملف',
    description: 'تقليص حجم الصور والجداول الداخلية بـ 3 مستويات مع عرض الحجم قبل وبعد.',
  ),
  split(
    id: 'split',
    arabicTitle: 'تقسيم واستخراج الصفحات',
    englishCode: 'SPLIT_PDF',
    shortActionLabel: 'تقسيم الملف',
    description: 'استخراج صفحات محددة أو نطاق صفحات في ملف جديد، أو فصل كل صفحة على حدة.',
  ),
  organize(
    id: 'organize',
    arabicTitle: 'ترتيب وحذف وتدوير الصفحات',
    englishCode: 'ORGANIZE_PDF',
    shortActionLabel: 'تنظيم الصفحات',
    description: 'معاينة مصغرات الصفحات وإعادة ترتيبها بالسحب أو تدويرها 90°/180° أو حذفها.',
  ),
  imagesToPdf(
    id: 'images_to_pdf',
    arabicTitle: 'تحويل الصور والكاميرا إلى PDF',
    englishCode: 'SCAN_TO_PDF',
    shortActionLabel: 'تحويل صور',
    description: 'استيراد صور المعرض أو المسح بالكاميرا مع قص الحواف وفلاتر المستندات وحجم A4.',
  );

  const PdfOperationType({
    required this.id,
    required this.arabicTitle,
    required this.englishCode,
    required this.shortActionLabel,
    required this.description,
  });

  final String id;
  final String arabicTitle;
  final String englishCode;
  final String shortActionLabel;
  final String description;

  static PdfOperationType fromId(String value) {
    for (final item in PdfOperationType.values) {
      if (item.id == value) return item;
    }
    return PdfOperationType.merge;
  }
}
