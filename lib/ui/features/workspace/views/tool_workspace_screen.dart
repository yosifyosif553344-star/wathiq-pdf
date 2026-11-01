import 'package:flutter/material.dart';

import '../../../../data/services/pdf_isolate_service.dart';
import '../../../../data/services/platform_storage.dart';
import '../../../../domain/models/compression_preset.dart';
import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../../domain/models/scanner_options.dart';
import '../../../core/theme/wathiq_theme.dart';
import '../view_models/wathiq_workspace_view_model.dart';
import 'home_screen.dart' show toolIcon;
import 'result_sheet_dialog.dart';

/// شاشة العمل: اختيار الملف ← إعداد بسيط ← زر تنفيذ واحد.
class ToolWorkspaceScreen extends StatefulWidget {
  const ToolWorkspaceScreen({super.key, required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  @override
  State<ToolWorkspaceScreen> createState() => _ToolWorkspaceScreenState();
}

class _ToolWorkspaceScreenState extends State<ToolWorkspaceScreen> {
  late final TextEditingController _rangeController;
  late final TextEditingController _textController;
  late final TextEditingController _passwordController;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _obscurePassword = true;

  WathiqWorkspaceViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _rangeController = TextEditingController(text: vm.splitRangeExpression);
    _textController = TextEditingController(text: vm.watermarkOrEditText);
    _passwordController = TextEditingController(text: vm.pdfPassword);
    _titleController = TextEditingController(text: vm.createPdfTitle);
    _bodyController = TextEditingController(text: vm.createPdfBody);
  }

  @override
  void dispose() {
    _rangeController.dispose();
    _textController.dispose();
    _passwordController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    FocusScope.of(context).unfocus();
    final record = await vm.executeActiveOperation();
    if (!mounted || record == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ResultSheetDialog(
        record: record,
        onOpenFile: () => vm.openProcessedFile(record),
        onShareFile: () => vm.shareProcessedFile(record),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final palette = WathiqPalette.of(context);
        final op = vm.activeOperation;

        return Scaffold(
          appBar: AppBar(
            title: Text(op.arabicTitle),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          _ToolHeader(tool: op),
                          const SizedBox(height: 20),
                          if (vm.workspaceError != null) ...[
                            _ErrorCard(
                              message: vm.workspaceError!,
                              onDismiss: vm.clearWorkspaceError,
                            ),
                            const SizedBox(height: 16),
                          ],
                          ..._buildBody(op, palette),
                        ],
                      ),
                    ),
                  ),
                ),
                _ActionBar(
                  label: op.shortActionLabel,
                  enabled: vm.hasRequiredInput && !vm.isProcessing,
                  busy: vm.isProcessing,
                  onPressed: _execute,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBody(PdfOperationType op, WathiqPalette palette) {
    return switch (op) {
      PdfOperationType.merge => _merge(palette),
      PdfOperationType.split => _split(palette),
      PdfOperationType.compress => _compress(palette),
      PdfOperationType.organize => _organize(palette),
      PdfOperationType.rotatePdf => _rotate(palette),
      PdfOperationType.signPdf => _sign(palette),
      PdfOperationType.editPdf => _editText(palette),
      PdfOperationType.watermark => _watermark(palette),
      PdfOperationType.pageNumbers => _pageNumbers(palette),
      PdfOperationType.imagesToPdf => _imagesToPdf(palette),
      PdfOperationType.createPdf => _createPdf(),
      PdfOperationType.protectPdf => _password(palette, isProtect: true),
      PdfOperationType.unlockPdf => _password(palette, isProtect: false),
      PdfOperationType.extractText ||
      PdfOperationType.repairPdf =>
        _singleFileOnly(palette),
    };
  }

  // ---------- Shared building blocks ----------

  List<Widget> _singlePdfPicker(WathiqPalette palette) {
    if (vm.selectedFiles.isEmpty) {
      return [
        _PickZone(
          icon: Icons.upload_file_rounded,
          title: 'اختر ملف PDF',
          onTap: () => vm.pickPdfFiles(allowMultiple: false),
        ),
      ];
    }
    final f = vm.selectedFiles.first;
    return [
      _FileCard(
        name: f.name,
        meta: '${f.pageCount} صفحة • ${f.formattedSize}',
        trailing: TextButton(
          onPressed: () => vm.pickPdfFiles(allowMultiple: false),
          child: const Text('تغيير'),
        ),
      ),
    ];
  }

  bool get _hasFile => vm.selectedFiles.isNotEmpty;

  // ---------- Tools ----------

  List<Widget> _singleFileOnly(WathiqPalette palette) =>
      _singlePdfPicker(palette);

  List<Widget> _merge(WathiqPalette palette) {
    final files = vm.selectedFiles;
    if (files.isEmpty) {
      return [
        _PickZone(
          icon: Icons.library_add_outlined,
          title: 'اختر ملفين أو أكثر',
          onTap: () => vm.pickPdfFiles(allowMultiple: true),
        ),
      ];
    }
    return [
      _SectionLabel(
        text: files.length < 2
            ? 'أضف ملفاً آخر على الأقل'
            : 'اسحب لتغيير الترتيب',
      ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: files.length,
        onReorder: vm.reorderSelectedFiles,
        itemBuilder: (context, i) {
          final f = files[i];
          return Padding(
            key: ValueKey('${f.path}_$i'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _FileCard(
              leadingText: '${i + 1}',
              name: f.name,
              meta: '${f.pageCount} صفحة • ${f.formattedSize}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'إزالة',
                    onPressed: () => vm.removeSelectedFileAt(i),
                    icon: Icon(Icons.close_rounded,
                        color: palette.textSecondary),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded,
                          color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => vm.pickPdfFiles(allowMultiple: true),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة ملفات'),
      ),
    ];
  }

  List<Widget> _split(WathiqPalette palette) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        const _SectionLabel(text: 'طريقة التقسيم'),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('صفحات محددة')),
            ButtonSegment(value: true, label: Text('كل صفحة ملف')),
          ],
          selected: {vm.burstSplitEachPage},
          onSelectionChanged: (s) => vm.setBurstSplitEachPage(s.first),
        ),
        if (!vm.burstSplitEachPage) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _rangeController,
            onChanged: vm.setSplitRangeExpression,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'أرقام الصفحات',
              hintText: 'مثال: 1-3, 5, 8',
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          _Hint(
            text:
                'سينتج ${vm.selectedFiles.first.pageCount} ملفاً، ملف لكل صفحة.',
          ),
        ],
      ],
    ];
  }

  List<Widget> _compress(WathiqPalette palette) {
    final totalBytes = vm.totalSelectedBytes;
    final activeSavingPct =
        ((1.0 - vm.compressionLevel.expectedRatio) * 100).round();
    final activeEstimatedSize =
        ProcessedFileRecord.formatBytes(vm.estimatedCompressedBytes);
    final currentFormattedSize = ProcessedFileRecord.formatBytes(totalBytes);

    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        const _SectionLabel(text: 'مستوى الضغط وتقدير الحجم'),
        for (final level in CompressionLevel.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Builder(
              builder: (_) {
                final savingPct = ((1.0 - level.expectedRatio) * 100).round();
                final estBytes = (totalBytes * level.expectedRatio).round();
                final estFormatted = ProcessedFileRecord.formatBytes(estBytes);
                return _ChoiceCard(
                  selected: vm.compressionLevel == level,
                  title: level.title,
                  subtitle:
                      'تخفيف متوقع ~$savingPct% • يصبح تقريباً $estFormatted',
                  onTap: () => vm.setCompressionLevel(level),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
        _Hint(
          text:
              'الحجم الحالي: $currentFormattedSize ← المتوقع بعد الضغط: ~$activeEstimatedSize (توفير ~$activeSavingPct%)',
        ),
      ],
    ];
  }

  List<Widget> _organize(WathiqPalette palette) {
    final pages = vm.pageInstructions;
    final selected = pages.where((p) => p.isSelected).length;
    return [
      ..._singlePdfPicker(palette),
      if (pages.isNotEmpty) ...[
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _SectionLabel(
                text: selected == 0
                    ? 'اضغط على صفحة لتحديدها'
                    : 'محدد: $selected',
              ),
            ),
            IconButton(
              tooltip: 'تدوير المحدد',
              onPressed:
                  selected > 0 ? () => vm.rotateSelectedPages(90) : null,
              icon: const Icon(Icons.rotate_right_rounded),
            ),
            IconButton(
              tooltip: 'حذف المحدد',
              onPressed: selected > 0 ? vm.deleteSelectedPages : null,
              icon: Icon(Icons.delete_outline_rounded,
                  color: selected > 0 ? palette.error : null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: pages.length,
          itemBuilder: (context, i) {
            final p = pages[i];
            return _PageTile(
              number: p.originalPageNumber,
              rotation: p.rotationDegrees,
              selected: p.isSelected,
              onTap: () => vm.togglePageSelection(i),
              onMoveBack: i > 0 ? () => vm.reorderPages(i, i - 1) : null,
              onMoveForward: i < pages.length - 1
                  ? () => vm.reorderPages(i, i + 2)
                  : null,
            );
          },
        ),
      ],
    ];
  }

  List<Widget> _rotate(WathiqPalette palette) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        const _SectionLabel(text: 'زاوية التدوير'),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 90, label: Text('90°')),
            ButtonSegment(value: 180, label: Text('180°')),
            ButtonSegment(value: 270, label: Text('270°')),
          ],
          selected: {vm.bulkRotationDegrees},
          onSelectionChanged: (s) => vm.setBulkRotationDegrees(s.first),
        ),
      ],
    ];
  }

  List<Widget> _sign(WathiqPalette palette) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: _SectionLabel(text: 'ارسم توقيعك')),
            TextButton.icon(
              onPressed: vm.signaturePoints.isEmpty ? null : vm.clearSignature,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('مسح'),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            color: Colors.white,
            child: GestureDetector(
              onPanStart: (d) => vm.addSignaturePoint(d.localPosition),
              onPanUpdate: (d) => vm.addSignaturePoint(d.localPosition),
              onPanEnd: (_) => vm.addSignaturePoint(null),
              child: CustomPaint(
                painter: _SignaturePadPainter(vm.signaturePoints),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _Hint(text: 'يوضع التوقيع أسفل الصفحة الأخيرة.'),
      ],
    ];
  }

  List<Widget> _editText(WathiqPalette palette) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        TextField(
          controller: _textController,
          maxLines: 3,
          onChanged: vm.setWatermarkOrEditText,
          decoration: const InputDecoration(labelText: 'النص'),
        ),
        const SizedBox(height: 8),
        const _Hint(text: 'يضاف النص أسفل الصفحة الأخيرة.'),
      ],
    ];
  }

  List<Widget> _watermark(WathiqPalette palette) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        TextField(
          controller: _textController,
          onChanged: vm.setWatermarkOrEditText,
          decoration: const InputDecoration(labelText: 'نص العلامة'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const _SectionLabel(text: 'الشفافية'),
            const Spacer(),
            Text(
              '${(vm.watermarkOpacity * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        Slider(
          value: vm.watermarkOpacity,
          min: 0.15,
          max: 0.85,
          onChanged: vm.setWatermarkOpacity,
        ),
      ],
    ];
  }

  List<Widget> _pageNumbers(WathiqPalette palette) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        const _SectionLabel(text: 'مكان الرقم'),
        for (final p in PageNumberPosition.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceCard(
              selected: vm.pageNumberPosition == p,
              title: p.title,
              onTap: () => vm.setPageNumberPosition(p),
            ),
          ),
      ],
    ];
  }

  List<Widget> _password(WathiqPalette palette, {required bool isProtect}) {
    return [
      ..._singlePdfPicker(palette),
      if (_hasFile) ...[
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: vm.setPdfPassword,
          decoration: InputDecoration(
            labelText: isProtect ? 'كلمة مرور جديدة' : 'كلمة مرور الملف',
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'إظهار' : 'إخفاء',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        if (isProtect) ...[
          const SizedBox(height: 8),
          const _Hint(text: 'احفظ كلمة المرور، لا يمكن استرجاعها.'),
        ],
      ],
    ];
  }

  List<Widget> _createPdf() {
    return [
      TextField(
        controller: _titleController,
        onChanged: vm.setCreatePdfTitle,
        decoration: const InputDecoration(labelText: 'العنوان'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _bodyController,
        minLines: 8,
        maxLines: 16,
        onChanged: vm.setCreatePdfBody,
        decoration: const InputDecoration(
          labelText: 'المحتوى',
          alignLabelWithHint: true,
        ),
      ),
    ];
  }

  List<Widget> _imagesToPdf(WathiqPalette palette) {
    final o = vm.scannerOptions;
    final images = vm.selectedImages;
    return [
      Row(
        children: [
          Expanded(
            child: _PickZone(
              compact: true,
              icon: Icons.photo_camera_outlined,
              title: 'الكاميرا',
              onTap: vm.scanDocumentWithCamera,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PickZone(
              compact: true,
              icon: Icons.photo_library_outlined,
              title: 'المعرض',
              onTap: vm.pickImagesFromGallery,
            ),
          ),
        ],
      ),
      if (images.isNotEmpty) ...[
        const SizedBox(height: 20),
        _SectionLabel(text: '${images.length} صورة'),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PlatformStorage.buildImageThumbnail(images[i]),
                ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => vm.removeSelectedImageAt(i),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel(text: 'حجم الصفحة'),
        SegmentedButton<PdfPaperSize>(
          showSelectedIcon: false,
          segments: [
            for (final s in PdfPaperSize.values)
              ButtonSegment(value: s, label: Text(s.title)),
          ],
          selected: {o.paperSize},
          onSelectionChanged: (s) =>
              vm.updateScannerOptions(o.copyWith(paperSize: s.first)),
        ),
        const SizedBox(height: 20),
        const _SectionLabel(text: 'الألوان'),
        SegmentedButton<DocumentColorFilter>(
          showSelectedIcon: false,
          segments: [
            for (final f in DocumentColorFilter.values)
              ButtonSegment(value: f, label: Text(f.title)),
          ],
          selected: {o.colorFilter},
          onSelectionChanged: (s) =>
              vm.updateScannerOptions(o.copyWith(colorFilter: s.first)),
        ),
      ],
    ];
  }
}

// ---------- Widgets ----------

class _ToolHeader extends StatelessWidget {
  const _ToolHeader({required this.tool});

  final PdfOperationType tool;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(toolIcon(tool), color: palette.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            tool.description,
            style: TextStyle(fontSize: 14, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: palette.textSecondary),
    );
  }
}

class _PickZone extends StatelessWidget {
  const _PickZone({
    required this.icon,
    required this.title,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Material(
      color: palette.accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: compact ? 120 : 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: palette.accent.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 30 : 44, color: palette.accent),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.name,
    required this.meta,
    this.trailing,
    this.leadingText,
  });

  final String name;
  final String meta;
  final Widget? trailing;
  final String? leadingText;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.structuralBorder.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: leadingText != null
                ? Text(
                    leadingText!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  )
                : Icon(Icons.picture_as_pdf_outlined, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Material(
      color: selected
          ? palette.accent.withValues(alpha: 0.10)
          : palette.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : palette.structuralBorder.withValues(alpha: 0.35),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.number,
    required this.rotation,
    required this.selected,
    required this.onTap,
    this.onMoveBack,
    this.onMoveForward,
  });

  final int number;
  final int rotation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onMoveBack;
  final VoidCallback? onMoveForward;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Column(
      children: [
        Expanded(
          child: Material(
            color: palette.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? palette.accent
                        : palette.structuralBorder.withValues(alpha: 0.35),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: AnimatedRotation(
                        turns: rotation / 360,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.description_outlined,
                          size: 34,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 6,
                      start: 0,
                      end: 0,
                      child: Text(
                        '$number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    if (selected)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: Icon(Icons.check_circle_rounded,
                            size: 20, color: palette.accent),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'تقديم',
              visualDensity: VisualDensity.compact,
              onPressed: onMoveBack,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: 'تأخير',
              visualDensity: VisualDensity.compact,
              onPressed: onMoveForward,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.error.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.textPrimary),
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: palette.canvasBackground,
        border: Border(
          top: BorderSide(
            color: palette.structuralBorder.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: palette.onAccent,
                      ),
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePadPainter extends CustomPainter {
  const _SignaturePadPainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePadPainter oldDelegate) => true;
}
