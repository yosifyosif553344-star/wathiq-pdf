import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../data/repositories/local_history_repository.dart';
import '../../../../data/repositories/pdf_operations_repository.dart';
import '../../../../domain/models/compression_preset.dart';
import '../../../../domain/models/page_instruction.dart';
import '../../../../domain/models/pdf_operation_type.dart';
import '../../../../domain/models/processed_file_record.dart';
import '../../../../domain/models/scanner_options.dart';
import '../../../../domain/use_cases/parse_page_range_use_case.dart';

/// نموذج ملف مدخل مختار من ذاكرة الجهاز لمعالجته محلياً.
class SelectedInputFile {
  const SelectedInputFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.pageCount,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final int pageCount;

  String get formattedSize => ProcessedFileRecord.formatBytes(sizeBytes);
}

/// حالات تحميل وعرض سجل العمليات الأخيرة (R-27: Empty, Loading, Error, Ready).
enum HistoryViewState {
  loading,
  empty,
  ready,
  error,
}

/// ViewModel الرئيسي لإدارة حالة تطبيق "وثيق PDF" وفصل منطق المعالجة عن الواجهة.
class WathiqWorkspaceViewModel extends ChangeNotifier {
  WathiqWorkspaceViewModel({
    required PdfOperationsRepository operationsRepository,
    required LocalHistoryRepository historyRepository,
    ParsePageRangeUseCase pageRangeParser = const ParsePageRangeUseCase(),
  })  : _operationsRepository = operationsRepository,
        _historyRepository = historyRepository,
        _pageRangeParser = pageRangeParser;

  final PdfOperationsRepository _operationsRepository;
  final LocalHistoryRepository _historyRepository;
  final ParsePageRangeUseCase _pageRangeParser;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  PdfOperationType _activeOperation = PdfOperationType.merge;
  PdfOperationType get activeOperation => _activeOperation;

  final List<SelectedInputFile> _selectedFiles = [];
  List<SelectedInputFile> get selectedFiles => List.unmodifiable(_selectedFiles);

  final List<String> _selectedImages = [];
  List<String> get selectedImages => List.unmodifiable(_selectedImages);

  final List<PdfPageInstruction> _pageInstructions = [];
  List<PdfPageInstruction> get pageInstructions => List.unmodifiable(_pageInstructions);

  CompressionLevel _compressionLevel = CompressionLevel.medium;
  CompressionLevel get compressionLevel => _compressionLevel;

  ScannerToPdfOptions _scannerOptions = const ScannerToPdfOptions();
  ScannerToPdfOptions get scannerOptions => _scannerOptions;

  String _splitRangeExpression = '1-3';
  String get splitRangeExpression => _splitRangeExpression;

  bool _burstSplitEachPage = false;
  bool get burstSplitEachPage => _burstSplitEachPage;

  String _outputFileName = 'وثيقة_معالجة_محلياً.pdf';
  String get outputFileName => _outputFileName;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _processingStatusText = '';
  String get processingStatusText => _processingStatusText;

  String? _workspaceError;
  String? get workspaceError => _workspaceError;

  ProcessedFileRecord? _lastCompletedRecord;
  ProcessedFileRecord? get lastCompletedRecord => _lastCompletedRecord;

  HistoryViewState _historyState = HistoryViewState.loading;
  HistoryViewState get historyState => _historyState;

  String? _historyErrorMessage;
  String? get historyErrorMessage => _historyErrorMessage;

  List<ProcessedFileRecord> _recentRecords = const [];
  List<ProcessedFileRecord> get recentRecords => List.unmodifiable(_recentRecords);

  /// إجمالي حجم الملفات المختارة حالياً بالبايت.
  int get totalSelectedBytes =>
      _selectedFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  /// إجمالي عدد الصفحات في الملفات المختارة حالياً.
  int get totalSelectedPages =>
      _selectedFiles.fold(0, (sum, item) => sum + item.pageCount);

  /// الحجم المتوقع بعد الضغط بناءً على المستوى المختار.
  int get estimatedCompressedBytes {
    if (totalSelectedBytes <= 0) return 0;
    return (totalSelectedBytes * _compressionLevel.expectedRatio).round();
  }

  /// تهيئة وتحميل سجل العمليات الأخيرة من التخزين المحلي.
  Future<void> initializeHistory() async {
    _historyState = HistoryViewState.loading;
    _historyErrorMessage = null;
    notifyListeners();

    try {
      _recentRecords = await _historyRepository.loadRecentRecords();
      _historyState = _recentRecords.isEmpty
          ? HistoryViewState.empty
          : HistoryViewState.ready;
    } catch (e) {
      _historyState = HistoryViewState.error;
      _historyErrorMessage =
          'تعذرت قراءة سجل العمليات المحلية من ذاكرة الجهاز. تحقق من صلاحيات التخزين.';
    }
    notifyListeners();
  }

  /// تبديل المظهر بين الوضع الليلي والنهاري (R-21, R-34).
  void toggleThemeMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void selectOperation(PdfOperationType operation) {
    _activeOperation = operation;
    _workspaceError = null;
    _outputFileName = '${operation.shortActionLabel.replaceAll(' ', '_')}_${DateTime.now().hour}${DateTime.now().minute}.pdf';
    notifyListeners();
  }

  void setCompressionLevel(CompressionLevel level) {
    _compressionLevel = level;
    notifyListeners();
  }

  void updateScannerOptions(ScannerToPdfOptions options) {
    _scannerOptions = options;
    notifyListeners();
  }

  void setSplitRangeExpression(String value) {
    _splitRangeExpression = value;
    _workspaceError = null;
    notifyListeners();
  }

  void setBurstSplitEachPage(bool value) {
    _burstSplitEachPage = value;
    _workspaceError = null;
    notifyListeners();
  }

  void setOutputFileName(String value) {
    _outputFileName = value;
    notifyListeners();
  }

  void clearWorkspaceError() {
    _workspaceError = null;
    notifyListeners();
  }

  /// اختيار ملف أو عدة ملفات PDF من ذاكرة الجهاز.
  Future<void> pickPdfFiles({bool allowMultiple = true}) async {
    _workspaceError = null;
    try {
      final List<PlatformFile> pickedFiles;
      if (allowMultiple) {
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
      } else {
        final single = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        pickedFiles = single != null ? <PlatformFile>[single] : const <PlatformFile>[];
      }
      if (pickedFiles.isEmpty) return;

      if (!allowMultiple) {
        _selectedFiles.clear();
      }

      for (final platformFile in pickedFiles) {
        final path = platformFile.path;
        if (path == null) continue;
        final file = File(path);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        var pagesCount = 1;
        try {
          final doc = PdfDocument(inputBytes: bytes);
          pagesCount = doc.pages.count;
          doc.dispose();
        } catch (_) {
          pagesCount = 1;
        }

        _selectedFiles.add(
          SelectedInputFile(
            path: path,
            name: platformFile.name,
            sizeBytes: bytes.length,
            pageCount: pagesCount,
          ),
        );
      }

      _rebuildPageInstructionsFromPrimaryFile();
      notifyListeners();
    } catch (e) {
      _workspaceError = 'تعذر استيراد ملف الـ PDF المختار. تأكد من سلامة الملف وعدم تلفه.';
      notifyListeners();
    }
  }

  /// استيراد صور متعددة من المعرض (JPG, PNG, WebP).
  Future<void> pickImagesFromGallery() async {
    _workspaceError = null;
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage();
      if (pickedList.isEmpty) return;
      for (final imgFile in pickedList) {
        _selectedImages.add(imgFile.path);
      }
      _activeOperation = PdfOperationType.imagesToPdf;
      notifyListeners();
    } catch (_) {
      _workspaceError = 'تعذر الوصول إلى معرض الصور المحلي.';
      notifyListeners();
    }
  }

  /// تشغيل الماسح الضوئي بالكاميرا مع قص الحواف التلقائي.
  Future<void> scanDocumentWithCamera() async {
    _workspaceError = null;
    try {
      final picker = ImagePicker();
      final captured = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (captured == null) return;
      _selectedImages.add(captured.path);
      _activeOperation = PdfOperationType.imagesToPdf;
      notifyListeners();
    } catch (_) {
      _workspaceError =
          'تعذر تشغيل الماسح الضوئي للكاميرا. تأكد من منح صلاحية الكاميرا للتطبيق.';
      notifyListeners();
    }
  }

  /// إعادة ترتيب الملفات المختارة للدمج عبر السحب والإفلات أو أزرار لوحة المفاتيح.
  void reorderSelectedFiles(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _selectedFiles.length) return;
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    targetIndex = targetIndex.clamp(0, _selectedFiles.length - 1);
    final item = _selectedFiles.removeAt(oldIndex);
    _selectedFiles.insert(targetIndex, item);
    notifyListeners();
  }

  void removeSelectedFileAt(int index) {
    if (index < 0 || index >= _selectedFiles.length) return;
    _selectedFiles.removeAt(index);
    _rebuildPageInstructionsFromPrimaryFile();
    notifyListeners();
  }

  void removeSelectedImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    _selectedImages.removeAt(index);
    notifyListeners();
  }

  void _rebuildPageInstructionsFromPrimaryFile() {
    _pageInstructions.clear();
    if (_selectedFiles.isEmpty) return;
    final count = _selectedFiles.first.pageCount;
    for (var i = 1; i <= count; i++) {
      _pageInstructions.add(PdfPageInstruction(originalPageNumber: i));
    }
  }

  /// إعادة ترتيب صفحات الوثيقة عبر السحب والإفلات.
  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pageInstructions.length) return;
    var target = newIndex;
    if (oldIndex < target) target -= 1;
    target = target.clamp(0, _pageInstructions.length - 1);
    final page = _pageInstructions.removeAt(oldIndex);
    _pageInstructions.insert(target, page);
    notifyListeners();
  }

  /// تحديد أو إلغاء تحديد صفحة في شبكة المصغرات.
  void togglePageSelection(int index) {
    if (index < 0 || index >= _pageInstructions.length) return;
    final current = _pageInstructions[index];
    _pageInstructions[index] = current.copyWith(isSelected: !current.isSelected);
    notifyListeners();
  }

  void selectAllPages(bool selectAll) {
    for (var i = 0; i < _pageInstructions.length; i++) {
      _pageInstructions[i] = _pageInstructions[i].copyWith(isSelected: selectAll);
    }
    notifyListeners();
  }

  /// تدوير صفحة مفردة بزاوية 90 أو 180 درجة.
  void rotatePageAt(int index, int deltaDegrees) {
    if (index < 0 || index >= _pageInstructions.length) return;
    _pageInstructions[index] = _pageInstructions[index].rotateBy(deltaDegrees);
    notifyListeners();
  }

  /// تدوير جميع الصفحات المحددة بضغطة واحدة.
  void rotateSelectedPages(int deltaDegrees) {
    for (var i = 0; i < _pageInstructions.length; i++) {
      if (_pageInstructions[i].isSelected) {
        _pageInstructions[i] = _pageInstructions[i].rotateBy(deltaDegrees);
      }
    }
    notifyListeners();
  }

  /// حذف صفحة مفردة مع منع إفراغ الوثيقة بالكامل.
  void deletePageAt(int index) {
    if (_pageInstructions.length <= 1) {
      _workspaceError = 'لا يمكن حذف جميع صفحات الوثيقة. يجب الإبقاء على صفحة واحدة على الأقل.';
      notifyListeners();
      return;
    }
    _pageInstructions.removeAt(index);
    notifyListeners();
  }

  /// حذف جميع الصفحات المحددة دفعة واحدة.
  void deleteSelectedPages() {
    final remaining = _pageInstructions.where((p) => !p.isSelected).toList();
    if (remaining.isEmpty) {
      _workspaceError = 'لا يمكن حذف كافة الصفحات. أبقِ صفحة واحدة على الأقل غير محددة.';
      notifyListeners();
      return;
    }
    _pageInstructions
      ..clear()
      ..addAll(remaining);
    notifyListeners();
  }

  /// تنفيذ العملية النشطة داخل Isolate خلفي وحفظ النتيجة محلياً.
  Future<ProcessedFileRecord?> executeActiveOperation() async {
    _workspaceError = null;
    _lastCompletedRecord = null;

    if (_activeOperation == PdfOperationType.imagesToPdf) {
      if (_selectedImages.isEmpty) {
        _workspaceError = 'اختر صورة واحدة على الأقل من المعرض أو التقط وثيقة بالكاميرا أولاً.';
        notifyListeners();
        return null;
      }
    } else if (_activeOperation == PdfOperationType.merge) {
      if (_selectedFiles.length < 2) {
        _workspaceError = 'اختر ملفين على الأقل من ذاكرة الجهاز لتنفيذ عملية الدمج.';
        notifyListeners();
        return null;
      }
    } else {
      if (_selectedFiles.isEmpty) {
        _workspaceError = 'اختر ملف PDF من ذاكرة الجهاز أولاً لبدء المعالجة.';
        notifyListeners();
        return null;
      }
    }

    _isProcessing = true;
    _processingStatusText =
        'جاري تنفيذ ${_activeOperation.arabicTitle} داخل خيط معالجة معزول (Isolate)...';
    notifyListeners();

    try {
      late final ProcessedFileRecord record;

      switch (_activeOperation) {
        case PdfOperationType.merge:
          record = await _operationsRepository.mergeFiles(
            inputPaths: _selectedFiles.map((e) => e.path).toList(),
            desiredOutputName: _outputFileName,
          );
        case PdfOperationType.split:
          final primary = _selectedFiles.first;
          var pagesToExtract = <int>[];
          if (!_burstSplitEachPage) {
            final parsed = _pageRangeParser.execute(
              rawExpression: _splitRangeExpression,
              totalPages: primary.pageCount,
            );
            if (!parsed.isValid) {
              _isProcessing = false;
              _workspaceError = parsed.errorMessage;
              notifyListeners();
              return null;
            }
            pagesToExtract = parsed.pages;
          }
          record = await _operationsRepository.splitFile(
            inputPath: primary.path,
            desiredOutputName: _outputFileName,
            selectedPages: pagesToExtract,
            burstEachPageIntoSeparateFile: _burstSplitEachPage,
          );
        case PdfOperationType.organize:
          final primary = _selectedFiles.first;
          record = await _operationsRepository.organizeFilePages(
            inputPath: primary.path,
            desiredOutputName: _outputFileName,
            instructions: _pageInstructions,
          );
        case PdfOperationType.compress:
          final primary = _selectedFiles.first;
          record = await _operationsRepository.compressFile(
            inputPath: primary.path,
            desiredOutputName: _outputFileName,
            level: _compressionLevel,
          );
        case PdfOperationType.imagesToPdf:
          record = await _operationsRepository.convertImagesToPdf(
            imagePaths: _selectedImages,
            desiredOutputName: _outputFileName,
            options: _scannerOptions,
          );
      }

      _lastCompletedRecord = record;
      await initializeHistory();
      return record;
    } catch (e) {
      _workspaceError =
          'تعذر إكمال المعالجة المحلية للملف المختار. تأكد من توفر مساحة كافية على الجهاز.';
      return null;
    } finally {
      _isProcessing = false;
      _processingStatusText = '';
      notifyListeners();
    }
  }

  /// فتح ملف من السجل المحلي.
  Future<void> openProcessedFile(ProcessedFileRecord record) async {
    await OpenFilex.open(record.filePath);
  }

  /// مشاركة ملف من السجل المحلي عبر تطبيقات النظام.
  Future<void> shareProcessedFile(ProcessedFileRecord record) async {
    final file = File(record.filePath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(record.filePath)],
        text: 'ملف معالج محلياً عبر تطبيق وثيق PDF: ${record.fileName}',
      );
    }
  }

  /// إعادة تسمية ملف في السجل المحلي.
  Future<void> renameProcessedFile({
    required String id,
    required String newName,
  }) async {
    if (newName.trim().isEmpty) return;
    _recentRecords = await _historyRepository.renameRecord(
      id: id,
      newFileName: newName,
    );
    _historyState = _recentRecords.isEmpty
        ? HistoryViewState.empty
        : HistoryViewState.ready;
    notifyListeners();
  }

  /// حذف سجل ملف من العمليات الأخيرة.
  Future<void> deleteProcessedFile({
    required String id,
    bool deleteFromDisk = false,
  }) async {
    _recentRecords = await _historyRepository.deleteRecord(
      id: id,
      deleteFileFromDisk: deleteFromDisk,
    );
    _historyState = _recentRecords.isEmpty
        ? HistoryViewState.empty
        : HistoryViewState.ready;
    notifyListeners();
  }
}
