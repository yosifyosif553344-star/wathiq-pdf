/// حالة صفحة مفردة أثناء إعادة الترتيب أو الحذف أو التدوير.
class PdfPageInstruction {
  const PdfPageInstruction({
    required this.originalPageNumber,
    this.rotationDegrees = 0,
    this.isSelected = false,
  });

  /// رقم الصفحة الأصلي في الملف المصدر (يبدأ من 1).
  final int originalPageNumber;

  /// زاوية الدوران بالدرجات (0، 90، 180، 270).
  final int rotationDegrees;

  /// هل الصفحة محددة حالياً لتنفيذ إجراء جماعي (حذف أو تدوير).
  final bool isSelected;

  PdfPageInstruction rotateBy(int deltaDegrees) {
    final normalized = (rotationDegrees + deltaDegrees) % 360;
    return copyWith(rotationDegrees: normalized < 0 ? normalized + 360 : normalized);
  }

  PdfPageInstruction copyWith({
    int? originalPageNumber,
    int? rotationDegrees,
    bool? isSelected,
  }) {
    return PdfPageInstruction(
      originalPageNumber: originalPageNumber ?? this.originalPageNumber,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
