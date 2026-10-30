import 'package:flutter/material.dart';

import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../core/theme/wathiq_theme.dart';

/// نافذة النتيجة: اسم الملف + الحجم + مشاركة / فتح.
class ResultSheetDialog extends StatelessWidget {
  const ResultSheetDialog({
    super.key,
    required this.record,
    required this.onOpenFile,
    required this.onShareFile,
  });

  final ProcessedFileRecord record;
  final VoidCallback onOpenFile;
  final VoidCallback onShareFile;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final isCompress = record.operationType == PdfOperationType.compress;
    final sizeText = isCompress && record.savedPercentage > 0
        ? '${record.formattedOriginalSize} ← ${record.formattedFinalSize} (-${record.savedPercentage}%)'
        : record.formattedFinalSize;

    return Dialog(
      backgroundColor: palette.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle_outline, size: 44, color: palette.accent),
            const SizedBox(height: 10),
            Text(
              'تم بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              record.fileName,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              sizeText,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onShareFile,
              icon: const Icon(Icons.share_outlined),
              label: const Text('مشاركة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenFile,
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح'),
            ),
          ],
        ),
      ),
    );
  }
}
