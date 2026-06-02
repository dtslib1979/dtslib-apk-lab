import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/config/app_config.dart';
import '../core/result/result.dart';

/// File lifecycle management
/// - Temp file creation with tracking
/// - Auto cleanup of old files
/// - Safe deletion with error handling
class FileManager {
  static final FileManager _instance = FileManager._();
  static FileManager get instance => _instance;
  FileManager._();

  final Set<String> _tempFiles = {};
  Directory? _cacheDir;

  /// Initialize and get cache directory
  Future<Directory> get cacheDir async {
    _cacheDir ??= await getApplicationDocumentsDirectory();
    return _cacheDir!;
  }

  /// Create temp file path with tracking
  Future<String> createTempPath({
    required String extension,
    String? prefix,
  }) async {
    final dir = await cacheDir;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = '${prefix ?? AppConfig.tempFilePrefix}$ts.$extension';
    final path = '${dir.path}/$name';

    _tempFiles.add(path);
    return path;
  }

  /// Get external storage path for recordings
  Future<Result<String>> getRecordingPath() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        return const Failure(
          '외부 저장소 접근 불가',
          code: ErrorCode.fileWriteError,
        );
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/${AppConfig.tempFilePrefix}capture_$ts.wav';
      _tempFiles.add(path);

      return Success(path);
    } catch (e) {
      return Failure(
        '저장 경로 생성 실패: $e',
        code: ErrorCode.fileWriteError,
      );
    }
  }

  /// Delete single file safely
  Future<Result<void>> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      _tempFiles.remove(path);
      return const Success(null);
    } catch (e) {
      return Failure('파일 삭제 실패: $e', code: ErrorCode.fileWriteError);
    }
  }

  /// Delete multiple files
  Future<void> deleteAll(List<String> paths) async {
    for (final path in paths) {
      await delete(path);
    }
  }

  /// Clean up all tracked temp files
  Future<int> cleanupTempFiles() async {
    int deleted = 0;
    final toDelete = List<String>.from(_tempFiles);

    for (final path in toDelete) {
      final result = await delete(path);
      if (result.isSuccess) deleted++;
    }

    return deleted;
  }

  /// Clean up old temp files (older than maxAge)
  Future<int> cleanupOldFiles() async {
    try {
      final dir = await cacheDir;
      final now = DateTime.now();
      int deleted = 0;

      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          if (name.startsWith(AppConfig.tempFilePrefix)) {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);

            if (age > AppConfig.tempFileMaxAge) {
              await entity.delete();
              deleted++;
            }
          }
        }
      }

      return deleted;
    } catch (e) {
      return 0;
    }
  }

  /// Check if file exists
  Future<bool> exists(String path) async {
    return File(path).exists();
  }

  /// Get file size in bytes
  Future<int?> getSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Format file size for display
  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
