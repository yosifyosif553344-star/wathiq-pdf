import 'package:flutter/material.dart';

import '../../../../domain/models/compression_preset.dart';
import '../../../../domain/models/page_instruction.dart';
import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../../domain/models/scanner_options.dart';
import '../../../core/theme/wathiq_theme.dart';
import '../view_models/wathiq_workspace_view_model.dart';
import 'result_sheet_dialog.dart';

/// شاشة العمل التفاعلية (الخطوة 2 من رحلة المستخدم): اختيار الملف -> التعديل البصري السريع -> معالجة وحفظ.
class ToolWorkspaceScreen extends StatefulWidget {
  const ToolWorkspaceScreen({
    super.key,
    required this.viewModel,
  });

  final WathiqWorkspaceViewModel viewModel;

  @override
  State<ToolWorkspaceScreen> createState() => _ToolWorkspaceScreenState();
}

class _ToolWorkspaceScreenState extends State<ToolWorkspaceScreen> {
  late final TextEditingController _fileNameController;
  late final TextEditingController _pageRangeController;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(
      text: widget.viewModel.outputFileName,
    );
    _pageRangeController = TextEditingController(
      text: widget.viewModel.splitRangeExpression,
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _pageRangeController.dispose();
    super.dispose();
  }

  Future<void> _handleExecute() async {
    widget.viewModel.setOutputFileName(_fileNameController.text);
    final record = await widget.viewModel.executeActiveOperation();
    if (!mounted || record == null) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => ResultSheetDialog(
        record: record,
        onOpenFile: () => widget.viewModel.openProcessedFile(record),
        onShareFile: () => widget.viewModel.shareProcessedFile(record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final palette = WathiqPalette.of(context);
        final op = widget.viewModel.activeOperation;

        return Scaffold(
          appBar: AppBar(
            title: Text(op.arabicTitle),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: palette.structuralBorder),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: palette.accent),
                    ),
                    child: Text(
                      'خيط معزول (Isolate) • بدون إنترنت',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (widget.viewModel.workspaceError != null)
                  _ErrorBanner(
                    message: widget.viewModel.workspaceError!,
                    onDismiss: widget.viewModel.clearWorkspaceError,
                  ),
                if (widget.viewModel.isProcessing)
                  _ProcessingBanner(
                    statusText: widget.viewModel.processingStatusText,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _OperationSelectorBar(viewModel: widget.viewModel),
                            const SizedBox(height: 20),
                            _OutputFileNameCard(
                              controller: _fileNameController,
                              onChanged: widget.viewModel.setOutputFileName,
                            ),
                            const SizedBox(height: 20),
                            switch (op) {
                              PdfOperationType.merge => _MergeWorkspaceSection(
                                  viewModel: widget.viewModel,
                                ),
                              PdfOperationType.split => _SplitWorkspaceSection(
                                  viewModel: widget.viewModel,
                                  rangeController: _pageRangeController,
                                ),
                              PdfOperationType.organize =>
                                _OrganizeWorkspaceSection(
                                  viewModel: widget.viewModel,
                                ),
                              PdfOperationType.compress =>
                                _CompressWorkspaceSection(
                                  viewModel: widget.viewModel,
                                ),
                              PdfOperationType.imagesToPdf =>
                                _ScannerWorkspaceSection(
                                  viewModel: widget.viewModel,
                                ),
                            },
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _PersistentActionFooter(
                  viewModel: widget.viewModel,
                  onExecute: _handleExecute,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OperationSelectorBar extends StatelessWidget {
  const _OperationSelectorBar({required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PdfOperationType.values.map((op) {
        final isSelected = viewModel.activeOperation == op;
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor:
                isSelected ? palette.accent : palette.surfaceContainer,
            foregroundColor: isSelected ? palette.onAccent : palette.textPrimary,
            side: BorderSide(
              color: isSelected ? palette.accent : palette.structuralBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          onPressed: () => viewModel.selectOperation(op),
          child: Text(op.shortActionLabel),
        );
      }).toList(),
    );
  }
}

class _OutputFileNameCard extends StatelessWidget {
  const _OutputFileNameCard({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اسم الملف الناتج في ذاكرة الجهاز',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'مثال: محاضرات_الفصل_الأول_مدمجة.pdf',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أ. قسم دمج الملفات مع إعادة الترتيب بالسحب والإفلات وأزرار لوحة المفاتيح.
class _MergeWorkspaceSection extends StatelessWidget {
  const _MergeWorkspaceSection({required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final files = viewModel.selectedFiles;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الملفات المختارة للدمج (${files.length})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => viewModel.pickPdfFiles(allowMultiple: true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة ملفات PDF'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اسحب الملفات لإعادة ترتيب تسلسل الدمج، أو استخدم أسهم الصعود والهبوط.',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            if (files.isEmpty)
              _EmptySelectionBox(
                title: 'لم يتم اختيار ملفات للدمج بعد',
                subtitle:
                    'اختر ملفين أو أكثر من ذاكرة الجهاز لترتيبها ودمجها في ملف واحد.',
                buttonLabel: 'اختيار ملفات PDF من الجهاز',
                onPressed: () => viewModel.pickPdfFiles(allowMultiple: true),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: files.length,
                onReorder: viewModel.reorderSelectedFiles,
                itemBuilder: (context, index) {
                  final item = files[index];
                  return Container(
                    key: ValueKey('${item.path}_$index'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.canvasBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.structuralBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                '${item.pageCount} صفحات • ${item.formattedSize}',
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
                          tooltip: 'تحريك الملف للأعلى',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: index > 0
                              ? () => viewModel.reorderSelectedFiles(
                                    index,
                                    index - 1,
                                  )
                              : null,
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: 'تحريك الملف للأسفل',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: index < files.length - 1
                              ? () => viewModel.reorderSelectedFiles(
                                    index,
                                    index + 2,
                                  )
                              : null,
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        IconButton(
                          tooltip: 'إزالة الملف من قائمة الدمج',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: () =>
                              viewModel.removeSelectedFileAt(index),
                          icon: Icon(
                            Icons.delete_outline,
                            color: palette.error,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// ب. قسم تقسيم الملفات (نطاق صفحات مخصص أو فصل كل صفحة كملف مستقل).
class _SplitWorkspaceSection extends StatelessWidget {
  const _SplitWorkspaceSection({
    required this.viewModel,
    required this.rangeController,
  });

  final WathiqWorkspaceViewModel viewModel;
  final TextEditingController rangeController;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final files = viewModel.selectedFiles;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تقسيم واستخراج صفحات الوثيقة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => viewModel.pickPdfFiles(allowMultiple: false),
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('اختيار ملف PDF'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (files.isEmpty)
              _EmptySelectionBox(
                title: 'لم يتم اختيار ملف لتقسيمه',
                subtitle:
                    'اختر ملف PDF لتحديد نطاق الصفحات المطلوب استخراجه أو فصله.',
                buttonLabel: 'اختيار ملف PDF للتقسيم',
                onPressed: () => viewModel.pickPdfFiles(allowMultiple: false),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.canvasBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.structuralBorder),
                ),
                child: Text(
                  'الملف النشط: ${files.first.name} (${files.first.pageCount} صفحة • ${files.first.formattedSize})',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 13,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: palette.accent,
                title: Text(
                  'تقسيم الملف بالكامل (كل صفحة في ملف PDF مستقل)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'ينشئ ${files.first.pageCount} ملفات PDF منفصلة في ذاكرة الجهاز.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
                value: viewModel.burstSplitEachPage,
                onChanged: viewModel.setBurstSplitEachPage,
              ),
              if (!viewModel.burstSplitEachPage) ...[
                const SizedBox(height: 12),
                Text(
                  'أرقام الصفحات أو النطاق المراد استخراجه',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rangeController,
                  onChanged: viewModel.setSplitRangeExpression,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: palette.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'مثال: 1, 5, 8 أو 1-10',
                    prefixIcon: Icon(Icons.call_split_outlined),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// ج. قسم إعادة ترتيب وحذف وتدوير الصفحات مع شبكة معاينة المصغرات.
class _OrganizeWorkspaceSection extends StatelessWidget {
  const _OrganizeWorkspaceSection({required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final files = viewModel.selectedFiles;
    final pages = viewModel.pageInstructions;
    final selectedCount = pages.where((p) => p.isSelected).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'معاينة وترتيب الصفحات (${pages.length})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (pages.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: selectedCount > 0
                            ? () => viewModel.rotateSelectedPages(90)
                            : null,
                        icon: const Icon(Icons.rotate_right, size: 18),
                        label: const Text('تدوير 90°'),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedCount > 0
                            ? () => viewModel.rotateSelectedPages(180)
                            : null,
                        icon: const Icon(Icons.flip_camera_android, size: 18),
                        label: const Text('تدوير 180°'),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedCount > 0
                            ? viewModel.deleteSelectedPages
                            : null,
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                          color: palette.error,
                        ),
                        label: Text('حذف المحدد ($selectedCount)'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () =>
                          viewModel.pickPdfFiles(allowMultiple: false),
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('اختيار ملف آخر'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (files.isEmpty)
              _EmptySelectionBox(
                title: 'اختر ملف PDF لعرض مصغرات صفحاته',
                subtitle:
                    'ستظهر معاينة لجميع الصفحات لإعادة ترتيبها أو تدويرها أو حذف أي صفحة بضغطة واحدة.',
                buttonLabel: 'اختيار ملف PDF للتنظيم',
                onPressed: () => viewModel.pickPdfFiles(allowMultiple: false),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 680
                      ? 4
                      : constraints.maxWidth > 440
                          ? 3
                          : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return _PageThumbnailTile(
                        filePath: files.first.path,
                        instruction: page,
                        index: index,
                        totalCount: pages.length,
                        onToggleSelect: () =>
                            viewModel.togglePageSelection(index),
                        onRotate90: () => viewModel.rotatePageAt(index, 90),
                        onDelete: () => viewModel.deletePageAt(index),
                        onMovePrevious: index > 0
                            ? () => viewModel.reorderPages(index, index - 1)
                            : null,
                        onMoveNext: index < pages.length - 1
                            ? () => viewModel.reorderPages(index, index + 2)
                            : null,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PageThumbnailTile extends StatelessWidget {
  const _PageThumbnailTile({
    required this.filePath,
    required this.instruction,
    required this.index,
    required this.totalCount,
    required this.onToggleSelect,
    required this.onRotate90,
    required this.onDelete,
    this.onMovePrevious,
    this.onMoveNext,
  });

  final String filePath;
  final PdfPageInstruction instruction;
  final int index;
  final int totalCount;
  final VoidCallback onToggleSelect;
  final VoidCallback onRotate90;
  final VoidCallback onDelete;
  final VoidCallback? onMovePrevious;
  final VoidCallback? onMoveNext;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final isSelected = instruction.isSelected;

    return InkWell(
      onTap: onToggleSelect,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.canvasBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? palette.accent : palette.structuralBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'P.${instruction.originalPageNumber.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? palette.accent : palette.textPrimary,
                  ),
                ),
                if (instruction.rotationDegrees != 0)
                  Text(
                    '${instruction.rotationDegrees}°',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                      color: palette.accent,
                    ),
                  ),
                Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected ? palette.accent : palette.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: RotatedBox(
                  quarterTurns: (instruction.rotationDegrees ~/ 90) % 4,
                  child: Container(
                    color: palette.surfaceContainer,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 26,
                          color: isSelected
                              ? palette.accent
                              : palette.textSecondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'صفحة ${instruction.originalPageNumber}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'تدوير 90 درجة',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onRotate90,
                  icon: const Icon(Icons.rotate_right, size: 18),
                ),
                IconButton(
                  tooltip: 'تقديم الصفحة',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onMovePrevious,
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
                IconButton(
                  tooltip: 'تأخير الصفحة',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onMoveNext,
                  icon: const Icon(Icons.chevron_left, size: 18),
                ),
                IconButton(
                  tooltip: 'حذف الصفحة',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: palette.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// د. قسم ضغط حجم الملف بـ 3 مستويات مع مقارنة الحجم قبل وبعد الضغط.
class _CompressWorkspaceSection extends StatelessWidget {
  const _CompressWorkspaceSection({required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final files = viewModel.selectedFiles;
    final originalBytes = viewModel.totalSelectedBytes;
    final estimatedBytes = viewModel.estimatedCompressedBytes;
    final savedPercent = originalBytes > 0
        ? ((1.0 - (estimatedBytes / originalBytes)) * 100).round()
        : 80;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مستويات ضغط حجم الملف',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => viewModel.pickPdfFiles(allowMultiple: false),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('اختيار ملف PDF'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...CompressionLevel.values.map((level) {
              final selected = viewModel.compressionLevel == level;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => viewModel.setCompressionLevel(level),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.canvasBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            selected ? palette.accent : palette.structuralBorder,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color:
                              selected ? palette.accent : palette.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                level.title,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                level.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${level.targetDpi} DPI',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? palette.accent
                                : palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.canvasBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.accent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحجم قبل الضغط: ${ProcessedFileRecord.formatBytes(originalBytes)}',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الحجم المتوقع بعد الضغط: ${ProcessedFileRecord.formatBytes(estimatedBytes)}',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'توفير ~$savedPercent%',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// هـ. قسم تحويل الصور والماسح الضوئي بالكاميرا إلى ملف PDF.
class _ScannerWorkspaceSection extends StatelessWidget {
  const _ScannerWorkspaceSection({required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final options = viewModel.scannerOptions;
    final images = viewModel.selectedImages;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'الصور والوثائق الممسوحة (${images.length})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: viewModel.scanDocumentWithCamera,
                      icon: const Icon(Icons.document_scanner_outlined, size: 18),
                      label: const Text('مسح بالكاميرا'),
                    ),
                    OutlinedButton.icon(
                      onPressed: viewModel.pickImagesFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('استيراد صور من المعرض'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'إعدادات الورق والهوامش وفلتر الوثائق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PdfPaperSize>(
              value: options.paperSize,
              decoration: const InputDecoration(labelText: 'حجم الورق'),
              items: PdfPaperSize.values
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.title)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  viewModel.updateScannerOptions(
                    options.copyWith(paperSize: val),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PdfPageMargin>(
              value: options.margin,
              decoration: const InputDecoration(labelText: 'هوامش الصفحة'),
              items: PdfPageMargin.values
                  .map(
                    (m) => DropdownMenuItem(value: m, child: Text(m.title)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  viewModel.updateScannerOptions(options.copyWith(margin: val));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentColorFilter>(
              value: options.colorFilter,
              decoration: const InputDecoration(labelText: 'فلتر الوثيقة'),
              items: DocumentColorFilter.values
                  .map(
                    (f) => DropdownMenuItem(value: f, child: Text(f.title)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  viewModel.updateScannerOptions(
                    options.copyWith(colorFilter: val),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: palette.accent,
              title: Text(
                'قص تلقائي لحواف الورقة (Auto-Crop)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              value: options.autoCropEdges,
              onChanged: (val) => viewModel.updateScannerOptions(
                options.copyWith(autoCropEdges: val),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySelectionBox extends StatelessWidget {
  const _EmptySelectionBox({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.canvasBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.structuralBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.upload_file_outlined, size: 36, color: palette.accent),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: palette.error, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: palette.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إغلاق التنبيه',
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProcessingBanner extends StatelessWidget {
  const _ProcessingBanner({required this.statusText});

  final String statusText;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: palette.surfaceContainer,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersistentActionFooter extends StatelessWidget {
  const _PersistentActionFooter({
    required this.viewModel,
    required this.onExecute,
  });

  final WathiqWorkspaceViewModel viewModel;
  final VoidCallback onExecute;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        border: Border(
          top: BorderSide(color: palette.structuralBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الإجمالي: ${viewModel.totalSelectedPages} صفحة • ${ProcessedFileRecord.formatBytes(viewModel.totalSelectedBytes)}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  'الحفظ محلياً في ذاكرة الجهاز مع مسح الكاش المؤقت فور الانتهاء',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: viewModel.isProcessing ? null : onExecute,
            icon: const Icon(Icons.save_alt_outlined, size: 20),
            label: Text(
              '${viewModel.activeOperation.shortActionLabel} وحفظ في الجهاز',
            ),
          ),
        ],
      ),
    );
  }
}
