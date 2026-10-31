import 'package:flutter/material.dart';

import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../core/theme/wathiq_theme.dart';
import '../../../core/widgets/wathiq_shield_logo.dart';
import '../view_models/wathiq_workspace_view_model.dart';
import 'tool_workspace_screen.dart';

/// أيقونة كل أداة.
IconData toolIcon(PdfOperationType tool) => switch (tool) {
      PdfOperationType.merge => Icons.merge_type_rounded,
      PdfOperationType.split => Icons.call_split_rounded,
      PdfOperationType.compress => Icons.compress_rounded,
      PdfOperationType.organize => Icons.grid_view_rounded,
      PdfOperationType.rotatePdf => Icons.rotate_right_rounded,
      PdfOperationType.signPdf => Icons.draw_rounded,
      PdfOperationType.editPdf => Icons.text_fields_rounded,
      PdfOperationType.watermark => Icons.water_drop_outlined,
      PdfOperationType.pageNumbers => Icons.format_list_numbered_rounded,
      PdfOperationType.imagesToPdf => Icons.add_photo_alternate_outlined,
      PdfOperationType.createPdf => Icons.note_add_outlined,
      PdfOperationType.extractText => Icons.subject_rounded,
      PdfOperationType.protectPdf => Icons.lock_outline_rounded,
      PdfOperationType.unlockPdf => Icons.lock_open_rounded,
      PdfOperationType.repairPdf => Icons.healing_outlined,
    };

/// الشاشة الرئيسية: وصول سريع + الأدوات حسب التصنيف + آخر الملفات.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

  static const _quickTools = [
    PdfOperationType.merge,
    PdfOperationType.compress,
    PdfOperationType.imagesToPdf,
  ];

  void _open(BuildContext context, PdfOperationType tool) {
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
        final others = PdfOperationType.values
            .where((t) => !_quickTools.contains(t))
            .toList();

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            const WathiqShieldLogo(size: 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'وثيق PDF',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: palette.isDark
                                  ? 'الوضع النهاري'
                                  : 'الوضع الليلي',
                              onPressed: viewModel.toggleThemeMode,
                              icon: Icon(
                                palette.isDark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            for (var i = 0; i < _quickTools.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(
                                child: _QuickToolCard(
                                  tool: _quickTools[i],
                                  highlighted: i == 0,
                                  onTap: () => _open(context, _quickTools[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    for (final category in PdfToolCategory.values) ...[
                      _SectionHeader(title: category.title),
                      _ToolGrid(
                        tools: others
                            .where((t) => t.category == category)
                            .toList(),
                        onTap: (t) => _open(context, t),
                      ),
                    ],
                    const _SectionHeader(title: 'آخر الملفات'),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverToBoxAdapter(
                        child: _RecentFiles(viewModel: viewModel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QuickToolCard extends StatelessWidget {
  const _QuickToolCard({
    required this.tool,
    required this.highlighted,
    required this.onTap,
  });

  final PdfOperationType tool;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    final bg = highlighted ? palette.accent : palette.surfaceContainer;
    final fg = highlighted ? palette.onAccent : palette.textPrimary;
    final iconColor = highlighted ? palette.onAccent : palette.accent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: highlighted
                ? null
                : Border.all(
                    color: palette.structuralBorder.withValues(alpha: 0.35),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(toolIcon(tool), size: 28, color: iconColor),
              Text(
                tool.arabicTitle,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools, required this.onTap});

  final List<PdfOperationType> tools;
  final ValueChanged<PdfOperationType> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _ToolTile(tool: tools[i], onTap: () => onTap(tools[i])),
          childCount: tools.length,
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});

  final PdfOperationType tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Material(
      color: palette.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.structuralBorder.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(toolIcon(tool), color: palette.accent, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                tool.arabicTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
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

class _RecentFiles extends StatelessWidget {
  const _RecentFiles({required this.viewModel});

  final WathiqWorkspaceViewModel viewModel;

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
          FilledButton(
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
    final palette = WathiqPalette.of(context);

    switch (viewModel.historyState) {
      case HistoryViewState.loading:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      case HistoryViewState.error:
        return TextButton.icon(
          onPressed: viewModel.initializeHistory,
          icon: const Icon(Icons.refresh),
          label: const Text('تعذر التحميل، أعد المحاولة'),
        );
      case HistoryViewState.empty:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.structuralBorder.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 32, color: palette.textSecondary),
              const SizedBox(height: 8),
              Text(
                'الملفات التي تعالجها ستظهر هنا',
                style: TextStyle(color: palette.textSecondary),
              ),
            ],
          ),
        );
      case HistoryViewState.ready:
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.structuralBorder.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < viewModel.recentRecords.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: palette.structuralBorder.withValues(alpha: 0.25),
                  ),
                _recentTile(context, palette, viewModel.recentRecords[i]),
              ],
            ],
          ),
        );
    }
  }

  Widget _recentTile(
    BuildContext context,
    WathiqPalette palette,
    ProcessedFileRecord record,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          toolIcon(record.operationType),
          size: 20,
          color: palette.accent,
        ),
      ),
      title: Text(
        record.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
      ),
      subtitle: Text(
        '${record.operationType.arabicTitle} • ${record.formattedFinalSize}',
        style: TextStyle(fontSize: 12, color: palette.textSecondary),
      ),
      onTap: () => viewModel.openProcessedFile(record),
      trailing: PopupMenuButton<String>(
        tooltip: 'خيارات',
        icon: Icon(Icons.more_vert, color: palette.textSecondary),
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
          PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
          PopupMenuItem(value: 'delete', child: Text('حذف من القائمة')),
        ],
      ),
    );
  }
}
