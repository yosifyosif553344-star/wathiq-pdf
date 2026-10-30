/// نتيجة تحليل نطاق الصفحات المدخل من المستخدم لتقسيم ملف PDF.
class PageRangeParseResult {
  const PageRangeParseResult._({
    required this.pages,
    this.errorMessage,
  });

  factory PageRangeParseResult.success(List<int> pages) {
    return PageRangeParseResult._(pages: pages);
  }

  factory PageRangeParseResult.failure(String message) {
    return PageRangeParseResult._(pages: const [], errorMessage: message);
  }

  final List<int> pages;
  final String? errorMessage;

  bool get isValid => errorMessage == null && pages.isNotEmpty;
}

/// يحلل تعبيرات الصفحات مثل "1, 5, 8" أو "1-10, 14" ويتحقق من وقوعها ضمن حدود الوثيقة.
class ParsePageRangeUseCase {
  const ParsePageRangeUseCase();

  PageRangeParseResult execute({
    required String rawExpression,
    required int totalPages,
  }) {
    final normalized = _normalizeArabicDigits(rawExpression).trim();
    if (normalized.isEmpty) {
      return PageRangeParseResult.failure(
        'أدخل أرقام الصفحات أو النطاق المطلوب استخراجه (مثال: 1-5, 8).',
      );
    }

    if (totalPages < 1) {
      return PageRangeParseResult.failure('الملف المختار لا يحتوي على صفحات صالحة.');
    }

    final result = <int>[];
    final seen = <int>{};
    final parts = normalized.split(RegExp(r'[,،\s]+'));

    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.contains('-')) {
        final bounds = part.split('-');
        if (bounds.length != 2) {
          return PageRangeParseResult.failure('صيغة النطاق "$part" غير صحيحة. استخدم الصيغة 1-5.');
        }
        final start = int.tryParse(bounds[0].trim());
        final end = int.tryParse(bounds[1].trim());
        if (start == null || end == null) {
          return PageRangeParseResult.failure('النطاق "$part" يجب أن يحتوي على أرقام صحيحة.');
        }
        if (start < 1 || end < 1 || start > totalPages || end > totalPages) {
          return PageRangeParseResult.failure(
            'النطاق "$part" يتجاوز عدد صفحات الوثيقة البالغ $totalPages صفحة.',
          );
        }
        final step = start <= end ? 1 : -1;
        for (var p = start; step > 0 ? p <= end : p >= end; p += step) {
          if (seen.add(p)) {
            result.add(p);
          }
        }
      } else {
        final page = int.tryParse(part.trim());
        if (page == null) {
          return PageRangeParseResult.failure('القيمة "$part" ليست رقم صفحة صالحاً.');
        }
        if (page < 1 || page > totalPages) {
          return PageRangeParseResult.failure(
            'الصفحة رقم $page خارج حدود الوثيقة (من 1 إلى $totalPages).',
          );
        }
        if (seen.add(page)) {
          result.add(page);
        }
      }
    }

    if (result.isEmpty) {
      return PageRangeParseResult.failure('لم يتم العثور على أي أرقام صفحات صالحة للاستخراج.');
    }

    return PageRangeParseResult.success(result);
  }

  String _normalizeArabicDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < arabicDigits.length; i++) {
      output = output.replaceAll(arabicDigits[i], i.toString());
    }
    return output;
  }
}
