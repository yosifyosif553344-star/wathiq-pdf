import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

@JS('document')
external _DomDocument get _document;

@JS('URL')
external _DomUrl get _url;

@JS('Blob')
extension type _DomBlob._(JSObject _) implements JSObject {
  external factory _DomBlob(JSArray<JSAny?> blobParts);
}

extension type _DomDocument(JSObject _) implements JSObject {
  external _AnchorElement createElement(JSString tagName);
}

extension type _DomUrl(JSObject _) implements JSObject {
  external JSString createObjectURL(_DomBlob blob);
  external void revokeObjectURL(JSString url);
}

extension type _AnchorElement(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
}

/// طبقة التجريد الخاصة بمتصفح الويب (Flutter Web) بدون الحاجة إلى dart:io أو خادم خارجي.
class PlatformStorage {
  const PlatformStorage._();

  static final Map<String, Uint8List> _memoryStore = <String, Uint8List>{};

  static Future<T> runTask<T>(T Function() computation) {
    return Future<T>.delayed(Duration.zero, computation);
  }

  static Uint8List readBytesSync(String path) {
    final bytes = _memoryStore[path];
    if (bytes == null) {
      throw StateError('الملف غير موجود في الذاكرة المؤقتة للمتصفح: $path');
    }
    return bytes;
  }

  static void writeBytesSync(String path, List<int> bytes) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    _memoryStore[path] = data;
    final fileName = path.split('/').last;
    _triggerBrowserDownload(fileName, data);
  }

  static Future<String> registerPickedBytes({
    required String fileName,
    required String? nativePath,
    required Uint8List bytes,
  }) async {
    final vPath =
        '/wathiq_web_in/${DateTime.now().microsecondsSinceEpoch}_$fileName';
    _memoryStore[vPath] = bytes;
    return vPath;
  }

  static Future<String> resolveOutputDirPath() async {
    return '/wathiq_web_out';
  }

  static Future<int> purgeTemporaryFiles({
    List<String> trackedPaths = const [],
  }) async {
    for (final p in trackedPaths) {
      _memoryStore.remove(p);
    }
    return 0;
  }

  static Future<String> renameFileIfPossible(
    String currentPath,
    String sanitizedName,
  ) async {
    final existing = _memoryStore.remove(currentPath);
    final newPath = '/wathiq_web_out/$sanitizedName';
    if (existing != null) {
      _memoryStore[newPath] = existing;
    }
    return newPath;
  }

  static Future<void> deleteFileIfPossible(String path) async {
    _memoryStore.remove(path);
  }

  static Future<void> openFile(String path, String fileName) async {
    final bytes = _memoryStore[path];
    if (bytes != null) {
      _triggerBrowserDownload(fileName, bytes);
    }
  }

  static Future<void> shareFile(String path, String fileName) async {
    final bytes = _memoryStore[path];
    if (bytes != null) {
      _triggerBrowserDownload(fileName, bytes);
    }
  }

  static Widget buildImageThumbnail(String path) {
    final bytes = _memoryStore[path];
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: 76,
        height: 92,
        fit: BoxFit.cover,
      );
    }
    return const SizedBox(width: 76, height: 92);
  }

  static void _triggerBrowserDownload(String fileName, Uint8List bytes) {
    try {
      final parts = <JSAny?>[bytes.toJS].toJS;
      final blob = _DomBlob(parts);
      final objectUrl = _url.createObjectURL(blob);
      final anchor = _document.createElement('a'.toJS);
      anchor.href = objectUrl;
      anchor.download = fileName.toJS;
      anchor.click();
      Future<void>.delayed(const Duration(seconds: 15), () {
        _url.revokeObjectURL(objectUrl);
      });
    } catch (_) {
      final mime = fileName.toLowerCase().endsWith('.txt')
          ? 'text/plain;charset=utf-8'
          : 'application/pdf';
      final b64 = base64Encode(bytes);
      final anchor = _document.createElement('a'.toJS);
      anchor.href = 'data:$mime;base64,$b64'.toJS;
      anchor.download = fileName.toJS;
      anchor.click();
    }
  }
}
