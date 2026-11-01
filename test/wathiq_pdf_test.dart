import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:wathiq_pdf/data/services/pdf_isolate_service.dart';
import 'package:wathiq_pdf/domain/models/compression_preset.dart';
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

  group('PdfIsolateService.compressPdf', () {
    test('يقلل حجم ملف PDF فعلياً عند الضغط', () async {
      final tempDir = await Directory.systemTemp.createTemp('wathiq_test_');
      try {
        final sampleImage = img.Image(width: 1600, height: 1600);
        for (var y = 0; y < 1600; y++) {
          for (var x = 0; x < 1600; x++) {
            sampleImage.setPixelRgb(
              x,
              y,
              (x * 17 + y * 3) & 0xFF,
              (x * 5 + y * 29) & 0xFF,
              (x * 11 + y * 7) & 0xFF,
            );
          }
        }
        final highQualityJpg = Uint8List.fromList(
          img.encodeJpg(sampleImage, quality: 98),
        );

        final srcDoc = PdfDocument();
        final page = srcDoc.pages.add();
        page.graphics.drawImage(
          PdfBitmap(highQualityJpg),
          const Rect.fromLTWH(0, 0, 500, 700),
        );
        final inputPath = '${tempDir.path}/input.pdf';
        final outputPath = '${tempDir.path}/compressed.pdf';
        File(inputPath).writeAsBytesSync(srcDoc.saveSync(), flush: true);
        srcDoc.dispose();

        const service = PdfIsolateService();
        final result = await service.compressPdf(
          inputPath: inputPath,
          outputPath: outputPath,
          level: CompressionLevel.medium,
        );

        expect(result.finalSizeBytes, lessThan(result.originalSizeBytes * 0.6));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
