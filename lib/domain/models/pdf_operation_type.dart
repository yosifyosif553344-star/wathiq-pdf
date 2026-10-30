/// أنواع عمليات معالجة الـ PDF والأوفيس والصور المدعومة محلياً بالكامل على الجهاز.
enum PdfOperationInputKind {
  multiplePdfs,
  singlePdf,
  officeDocument,
  images,
  none,
}

enum PdfOperationType {
  compress(
    id: 'compress',
    arabicTitle: 'ضغط PDF',
    englishCode: 'COMPRESS_PDF',
    shortActionLabel: 'ضغط PDF',
    description: 'تقليص حجم ملف الـ PDF بـ 3 مستويات.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  split(
    id: 'split',
    arabicTitle: 'تقسيم PDF',
    englishCode: 'SPLIT_PDF',
    shortActionLabel: 'تقسيم PDF',
    description: 'استخراج صفحات محددة أو فصل كل صفحة في ملف مستقل.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  merge(
    id: 'merge',
    arabicTitle: 'دمج ملفات PDF',
    englishCode: 'MERGE_PDF',
    shortActionLabel: 'دمج PDF',
    description: 'جمع ملفين أو أكثر في ملف PDF موحد.',
    inputKind: PdfOperationInputKind.multiplePdfs,
  ),
  pdfToWord(
    id: 'pdf_to_word',
    arabicTitle: 'PDF إلى وورد',
    englishCode: 'PDF_TO_WORD',
    shortActionLabel: 'PDF إلى وورد',
    description: 'تحويل ملف PDF إلى مستند وورد قابل للتعديل (.doc).',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  pdfToPowerPoint(
    id: 'pdf_to_powerpoint',
    arabicTitle: 'PDF إلى بوربوينت',
    englishCode: 'PDF_TO_PPT',
    shortActionLabel: 'PDF إلى بوربوينت',
    description: 'تحويل صفحات الـ PDF إلى شرائح عرض (.ppt).',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  pdfToExcel(
    id: 'pdf_to_excel',
    arabicTitle: 'PDF إلى إكسيل',
    englishCode: 'PDF_TO_EXCEL',
    shortActionLabel: 'PDF إلى إكسيل',
    description: 'استخراج البيانات والجداول إلى ملف جدول بيانات (.csv / .xls).',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  wordToPdf(
    id: 'word_to_pdf',
    arabicTitle: 'وورد إلى PDF',
    englishCode: 'WORD_TO_PDF',
    shortActionLabel: 'وورد إلى PDF',
    description: 'تحويل مستندات وورد والنصوص إلى ملف PDF.',
    inputKind: PdfOperationInputKind.officeDocument,
  ),
  powerPointToPdf(
    id: 'powerpoint_to_pdf',
    arabicTitle: 'بوربوينت إلى PDF',
    englishCode: 'PPT_TO_PDF',
    shortActionLabel: 'بوربوينت إلى PDF',
    description: 'تحويل العروض التقديمية إلى ملف PDF.',
    inputKind: PdfOperationInputKind.officeDocument,
  ),
  excelToPdf(
    id: 'excel_to_pdf',
    arabicTitle: 'إكسل إلى PDF',
    englishCode: 'EXCEL_TO_PDF',
    shortActionLabel: 'إكسل إلى PDF',
    description: 'تحويل جداول البيانات إلى ملف PDF.',
    inputKind: PdfOperationInputKind.officeDocument,
  ),
  editPdf(
    id: 'edit_pdf',
    arabicTitle: 'تعديل ملف PDF',
    englishCode: 'EDIT_PDF',
    shortActionLabel: 'تعديل PDF',
    description: 'إضافة نصوص وملاحظات مباشرة على صفحات الـ PDF.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  pdfToJpg(
    id: 'pdf_to_jpg',
    arabicTitle: 'PDF إلى JPG',
    englishCode: 'PDF_TO_JPG',
    shortActionLabel: 'PDF إلى JPG',
    description: 'استخراج صفحات الـ PDF كصور JPG عالية الدقة.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  imagesToPdf(
    id: 'images_to_pdf',
    arabicTitle: 'صورة إلى PDF',
    englishCode: 'SCAN_TO_PDF',
    shortActionLabel: 'صورة إلى PDF',
    description: 'تحويل الصور والكاميرا إلى ملف PDF.',
    inputKind: PdfOperationInputKind.images,
  ),
  pageNumbers(
    id: 'page_numbers',
    arabicTitle: 'ترقيم الصفحات',
    englishCode: 'PAGE_NUMBERS',
    shortActionLabel: 'ترقيم الصفحات',
    description: 'إضافة أرقام الصفحات في أعلى أو أسفل الوثيقة.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  watermark(
    id: 'watermark',
    arabicTitle: 'العلامة المائية',
    englishCode: 'WATERMARK_PDF',
    shortActionLabel: 'علامة مائية',
    description: 'إضافة علامة مائية نصية مخصصة على جميع الصفحات.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  rotatePdf(
    id: 'rotate_pdf',
    arabicTitle: 'تدوير ملفات PDF',
    englishCode: 'ROTATE_PDF',
    shortActionLabel: 'تدوير PDF',
    description: 'تدوير جميع صفحات الملف بزاوية 90° أو 180° أو 270°.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  unlockPdf(
    id: 'unlock_pdf',
    arabicTitle: 'فتح قفل ملفات PDF',
    englishCode: 'UNLOCK_PDF',
    shortActionLabel: 'فتح قفل PDF',
    description: 'إزالة كلمة المرور وفك تشفير ملف الـ PDF.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  protectPdf(
    id: 'protect_pdf',
    arabicTitle: 'حماية ملف PDF',
    englishCode: 'PROTECT_PDF',
    shortActionLabel: 'حماية PDF',
    description: 'تشفير وقفل ملف الـ PDF بكلمة مرور سرية.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  organize(
    id: 'organize',
    arabicTitle: 'تنظيم ملف PDF',
    englishCode: 'ORGANIZE_PDF',
    shortActionLabel: 'تنظيم PDF',
    description: 'ترتيب وحذف وتدوير صفحات الملف.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  repairPdf(
    id: 'repair_pdf',
    arabicTitle: 'إصلاح مستند PDF',
    englishCode: 'REPAIR_PDF',
    shortActionLabel: 'إصلاح PDF',
    description: 'إعادة بناء هيكل ملف الـ PDF وإصلاح الصفحات التالفة.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  signPdf(
    id: 'sign_pdf',
    arabicTitle: 'توقيع مستند PDF',
    englishCode: 'SIGN_PDF',
    shortActionLabel: 'توقيع PDF',
    description: 'رسم التوقيع باليد أو كتابته وإدراجه في الوثيقة.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  extractText(
    id: 'extract_text',
    arabicTitle: 'استخراج النصوص',
    englishCode: 'EXTRACT_TEXT',
    shortActionLabel: 'استخراج النص',
    description: 'استخراج كافة النصوص من ملف الـ PDF إلى ملف نصي.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  ocrPdf(
    id: 'ocr_pdf',
    arabicTitle: 'OCR PDF',
    englishCode: 'OCR_PDF',
    shortActionLabel: 'OCR PDF',
    description: 'التعرف على النصوص وإعادة بناء PDF قابل للبحث والنسخ.',
    inputKind: PdfOperationInputKind.singlePdf,
  ),
  createPdf(
    id: 'create_pdf',
    arabicTitle: 'إنشاء ملف PDF',
    englishCode: 'CREATE_PDF',
    shortActionLabel: 'إنشاء PDF',
    description: 'إنشاء مستند PDF جديد مباشرة من عنوان ومحتوى نصي.',
    inputKind: PdfOperationInputKind.none,
  ),
  compressImage(
    id: 'compress_image',
    arabicTitle: 'ضغط الصورة',
    englishCode: 'COMPRESS_IMG',
    shortActionLabel: 'ضغط الصورة',
    description: 'تقليص حجم الصور مع الحفاظ على وضوحها.',
    inputKind: PdfOperationInputKind.images,
  ),
  convertToJpg(
    id: 'convert_to_jpg',
    arabicTitle: 'التحويل إلى JPG',
    englishCode: 'TO_JPG',
    shortActionLabel: 'إلى JPG',
    description: 'تحويل صور PNG أو WebP إلى صيغة JPG.',
    inputKind: PdfOperationInputKind.images,
  ),
  convertFromJpg(
    id: 'convert_from_jpg',
    arabicTitle: 'التحويل من JPG',
    englishCode: 'FROM_JPG',
    shortActionLabel: 'من JPG إلى PNG',
    description: 'تحويل صور JPG إلى صيغة PNG عالية الدقة.',
    inputKind: PdfOperationInputKind.images,
  );

  const PdfOperationType({
    required this.id,
    required this.arabicTitle,
    required this.englishCode,
    required this.shortActionLabel,
    required this.description,
    required this.inputKind,
  });

  final String id;
  final String arabicTitle;
  final String englishCode;
  final String shortActionLabel;
  final String description;
  final PdfOperationInputKind inputKind;

  List<String> get allowedOfficeExtensions => switch (this) {
        PdfOperationType.wordToPdf => const ['docx', 'doc', 'txt', 'rtf'],
        PdfOperationType.powerPointToPdf => const ['pptx', 'ppt', 'txt'],
        PdfOperationType.excelToPdf => const ['xlsx', 'xls', 'csv', 'txt'],
        _ => const ['pdf'],
      };

  static PdfOperationType fromId(String value) {
    for (final item in PdfOperationType.values) {
      if (item.id == value) return item;
    }
    return PdfOperationType.merge;
  }
}
