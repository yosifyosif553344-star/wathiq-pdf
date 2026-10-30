/// خيارات أبعاد الورق عند تحويل الصور أو الماسح الضوئي إلى ملف PDF.
enum PdfPaperSize {
  a4(title: 'A4 قياسي (210 × 297 مم)'),
  originalImage(title: 'حجم الصورة الأصلي');

  const PdfPaperSize({required this.title});
  final String title;
}

/// خيارات هوامش الصفحة حول الصورة الممسوحة ضوئياً.
enum PdfPageMargin {
  none(title: 'بدون هوامش (0 مم)', points: 0),
  standard(title: 'هامش قياسي (12 مم)', points: 34),
  wide(title: 'هامش واسع (20 مم)', points: 56);

  const PdfPageMargin({required this.title, required this.points});
  final String title;
  final double points;
}

/// الفلاتر البصرية المطبقة على صور الدفاتر والوثائق قبل التصدير إلى PDF.
enum DocumentColorFilter {
  highContrastBw(title: 'أبيض وأسود للوثائق (تباين عالٍ)'),
  grayscale(title: 'تدرج رمادي هادئ'),
  originalColor(title: 'ملون أصلي');

  const DocumentColorFilter({required this.title});
  final String title;
}

/// إعدادات تحويل الصور والماسح الضوئي إلى وثيقة PDF.
class ScannerToPdfOptions {
  const ScannerToPdfOptions({
    this.paperSize = PdfPaperSize.a4,
    this.margin = PdfPageMargin.standard,
    this.colorFilter = DocumentColorFilter.highContrastBw,
    this.autoCropEdges = true,
  });

  final PdfPaperSize paperSize;
  final PdfPageMargin margin;
  final DocumentColorFilter colorFilter;
  final bool autoCropEdges;

  ScannerToPdfOptions copyWith({
    PdfPaperSize? paperSize,
    PdfPageMargin? margin,
    DocumentColorFilter? colorFilter,
    bool? autoCropEdges,
  }) {
    return ScannerToPdfOptions(
      paperSize: paperSize ?? this.paperSize,
      margin: margin ?? this.margin,
      colorFilter: colorFilter ?? this.colorFilter,
      autoCropEdges: autoCropEdges ?? this.autoCropEdges,
    );
  }
}
