import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../core/theme/wathiq_theme.dart';

/// نافذة شاشة النتيجة الفورية (الخطوة 3 من رحلة المستخدم) مع زر مشاركة بارز وزر فتح الملف.
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

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Dialog(
        backgroundColor: palette.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: palette.accent, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.canvasBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.accent, width: 1),
                      ),
                      child: Icon(
                        Icons.verified_outlined,
                        color: palette.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اكتملت المعالجة المحلية بنجاح',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            'الزمن المستغرق: ${record.durationMs} ملي ثانية • على معالج الجهاز',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق نافذة النتيجة (Escape)',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: palette.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.canvasBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.structuralBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fileName,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'العملية: ${record.operationType.arabicTitle} • عدد الصفحات: ${record.pageCount}',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isCompress && record.savedPercentage > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'قبل الضغط: ${record.formattedOriginalSize}',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                color: palette.textSecondary,
                              ),
                            ),
                            Text(
                              'بعد الضغط: ${record.formattedFinalSize}',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: palette.accent),
                          ),
                          child: Text(
                            'تم تقليص الحجم بنسبة ${record.savedPercentage}%',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.accent,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'الحجم النهائي: ${record.formattedFinalSize}',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.accent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.memory_outlined,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'تم تفريغ الكاش والملفات المؤقتة تلقائياً (0 KB Temp)',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                fontSize: 11,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onShareFile,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: const Text('مشاركة الملف مباشرة'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  label: const Text('فتح ومعاينة الملف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
