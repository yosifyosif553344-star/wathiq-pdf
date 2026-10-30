import 'package:flutter/material.dart';

import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../core/theme/wathiq_theme.dart';
import '../../../core/widgets/wathiq_shield_logo.dart';
import '../view_models/wathiq_workspace_view_model.dart';
import 'tool_workspace_screen.dart';

/// الشاشة الرئيسية لتطبيق "وثيق PDF" (الخطوة 1 من رحلة المستخدم).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
  });

  final WathiqWorkspaceViewModel viewModel;

  void _openToolWorkspace(BuildContext context, PdfOperationType tool) {
    viewModel.selectOperation(tool);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToolWorkspaceScreen(viewModel: viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final palette = WathiqPalette.of(context);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                const WathiqShieldLogo(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وثيق PDF',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        'معالجة محلية 100% داخل جهازك بدون إنترنت',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: palette.isDark
                    ? 'التبديل إلى الوضع النهاري'
                    : 'التبديل إلى الوضع الليلي',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: viewModel.toggleThemeMode,
                icon: Icon(
                  palette.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: palette.structuralBorder),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                final isTablet =
                    constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
                final horizontalPadding = isDesktop
                    ? 40.0
                    : isTablet
                        ? 24.0
                        : 16.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _FocalQuickActionBanner(
                                        onPickPdf: () async {
                                          await viewModel.pickPdfFiles();
                                          if (context.mounted) {
                                            _openToolWorkspace(
                                              context,
                                              PdfOperationType.merge,
                                            );
                                          }
                                        },
                                        onScanCamera: () async {
                                          await viewModel
                                              .scanDocumentWithCamera();
                                          if (context.mounted) {
                                            _openToolWorkspace(
                                              context,
                                              PdfOperationType.imagesToPdf,
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      _HierarchicalToolMatrix(
                                        isWide: true,
                                        onSelectTool: (tool) =>
                                            _openToolWorkspace(context, tool),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 5,
                                  child: _RecentLocalHistorySection(
                                    viewModel: viewModel,
                                    onStartFirstAction: () =>
                                        _openToolWorkspace(
                                      context,
                                      PdfOperationType.compress,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FocalQuickActionBanner(
                                  onPickPdf: () async {
                                    await viewModel.pickPdfFiles();
                                    if (context.mounted) {
                                      _openToolWorkspace(
                                        context,
                                        PdfOperationType.merge,
                                      );
                                    }
                                  },
                                  onScanCamera: () async {
                                    await viewModel.scanDocumentWithCamera();
                                    if (context.mounted) {
                                      _openToolWorkspace(
                                        context,
                                        PdfOperationType.imagesToPdf,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                _HierarchicalToolMatrix(
                                  isWide: isTablet,
                                  onSelectTool: (tool) =>
                                      _openToolWorkspace(context, tool),
                                ),
                                const SizedBox(height: 28),
                                _RecentLocalHistorySection(
                                  viewModel: viewModel,
                                  onStartFirstAction: () => _openToolWorkspace(
                                    context,
                                    PdfOperationType.compress,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// المستوى الهرمي 1: منطقة الإجراء المباشر لاختيار ملف أو تشغيل الماسح الضوئي.
class _FocalQuickActionBanner extends StatelessWidget {
  const _FocalQuickActionBanner({
    required this.onPickPdf,
    required this.onScanCamera,
  });

  final VoidCallback onPickPdf;
  final VoidCallback onScanCamera;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملفاتك لا تغادر جهازك أبداً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ادمج المحاضرات، اضغط العقود الرسمية، أو امسح الوثائق بالكاميرا مباشرة على معالج هاتفك دون رفع أي بايت للإنترنت.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: onPickPdf,
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                  label: const Text('اختيار ملف PDF من الجهاز'),
                ),
                OutlinedButton.icon(
                  onPressed: onScanCamera,
                  icon: const Icon(Icons.document_scanner_outlined, size: 20),
                  label: const Text('مسح وثيقة بالكاميرا'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// المستوى الهرمي 2: مصفوفة الأدوات المتباينة (تتجنب Bento Grid المتماثلة وفق القاعدة R-05 وR-14).
class _HierarchicalToolMatrix extends StatelessWidget {
  const _HierarchicalToolMatrix({
    required this.isWide,
    required this.onSelectTool,
  });

  final bool isWide;
  final ValueChanged<PdfOperationType> onSelectTool;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدوات المعالجة المحلية',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (isWide)
          Row(
            children: [
              Expanded(
                child: _PrimaryFeaturedToolCard(
                  operation: PdfOperationType.merge,
                  icon: Icons.merge_type_outlined,
                  metricLabel: 'سحب وإفلات • جودة أصلية',
                  onTap: () => onSelectTool(PdfOperationType.merge),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryFeaturedToolCard(
                  operation: PdfOperationType.compress,
                  icon: Icons.compress_outlined,
                  metricLabel: '3 مستويات ضغط • مقارنة الحجم',
                  onTap: () => onSelectTool(PdfOperationType.compress),
                ),
              ),
            ],
          )
        else ...[
          _PrimaryFeaturedToolCard(
            operation: PdfOperationType.merge,
            icon: Icons.merge_type_outlined,
            metricLabel: 'سحب وإفلات • جودة أصلية',
            onTap: () => onSelectTool(PdfOperationType.merge),
          ),
          const SizedBox(height: 12),
          _PrimaryFeaturedToolCard(
            operation: PdfOperationType.compress,
            icon: Icons.compress_outlined,
            metricLabel: '3 مستويات ضغط • مقارنة الحجم',
            onTap: () => onSelectTool(PdfOperationType.compress),
          ),
        ],
        const SizedBox(height: 12),
        _SpecializedToolRowCard(
          operation: PdfOperationType.split,
          icon: Icons.call_split_outlined,
          onTap: () => onSelectTool(PdfOperationType.split),
        ),
        const SizedBox(height: 10),
        _SpecializedToolRowCard(
          operation: PdfOperationType.organize,
          icon: Icons.grid_view_outlined,
          onTap: () => onSelectTool(PdfOperationType.organize),
        ),
        const SizedBox(height: 10),
        _SpecializedToolRowCard(
          operation: PdfOperationType.imagesToPdf,
          icon: Icons.camera_alt_outlined,
          onTap: () => onSelectTool(PdfOperationType.imagesToPdf),
        ),
      ],
    );
  }
}

class _PrimaryFeaturedToolCard extends StatelessWidget {
  const _PrimaryFeaturedToolCard({
    required this.operation,
    required this.icon,
    required this.metricLabel,
    required this.onTap,
  });

  final PdfOperationType operation;
  final IconData icon;
  final String metricLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.canvasBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.accent),
                    ),
                    child: Icon(icon, color: palette.accent, size: 22),
                  ),
                  Text(
                    metricLabel,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                operation.arabicTitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                operation.description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecializedToolRowCard extends StatelessWidget {
  const _SpecializedToolRowCard({
    required this.operation,
    required this.icon,
    required this.onTap,
  });

  final PdfOperationType operation;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.canvasBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.structuralBorder),
                ),
                child: Icon(icon, color: palette.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation.arabicTitle,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      operation.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onTap,
                child: Text(operation.shortActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// المستوى الهرمي 3: سجل العمليات الأخيرة مع الحالات الثلاث الإلزامية (R-27: Empty, Loading, Error).
class _RecentLocalHistorySection extends StatelessWidget {
  const _RecentLocalHistorySection({
    required this.viewModel,
    required this.onStartFirstAction,
  });

  final WathiqWorkspaceViewModel viewModel;
  final VoidCallback onStartFirstAction;

  Future<void> _showRenameDialog(
    BuildContext context,
    ProcessedFileRecord record,
  ) async {
    final controller = TextEditingController(text: record.fileName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تسمية الملف المحفوظ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'الاسم الجديد للملف',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('حفظ الاسم'),
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
    final palette = WathiqPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سجل العمليات الأخيرة على الجهاز',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            IconButton(
              tooltip: 'تحديث السجل المحلي',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: viewModel.initializeHistory,
              icon: Icon(Icons.refresh, color: palette.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        switch (viewModel.historyState) {
          HistoryViewState.loading => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'جاري قراءة سجل الملفات المعالجة محلياً من ذاكرة الجهاز...',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          HistoryViewState.error => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: palette.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            viewModel.historyErrorMessage ??
                                'حدث خطأ أثناء تحميل السجل المحلي.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: viewModel.initializeHistory,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          HistoryViewState.empty => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لا توجد ملفات معالجة في السجل المحلي حتى الآن',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'عندما تقوم بدمج أو ضغط أو تقسيم أي ملف PDF، سيظهر هنا مع حجمه قبل وبعد المعالجة للوصول السريع إليه أو مشاركته.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onStartFirstAction,
                      icon: const Icon(Icons.compress_outlined, size: 18),
                      label: const Text('ضغط أو معالجة أول ملف الآن'),
                    ),
                  ],
                ),
              ),
            ),
          HistoryViewState.ready => Column(
              children: viewModel.recentRecords.map((record) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.fileName,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.canvasBackground,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: palette.structuralBorder,
                                  ),
                                ),
                                child: Text(
                                  record.operationType.shortActionLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: palette.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'الحجم: ${record.sizeComparisonLabel} • ${record.pageCount} صفحة',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    viewModel.openProcessedFile(record),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                ),
                                label: const Text('فتح'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    viewModel.shareProcessedFile(record),
                                icon:
                                    const Icon(Icons.share_outlined, size: 16),
                                label: const Text('مشاركة'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showRenameDialog(context, record),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('تسمية'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => viewModel.deleteProcessedFile(
                                  id: record.id,
                                ),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: palette.error,
                                ),
                                label: const Text('حذف'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        },
      ],
    );
  }
}
