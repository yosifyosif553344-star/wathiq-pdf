import 'package:flutter/material.dart';

import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../core/theme/wathiq_theme.dart';
import '../../../core/widgets/wathiq_shield_logo.dart';
import '../view_models/wathiq_workspace_view_model.dart';
import 'tool_workspace_screen.dart';

/// الشاشة الرئيسية: قائمة بسيطة بجميع الأدوات (26 أداة) + آخر الملفات.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  static const _icons = <PdfOperationType, IconData>{
    PdfOperationType.compress: Icons.compress_outlined,
    PdfOperationType.split: Icons.call_split_outlined,
    PdfOperationType.merge: Icons.merge_type_outlined,
    PdfOperationType.pdfToWord: Icons.article_outlined,
    PdfOperationType.pdfToPowerPoint: Icons.slideshow_outlined,
    PdfOperationType.pdfToExcel: Icons.table_chart_outlined,
    PdfOperationType.wordToPdf: Icons.description_outlined,
    PdfOperationType.powerPointToPdf: Icons.present_to_all_outlined,
    PdfOperationType.excelToPdf: Icons.grid_on_outlined,
    PdfOperationType.editPdf: Icons.edit_note_outlined,
    PdfOperationType.pdfToJpg: Icons.image_outlined,
    PdfOperationType.imagesToPdf: Icons.photo_camera_outlined,
    PdfOperationType.pageNumbers: Icons.format_list_numbered_rtl,
    PdfOperationType.watermark: Icons.branding_watermark_outlined,
    PdfOperationType.rotatePdf: Icons.rotate_right_outlined,
    PdfOperationType.unlockPdf: Icons.lock_open_outlined,
    PdfOperationType.protectPdf: Icons.lock_outline,
    PdfOperationType.organize: Icons.grid_view_outlined,
    PdfOperationType.repairPdf: Icons.build_outlined,
    PdfOperationType.signPdf: Icons.draw_outlined,
    PdfOperationType.extractText: Icons.text_snippet_outlined,
    PdfOperationType.ocrPdf: Icons.document_scanner_outlined,
    PdfOperationType.createPdf: Icons.note_add_outlined,
    PdfOperationType.compressImage: Icons.photo_size_select_small_outlined,
    PdfOperationType.convertToJpg: Icons.transform_outlined,
    PdfOperationType.convertFromJpg: Icons.collections_outlined,
  };

  void _open(BuildContext context, PdfOperationType tool) {
    viewModel.selectOperation(tool);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToolWorkspaceScreen(viewModel: viewModel),
      ),
    );
  }

  Future<void> _rename(BuildContext context, ProcessedFileRecord record) async {
    final controller = TextEditingController(text: record.fileName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تسمية'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await viewModel.renameProcessedFile(id: record.id, newName: newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final palette = WathiqPalette.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const WathiqShieldLogo(size: 30),
                const SizedBox(width: 10),
                Text(
                  'وثيق PDF',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'تبديل الوضع',
                onPressed: viewModel.toggleThemeMode,
                icon: Icon(
                  palette.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final tool in PdfOperationType.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            minVerticalPadding: 14,
                            leading: Icon(
                              _icons[tool] ?? Icons.picture_as_pdf_outlined,
                              color: palette.accent,
                            ),
                            title: Text(
                              tool.arabicTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_left,
                              color: palette.textSecondary,
                            ),
                            onTap: () => _open(context, tool),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'آخر الملفات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _history(context, palette),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _history(BuildContext context, WathiqPalette palette) {
    switch (viewModel.historyState) {
      case HistoryViewState.loading:
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      case HistoryViewState.error:
        return TextButton.icon(
          onPressed: viewModel.initializeHistory,
          icon: const Icon(Icons.refresh),
          label: const Text('تعذر التحميل، أعد المحاولة'),
        );
      case HistoryViewState.empty:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'لا توجد ملفات بعد.',
            style: TextStyle(color: palette.textSecondary),
          ),
        );
      case HistoryViewState.ready:
        return Column(
          children: [
            for (final record in viewModel.recentRecords)
              Card(
                child: ListTile(
                  title: Text(
                    record.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  subtitle: Text(
                    '${record.operationType.shortActionLabel} • ${record.formattedFinalSize}',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  onTap: () => viewModel.openProcessedFile(record),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'share':
                          viewModel.shareProcessedFile(record);
                        case 'rename':
                          _rename(context, record);
                        case 'delete':
                          viewModel.deleteProcessedFile(id: record.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'share', child: Text('مشاركة')),
                      PopupMenuItem(value: 'rename', child: Text('تسمية')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ),
              ),
          ],
        );
    }
  }
}
