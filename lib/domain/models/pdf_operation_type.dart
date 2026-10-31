/// نوع المدخلات المطلوبة لكل أداة.
enum PdfOperationInputKind {
  multiplePdfs,
  singlePdf,
  images,
  none,
}

/// تصنيف الأدوات في الشاشة الرئيسية.
enum PdfToolCategory {
  organize('تنظيم'),
  edit('تحرير'),
  create('إنشاء وتحويل'),
  security('حماية');

  const PdfToolCategory(this.title);
  final String title;
}

/// أدوات الـ PDF المدعومة محلياً على الجهاز.
enum PdfOperationType {
  merge(
    id: 'merge',
    arabicTitle: 'دمج',
    shortActionLabel: 'دمج PDF',
    description: 'اجمع عدة ملفات في ملف واحد',
    inputKind: PdfOperationInputKind.multiplePdfs,
    category: PdfToolCategory.organize,
  ),
  split(
    id: 'split',
    arabicTitle: 'تقسيم',
    shortActionLabel: 'تقسيم PDF',
    description: 'استخرج صفحات أو افصل كل صفحة',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.organize,
  ),
  compress(
    id: 'compress',
    arabicTitle: 'ضغط',
    shortActionLabel: 'ضغط PDF',
    description: 'صغّر حجم الملف',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.organize,
  ),
  organize(
    id: 'organize',
    arabicTitle: 'ترتيب الصفحات',
    shortActionLabel: 'تنظيم PDF',
    description: 'رتّب واحذف ودوّر الصفحات',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.organize,
  ),
  rotatePdf(
    id: 'rotate_pdf',
    arabicTitle: 'تدوير',
    shortActionLabel: 'تدوير PDF',
    description: 'دوّر كل الصفحات',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.organize,
  ),
  signPdf(
    id: 'sign_pdf',
    arabicTitle: 'توقيع',
    shortActionLabel: 'توقيع PDF',
    description: 'ارسم توقيعك وضعه على الملف',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.edit,
  ),
  editPdf(
    id: 'edit_pdf',
    arabicTitle: 'إضافة نص',
    shortActionLabel: 'تعديل PDF',
    description: 'اكتب نصاً على الصفحة الأخيرة',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.edit,
  ),
  watermark(
    id: 'watermark',
    arabicTitle: 'علامة مائية',
    shortActionLabel: 'علامة مائية',
    description: 'نص شفاف على كل الصفحات',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.edit,
  ),
  pageNumbers(
    id: 'page_numbers',
    arabicTitle: 'ترقيم الصفحات',
    shortActionLabel: 'ترقيم الصفحات',
    description: 'أضف أرقام الصفحات',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.edit,
  ),
  imagesToPdf(
    id: 'images_to_pdf',
    arabicTitle: 'صور إلى PDF',
    shortActionLabel: 'صور إلى PDF',
    description: 'من المعرض أو الكاميرا',
    inputKind: PdfOperationInputKind.images,
    category: PdfToolCategory.create,
  ),
  createPdf(
    id: 'create_pdf',
    arabicTitle: 'ملف جديد',
    shortActionLabel: 'إنشاء PDF',
    description: 'اكتب نصاً واحفظه PDF',
    inputKind: PdfOperationInputKind.none,
    category: PdfToolCategory.create,
  ),
  extractText(
    id: 'extract_text',
    arabicTitle: 'استخراج النص',
    shortActionLabel: 'استخراج النص',
    description: 'احفظ نص الملف كملف TXT',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.create,
  ),
  protectPdf(
    id: 'protect_pdf',
    arabicTitle: 'قفل بكلمة مرور',
    shortActionLabel: 'حماية PDF',
    description: 'امنع فتح الملف بدون كلمة مرور',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.security,
  ),
  unlockPdf(
    id: 'unlock_pdf',
    arabicTitle: 'فك القفل',
    shortActionLabel: 'فك قفل PDF',
    description: 'أزل كلمة المرور من ملفك',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.security,
  ),
  repairPdf(
    id: 'repair_pdf',
    arabicTitle: 'إصلاح',
    shortActionLabel: 'إصلاح PDF',
    description: 'أعد بناء ملف لا يفتح بشكل صحيح',
    inputKind: PdfOperationInputKind.singlePdf,
    category: PdfToolCategory.security,
  );

  const PdfOperationType({
    required this.id,
    required this.arabicTitle,
    required this.shortActionLabel,
    required this.description,
    required this.inputKind,
    required this.category,
  });

  final String id;
  final String arabicTitle;
  final String shortActionLabel;
  final String description;
  final PdfOperationInputKind inputKind;
  final PdfToolCategory category;

  static PdfOperationType fromId(String value) {
    for (final item in PdfOperationType.values) {
      if (item.id == value) return item;
    }
    return PdfOperationType.merge;
  }
}
