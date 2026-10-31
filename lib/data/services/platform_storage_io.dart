import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// طبقة التجريد الخاصة بنظام الملفات والخيوط للأندرويد وiOS وسطح المكتب.
class PlatformStorage {
  const PlatformStorage._();

  static Future<T> runTask<T>(T Function() computation) {
    return Isolate.run(computation);
  }

  static Uint8List readBytesSync(String path) {
    return File(path).readAsBytesSync();
  }

  static void writeBytesSync(String path, List<int> bytes) {
    File(path).writeAsBytesSync(bytes, flush: true);
  }

  static Future<String> registerPickedBytes({
    required String fileName,
    required String? nativePath,
    required Uint8List bytes,
  }) async {
    if (nativePath != null && nativePath.isNotEmpty) {
      final f = File(nativePath);
      if (await f.exists()) {
        return nativePath;
      }
    }
    final tempDir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^\w\u0600-\u06FF\.\-]'), '_');
    final outPath =
        '${tempDir.path}/wathiq_work_${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await File(outPath).writeAsBytes(bytes, flush: true);
    return outPath;
  }

  static Future<String> resolveOutputDirPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final wathiqDir = Directory('${docsDir.path}/Wathiq_PDF');
    if (!await wathiqDir.exists()) {
      await wathiqDir.create(recursive: true);
    }
    return wathiqDir.path;
  }

  static Future<int> purgeTemporaryFiles({
    List<String> trackedPaths = const [],
  }) async {
    var freedBytes = 0;

    for (final rawPath in trackedPaths) {
      if (rawPath.isEmpty) continue;
      final file = File(rawPath);
      if (await file.exists()) {
        try {
          freedBytes += await file.length();
          await file.delete();
        } on FileSystemException {
          // قد يكون الملف محذوفاً مسبقاً من نظام التشغيل.
        }
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: false)) {
          if (entity is File &&
              (entity.path.endsWith('.tmp') ||
                  entity.path.contains('wathiq_work_') ||
                  entity.path.contains('cunning_scanner'))) {
            try {
              freedBytes += await entity.length();
              await entity.delete();
            } on FileSystemException {
              // نتجاوز الملفات المقفلة من النظام.
            }
          }
        }
      }
    } on MissingPlatformDirectoryException {
      // في بيئة الاختبار قد لا يتوفر مجلد مؤقت للنظام.
    }

    return freedBytes;
  }

  static Future<String> renameFileIfPossible(
    String currentPath,
    String sanitizedName,
  ) async {
    final existingFile = File(currentPath);
    if (await existingFile.exists()) {
      final parentDir = existingFile.parent.path;
      final candidatePath = '$parentDir/$sanitizedName';
      try {
        final renamed = await existingFile.rename(candidatePath);
        return renamed.path;
      } on FileSystemException {
        return currentPath;
      }
    }
    return currentPath;
  }

  static Future<void> deleteFileIfPossible(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // تجاهل أخطاء الحذف إذا نُقل الملف خارجياً.
      }
    }
  }

  static Future<void> openFile(String path, String fileName) async {
    await OpenFilex.open(path);
  }

  static Future<void> shareFile(String path, String fileName) async {
    final file = File(path);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(path)], text: fileName);
    }
  }

  static Widget buildImageThumbnail(String path) {
    return Image.file(
      File(path),
      width: 76,
      height: 92,
      fit: BoxFit.cover,
    );
  }
}
