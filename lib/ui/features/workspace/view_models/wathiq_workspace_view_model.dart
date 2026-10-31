import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../data/repositories/local_history_repository.dart';
import '../../../../data/repositories/pdf_operations_repository.dart';
import '../../../../data/services/pdf_isolate_service.dart';
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

/// حالات تحميل وعرض سجل العمليات الأخيرة.
enum HistoryViewState {
  loading,
  empty,
  ready,
  error,
}

/// ViewModel الرئيسي لإدارة حالة تطبيق "وثيق PDF" لجميع الأدوات (26 أداة).
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
  List<SelectedInputFile> get selectedFiles =>
      List.unmodifiable(_selectedFiles);

  final List<String> _selectedImages = [];
  List<String> get selectedImages => List.unmodifiable(_selectedImages);

  final List<PdfPageInstruction> _pageInstructions = [];
  List<PdfPageInstruction> get pageInstructions =>
      List.unmodifiable(_pageInstructions);

  CompressionLevel _compressionLevel = CompressionLevel.medium;
  CompressionLevel get compressionLevel => _compressionLevel;

  ScannerToPdfOptions _scannerOptions = const ScannerToPdfOptions();
  ScannerToPdfOptions get scannerOptions => _scannerOptions;

  String _splitRangeExpression = '1-3';
  String get splitRangeExpression => _splitRangeExpression;

  bool _burstSplitEachPage = false;
  bool get burstSplitEachPage => _burstSplitEachPage;

  int _bulkRotationDegrees = 90;
  int get bulkRotationDegrees => _bulkRotationDegrees;

  PageNumberPosition _pageNumberPosition = PageNumberPosition.bottomCenter;
  PageNumberPosition get pageNumberPosition => _pageNumberPosition;

  String _watermarkOrEditText = 'سري للغاية';
  String get watermarkOrEditText => _watermarkOrEditText;

  double _watermarkOpacity = 0.35;
  double get watermarkOpacity => _watermarkOpacity;

  String _pdfPassword = '';
  String get pdfPassword => _pdfPassword;

  String _createPdfTitle = 'مستند جديد';
  String get createPdfTitle => _createPdfTitle;

  String _createPdfBody = '';
  String get createPdfBody => _createPdfBody;

  final List<Offset?> _signaturePoints = [];
  List<Offset?> get signaturePoints => List.unmodifiable(_signaturePoints);

  String _outputFileName = 'وثيقة.pdf';
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
  List<ProcessedFileRecord> get recentRecords =>
      List.unmodifiable(_recentRecords);

  int get totalSelectedBytes =>
      _selectedFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  int get totalSelectedPages =>
      _selectedFiles.fold(0, (sum, item) => sum + item.pageCount);

  int get estimatedCompressedBytes {
    if (totalSelectedBytes <= 0) return 0;
    return (totalSelectedBytes * _compressionLevel.expectedRatio).round();
  }

  bool get hasRequiredInput {
    return switch (_activeOperation.inputKind) {
      PdfOperationInputKind.multiplePdfs => _selectedFiles.length >= 2,
      PdfOperationInputKind.singlePdf => _selectedFiles.isNotEmpty,
      PdfOperationInputKind.images => _selectedImages.isNotEmpty,
      PdfOperationInputKind.none => _createPdfBody.trim().isNotEmpty ||
          _createPdfTitle.trim().isNotEmpty,
    };
  }

  Future<void> initializeHistory() async {
    _historyState = HistoryViewState.loading;
    _historyErrorMessage = null;
    notifyListeners();

    try {
      _recentRecords = await _historyRepository.loadRecentRecords();
      _historyState = _recentRecords.isEmpty
          ? HistoryViewState.empty
          : HistoryViewState.ready;
    } catch (_) {
      _historyState = HistoryViewState.error;
      _historyErrorMessage = 'تعذرت قراءة السجل المحلي.';
    }
    notifyListeners();
  }

  void toggleThemeMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void selectOperation(PdfOperationType operation) {
    _activeOperation = operation;
    _workspaceError = null;
    _selectedFiles.clear();
    _selectedImages.clear();
    _pageInstructions.clear();
    _signaturePoints.clear();
    final stamp = '${DateTime.now().hour}${DateTime.now().minute}';
    _outputFileName =
        '${operation.shortActionLabel.replaceAll(' ', '_')}_$stamp';
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

  void setBulkRotationDegrees(int degrees) {
    _bulkRotationDegrees = degrees;
    notifyListeners();
  }

  void setPageNumberPosition(PageNumberPosition position) {
    _pageNumberPosition = position;
    notifyListeners();
  }

  void setWatermarkOrEditText(String value) {
    _watermarkOrEditText = value;
    notifyListeners();
  }

  void setWatermarkOpacity(double value) {
    _watermarkOpacity = value;
    notifyListeners();
  }

  void setPdfPassword(String value) {
    _pdfPassword = value;
    notifyListeners();
  }

  void setCreatePdfTitle(String value) {
    _createPdfTitle = value;
    notifyListeners();
  }

  void setCreatePdfBody(String value) {
    _createPdfBody = value;
    notifyListeners();
  }

  void addSignaturePoint(Offset? point) {
    _signaturePoints.add(point);
    notifyListeners();
  }

  void clearSignature() {
    _signaturePoints.clear();
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

  /// اختيار ملف أو عدة ملفات (PDF أو أوفيس حسب الأداة المختارة).
  Future<void> pickPdfFiles({bool allowMultiple = true}) async {
    _workspaceError = null;
    try {
      const extensions = ['pdf'];
      final List<PlatformFile> pickedFiles;
      if (allowMultiple) {
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: extensions,
        );
      } else {
        final single = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: extensions,
        );
        pickedFiles = single != null
            ? <PlatformFile>[single]
            : const <PlatformFile>[];
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
        if (path.toLowerCase().endsWith('.pdf')) {
          try {
            final doc = PdfDocument(inputBytes: bytes);
            pagesCount = doc.pages.count;
            doc.dispose();
          } catch (_) {
            pagesCount = 1;
          }
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
    } catch (_) {
      _workspaceError = 'تعذر استيراد الملف المختار.';
      notifyListeners();
    }
  }

  /// استيراد صور من المعرض.
  Future<void> pickImagesFromGallery() async {
    _workspaceError = null;
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage();
      if (pickedList.isEmpty) return;
      for (final imgFile in pickedList) {
        _selectedImages.add(imgFile.path);
      }
      notifyListeners();
    } catch (_) {
      _workspaceError = 'تعذر الوصول إلى معرض الصور.';
      notifyListeners();
    }
  }

  /// التقاط صورة بالكاميرا.
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
      notifyListeners();
    } catch (_) {
      _workspaceError = 'تعذر تشغيل الكاميرا.';
      notifyListeners();
    }
  }

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

  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pageInstructions.length) return;
    var target = newIndex;
    if (oldIndex < target) target -= 1;
    target = target.clamp(0, _pageInstructions.length - 1);
    final page = _pageInstructions.removeAt(oldIndex);
    _pageInstructions.insert(target, page);
    notifyListeners();
  }

  void togglePageSelection(int index) {
    if (index < 0 || index >= _pageInstructions.length) return;
    final current = _pageInstructions[index];
    _pageInstructions[index] =
        current.copyWith(isSelected: !current.isSelected);
    notifyListeners();
  }

  void rotatePageAt(int index, int deltaDegrees) {
    if (index < 0 || index >= _pageInstructions.length) return;
    _pageInstructions[index] = _pageInstructions[index].rotateBy(deltaDegrees);
    notifyListeners();
  }

  void rotateSelectedPages(int deltaDegrees) {
    for (var i = 0; i < _pageInstructions.length; i++) {
      if (_pageInstructions[i].isSelected) {
        _pageInstructions[i] = _pageInstructions[i].rotateBy(deltaDegrees);
      }
    }
    notifyListeners();
  }

  void deletePageAt(int index) {
    if (_pageInstructions.length <= 1) {
      _workspaceError = 'يجب الإبقاء على صفحة واحدة على الأقل.';
      notifyListeners();
      return;
    }
    _pageInstructions.removeAt(index);
    notifyListeners();
  }

  void deleteSelectedPages() {
    final remaining = _pageInstructions.where((p) => !p.isSelected).toList();
    if (remaining.isEmpty) {
      _workspaceError = 'أبقِ صفحة واحدة على الأقل غير محددة.';
      notifyListeners();
      return;
    }
    _pageInstructions
      ..clear()
      ..addAll(remaining);
    notifyListeners();
  }

  /// تنفيذ الأداة النشطة وحفظ النتيجة محلياً.
  Future<ProcessedFileRecord?> executeActiveOperation() async {
    _workspaceError = null;
    _lastCompletedRecord = null;

    if (!hasRequiredInput) {
      _workspaceError = 'يرجى استكمال المدخلات المطلوبة أولاً.';
      notifyListeners();
      return null;
    }

    if (_activeOperation == PdfOperationType.protectPdf &&
        _pdfPassword.trim().isEmpty) {
      _workspaceError = 'أدخل كلمة المرور لحماية الملف.';
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    _processingStatusText = 'جارٍ تنفيذ ${_activeOperation.arabicTitle}...';
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
          record = await _operationsRepository.organizeFilePages(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            instructions: _pageInstructions,
          );

        case PdfOperationType.rotatePdf:
          record = await _operationsRepository.rotateFile(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            rotationDegrees: _bulkRotationDegrees,
          );

        case PdfOperationType.compress:
          record = await _operationsRepository.compressFile(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            level: _compressionLevel,
          );

        case PdfOperationType.imagesToPdf:
          record = await _operationsRepository.convertImagesToPdf(
            imagePaths: _selectedImages,
            desiredOutputName: _outputFileName,
            options: _scannerOptions,
          );

        case PdfOperationType.pageNumbers:
          record = await _operationsRepository.addPageNumbers(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            position: _pageNumberPosition,
          );

        case PdfOperationType.watermark:
          final png = await _operationsRepository.renderOverlayPng(
            text: _watermarkOrEditText,
            diagonal: true,
          );
          record = await _operationsRepository.stampTextOrSignatureOnPdf(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            operationType: PdfOperationType.watermark,
            overlayPngBytes: png,
            opacity: _watermarkOpacity,
            allPages: true,
            centerDiagonal: true,
          );

        case PdfOperationType.editPdf:
          final png = await _operationsRepository.renderOverlayPng(
            text: _watermarkOrEditText,
            diagonal: false,
          );
          record = await _operationsRepository.stampTextOrSignatureOnPdf(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            operationType: PdfOperationType.editPdf,
            overlayPngBytes: png,
            opacity: 1.0,
            allPages: false,
            centerDiagonal: false,
          );

        case PdfOperationType.signPdf:
          final png = await _operationsRepository.renderOverlayPng(
            text: _watermarkOrEditText.isEmpty ? 'توقيع معتمد' : _watermarkOrEditText,
            signaturePoints: _signaturePoints,
            diagonal: false,
          );
          record = await _operationsRepository.stampTextOrSignatureOnPdf(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            operationType: PdfOperationType.signPdf,
            overlayPngBytes: png,
            opacity: 1.0,
            allPages: false,
            centerDiagonal: false,
          );

        case PdfOperationType.protectPdf:
          record = await _operationsRepository.protectFile(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            password: _pdfPassword,
          );

        case PdfOperationType.unlockPdf:
          record = await _operationsRepository.unlockFile(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
            password: _pdfPassword,
          );

        case PdfOperationType.repairPdf:
          record = await _operationsRepository.repairFile(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
          );

        case PdfOperationType.extractText:
          record = await _operationsRepository.extractText(
            inputPath: _selectedFiles.first.path,
            desiredOutputName: _outputFileName,
          );

        case PdfOperationType.createPdf:
          record = await _operationsRepository.createOrConvertTextToPdf(
            title: _createPdfTitle,
            bodyText: _createPdfBody,
            desiredOutputName: _outputFileName,
            operationType: PdfOperationType.createPdf,
          );

      }

      _lastCompletedRecord = record;
      await initializeHistory();
      return record;
    } catch (_) {
      _workspaceError =
          'تعذر إكمال المعالجة. تحقق من صلاحية الملف أو كلمة المرور.';
      return null;
    } finally {
      _isProcessing = false;
      _processingStatusText = '';
      notifyListeners();
    }
  }

  Future<void> openProcessedFile(ProcessedFileRecord record) async {
    await OpenFilex.open(record.filePath);
  }

  Future<void> shareProcessedFile(ProcessedFileRecord record) async {
    final file = File(record.filePath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(record.filePath)],
        text: record.fileName,
      );
    }
  }

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
