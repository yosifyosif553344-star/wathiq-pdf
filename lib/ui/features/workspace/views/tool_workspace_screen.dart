import 'package:flutter/material.dart';

import '../../../../data/services/pdf_isolate_service.dart';
import '../../../../domain/models/compression_preset.dart';
import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/scanner_options.dart';
import '../../../core/theme/wathiq_theme.dart';
import '../view_models/wathiq_workspace_view_model.dart';
import 'result_sheet_dialog.dart';

/// شاشة العمل البسيطة لجميع الأدوات (26 أداة): اختيار ← إعداد سريع ← تنفيذ وحفظ.
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
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final palette = WathiqPalette.of(context);
        final op = vm.activeOperation;

        return Scaffold(
          appBar: AppBar(title: Text(op.arabicTitle)),
          body: SafeArea(
            child: Column(
              children: [
                if (vm.workspaceError != null)
                  MaterialBanner(
                    content: Text(vm.workspaceError!),
                    leading: Icon(Icons.error_outline, color: palette.error),
                    actions: [
                      TextButton(
                        onPressed: vm.clearWorkspaceError,
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                if (vm.isProcessing) const LinearProgressIndicator(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [_buildBody(op, palette)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!vm.hasRequiredInput || vm.isProcessing)
                          ? null
                          : _execute,
                      child: Text(
                        vm.isProcessing ? 'جارٍ العمل...' : 'تنفيذ وحفظ',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(PdfOperationType op, WathiqPalette palette) {
    return switch (op) {
      PdfOperationType.merge => _merge(palette),
      PdfOperationType.split => _split(palette),
      PdfOperationType.organize => _organize(palette),
      PdfOperationType.rotatePdf => _rotate(palette),
      PdfOperationType.compress => _compress(palette),
      PdfOperationType.imagesToPdf => _imagesToPdf(palette),
      PdfOperationType.pageNumbers => _pageNumbers(palette),
      PdfOperationType.watermark => _watermark(palette),
      PdfOperationType.editPdf => _editPdf(palette),
      PdfOperationType.signPdf => _signPdf(palette),
      PdfOperationType.protectPdf ||
      PdfOperationType.unlockPdf =>
        _passwordTool(palette, isProtect: op == PdfOperationType.protectPdf),
      PdfOperationType.createPdf => _createPdf(),
      PdfOperationType.compressImage ||
      PdfOperationType.convertToJpg ||
      PdfOperationType.convertFromJpg =>
        _imageTool(palette, showCompression: op == PdfOperationType.compressImage),
      _ => _singleFileDirectTool(palette),
    };
  }

  Widget _pickButton(String label, {bool multiple = false}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => vm.pickPdfFiles(allowMultiple: multiple),
        icon: const Icon(Icons.add),
        label: Text(label),
      ),
    );
  }

  Widget _fileInfo(WathiqPalette palette) {
    final f = vm.selectedFiles.first;
    return Card(
      child: ListTile(
        leading: Icon(Icons.insert_drive_file_outlined, color: palette.accent),
        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${f.pageCount} صفحة • ${f.formattedSize}'),
      ),
    );
  }

  Widget _singleFileDirectTool(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) _fileInfo(palette),
      ],
    );
  }

  Widget _merge(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton('إضافة ملفات', multiple: true),
        const SizedBox(height: 12),
        if (files.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            onReorder: vm.reorderSelectedFiles,
            itemBuilder: (context, i) {
              final f = files[i];
              return Card(
                key: ValueKey('${f.path}_$i'),
                child: ListTile(
                  leading: const Icon(Icons.drag_indicator),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${f.pageCount} صفحة'),
                  trailing: IconButton(
                    tooltip: 'إزالة',
                    onPressed: () => vm.removeSelectedFileAt(i),
                    icon: Icon(Icons.close, color: palette.error),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _split(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: palette.accent,
            title: const Text('كل صفحة في ملف'),
            value: vm.burstSplitEachPage,
            onChanged: vm.setBurstSplitEachPage,
          ),
          if (!vm.burstSplitEachPage)
            TextField(
              controller: _rangeController,
              onChanged: vm.setSplitRangeExpression,
              decoration: const InputDecoration(
                labelText: 'الصفحات',
                hintText: '1, 5, 8 أو 1-10',
              ),
            ),
        ],
      ],
    );
  }

  Widget _organize(WathiqPalette palette) {
    final files = vm.selectedFiles;
    final pages = vm.pageInstructions;
    final selected = pages.where((p) => p.isSelected).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (pages.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    selected > 0 ? () => vm.rotateSelectedPages(90) : null,
                icon: const Icon(Icons.rotate_right),
                label: const Text('تدوير'),
              ),
              OutlinedButton.icon(
                onPressed: selected > 0 ? vm.deleteSelectedPages : null,
                icon: const Icon(Icons.delete_outline),
                label: Text('حذف ($selected)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: pages.length,
            itemBuilder: (context, i) {
              final p = pages[i];
              return InkWell(
                onTap: () => vm.togglePageSelection(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p.isSelected
                          ? palette.accent
                          : palette.structuralBorder,
                      width: p.isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: (p.rotationDegrees ~/ 90) % 4,
                          child: Center(
                            child: Text(
                              '${p.originalPageNumber}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap:
                                i > 0 ? () => vm.reorderPages(i, i - 1) : null,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.chevron_right, size: 20),
                            ),
                          ),
                          InkWell(
                            onTap: i < pages.length - 1
                                ? () => vm.reorderPages(i, i + 2)
                                : null,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.chevron_left, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _rotate(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 10),
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
      ],
    );
  }

  Widget _compress(WathiqPalette palette) {
    final files = vm.selectedFiles;
    final before = vm.totalSelectedBytes;
    final after = vm.estimatedCompressedBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 8),
          SegmentedButton<CompressionLevel>(
            showSelectedIcon: false,
            segments: [
              for (final l in CompressionLevel.values)
                ButtonSegment(value: l, label: Text(l.title)),
            ],
            selected: {vm.compressionLevel},
            onSelectionChanged: (s) => vm.setCompressionLevel(s.first),
          ),
          const SizedBox(height: 14),
          Text(
            'الحجم: ${_fmt(before)} ← ${_fmt(after)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _pageNumbers(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 12),
          DropdownButtonFormField<PageNumberPosition>(
            value: vm.pageNumberPosition,
            decoration: const InputDecoration(labelText: 'موضع الرقم'),
            items: [
              for (final p in PageNumberPosition.values)
                DropdownMenuItem(value: p, child: Text(p.title)),
            ],
            onChanged: (v) {
              if (v != null) vm.setPageNumberPosition(v);
            },
          ),
        ],
      ],
    );
  }

  Widget _watermark(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            onChanged: vm.setWatermarkOrEditText,
            decoration: const InputDecoration(labelText: 'نص العلامة المائية'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('الشفافية'),
              Expanded(
                child: Slider(
                  value: vm.watermarkOpacity,
                  min: 0.15,
                  max: 0.85,
                  activeColor: palette.accent,
                  onChanged: vm.setWatermarkOpacity,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _editPdf(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 3,
            onChanged: vm.setWatermarkOrEditText,
            decoration: const InputDecoration(
              labelText: 'النص المراد إضافته للوثيقة',
            ),
          ),
        ],
      ],
    );
  }

  Widget _signPdf(WathiqPalette palette) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ارسم توقيعك هنا:'),
              TextButton(
                onPressed: vm.clearSignature,
                child: const Text('مسح'),
              ),
            ],
          ),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.structuralBorder),
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                vm.addSignaturePoint(details.localPosition);
              },
              onPanEnd: (_) => vm.addSignaturePoint(null),
              child: CustomPaint(
                painter: _SignaturePadPainter(vm.signaturePoints),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _passwordTool(WathiqPalette palette, {required bool isProtect}) {
    final files = vm.selectedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pickButton(files.isEmpty ? 'اختيار ملف' : 'تغيير الملف'),
        const SizedBox(height: 12),
        if (files.isNotEmpty) ...[
          _fileInfo(palette),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: vm.setPdfPassword,
            decoration: InputDecoration(
              labelText: isProtect ? 'كلمة المرور الجديدة' : 'كلمة مرور الملف',
            ),
          ),
        ],
      ],
    );
  }

  Widget _createPdf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          onChanged: vm.setCreatePdfTitle,
          decoration: const InputDecoration(labelText: 'عنوان المستند'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyController,
          maxLines: 8,
          onChanged: vm.setCreatePdfBody,
          decoration: const InputDecoration(
            labelText: 'محتوى المستند',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _imagesToPdf(WathiqPalette palette) {
    final o = vm.scannerOptions;
    final images = vm.selectedImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.scanDocumentWithCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('كاميرا'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.pickImagesFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('المعرض'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (images.isNotEmpty)
          Text(
            '${images.length} صورة مختارة',
            style: TextStyle(color: palette.textSecondary),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PdfPaperSize>(
          value: o.paperSize,
          decoration: const InputDecoration(labelText: 'الورق'),
          items: [
            for (final s in PdfPaperSize.values)
              DropdownMenuItem(value: s, child: Text(s.title)),
          ],
          onChanged: (v) {
            if (v != null) vm.updateScannerOptions(o.copyWith(paperSize: v));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<DocumentColorFilter>(
          value: o.colorFilter,
          decoration: const InputDecoration(labelText: 'الفلتر'),
          items: [
            for (final f in DocumentColorFilter.values)
              DropdownMenuItem(value: f, child: Text(f.title)),
          ],
          onChanged: (v) {
            if (v != null) vm.updateScannerOptions(o.copyWith(colorFilter: v));
          },
        ),
      ],
    );
  }

  Widget _imageTool(WathiqPalette palette, {required bool showCompression}) {
    final images = vm.selectedImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.scanDocumentWithCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('كاميرا'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.pickImagesFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('المعرض'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (images.isNotEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.image_outlined, color: palette.accent),
              title: Text(
                images.first.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (showCompression && images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SegmentedButton<CompressionLevel>(
            showSelectedIcon: false,
            segments: [
              for (final l in CompressionLevel.values)
                ButtonSegment(value: l, label: Text(l.title)),
            ],
            selected: {vm.compressionLevel},
            onSelectionChanged: (s) => vm.setCompressionLevel(s.first),
          ),
        ],
      ],
    );
  }

  String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
