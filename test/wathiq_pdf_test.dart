import 'package:flutter_test/flutter_test.dart';
import 'package:wathiq_pdf/domain/models/page_instruction.dart';
import 'package:wathiq_pdf/domain/models/pdf_operation_type.dart';
import 'package:wathiq_pdf/domain/models/processed_file_record.dart';
import 'package:wathiq_pdf/domain/use_cases/parse_page_range_use_case.dart';

void main() {
  group('ParsePageRangeUseCase', () {
    const parser = ParsePageRangeUseCase();

    test('يحلل الصفحات المفردة والنطاقات والأرقام العربية بشكل صحيح', () {
      final result = parser.execute(
        rawExpression: '١, 3-5, 8',
        totalPages: 10,
      );
      expect(result.isValid, isTrue);
      expect(result.pages, equals([1, 3, 4, 5, 8]));
    });

    test('يرفض النطاق الذي يتجاوز عدد صفحات الوثيقة', () {
      final result = parser.execute(
        rawExpression: '1-15',
        totalPages: 10,
      );
      expect(result.isValid, isFalse);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('ProcessedFileRecord', () {
    test('يحسب نسبة التوفير في الحجم عند الضغط بدقة', () {
      final record = ProcessedFileRecord(
        id: 'rec_1',
        fileName: 'عقد_مضغوط.pdf',
        filePath: '/storage/emulated/0/Documents/عقد_مضغوط.pdf',
        operationType: PdfOperationType.compress,
        originalSizeBytes: 15 * 1024 * 1024,
        finalSizeBytes: 3 * 1024 * 1024,
        pageCount: 24,
        processedAt: DateTime(2026, 10, 30),
        durationMs: 620,
      );

      expect(record.savedPercentage, equals(80));
      expect(record.formattedOriginalSize, equals('15.0 MB'));
      expect(record.formattedFinalSize, equals('3.0 MB'));
    });
  });

  group('PdfPageInstruction', () {
    test('يدور الصفحة بمضاعفات 90 و180 درجة مع التطبيع إلى 0..359', () {
      const page = PdfPageInstruction(originalPageNumber: 1);
      final rotated90 = page.rotateBy(90);
      expect(rotated90.rotationDegrees, equals(90));

      final rotated270 = rotated90.rotateBy(180);
      expect(rotated270.rotationDegrees, equals(270));

      final rotated360 = rotated270.rotateBy(90);
      expect(rotated360.rotationDegrees, equals(0));
    });
  });
}
