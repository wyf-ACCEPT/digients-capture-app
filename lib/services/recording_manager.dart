import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recording.dart';

/// Top-level so it can run inside the isolate spawned by [compute]. Builds
/// the archive on disk via streaming primitives, never holding the video
/// payload in memory at once.
///
/// 1. `TarFileEncoder` walks the recording dir and writes each file
///    straight to a temp `.tar` (per-file `readAsBytesSync` is used by the
///    encoder, so peak memory is bounded by the largest single file —
///    `video.mp4` — and not multiples thereof).
/// 2. The temp `.tar` is then piped through `dart:io`'s streaming
///    `GZipCodec` encoder into the final `.tar.gz`. Level 1 keeps
///    `metadata.json` / `frames.jsonl` compressed but stays cheap on the
///    already-compressed HEVC video where higher levels would just burn
///    CPU for ~1 % gain.
/// 3. Temp `.tar` is removed.
Future<String> _runExportInIsolate(Map<String, String> params) async {
  final recordingDir = params['recordingDir']!;
  final tarGzPath = params['tarGzPath']!;

  final tarPath = '$tarGzPath.tmp.tar';

  final encoder = TarFileEncoder();
  encoder.create(tarPath);
  try {
    final root = Directory(recordingDir);
    final entities = root.listSync(recursive: true);
    entities.sort((a, b) => a.path.compareTo(b.path));
    for (final entity in entities) {
      if (entity is File) {
        final relative = path.relative(entity.path, from: root.path);
        encoder.addFile(entity, relative);
      }
    }
  } finally {
    encoder.close();
  }

  final tarFile = File(tarPath);
  final gzSink = File(tarGzPath).openWrite();
  try {
    await tarFile
        .openRead()
        .transform(GZipCodec(level: 1).encoder)
        .pipe(gzSink);
  } finally {
    if (await tarFile.exists()) {
      await tarFile.delete();
    }
  }

  return tarGzPath;
}

class RecordingManager {
  static const String _recordingsFileName = 'recordings.json';
  static const Uuid _uuid = Uuid();

  Future<Directory> _getRecordingsDirectory() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory recordingsDir =
        Directory(path.join(documentsDir.path, 'recordings'));

    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    return recordingsDir;
  }

  Future<File> _getRecordingsFile() async {
    final Directory recordingsDir = await _getRecordingsDirectory();
    return File(path.join(recordingsDir.path, _recordingsFileName));
  }

  String generateSessionId() {
    return _uuid.v4();
  }

  Future<String> createRecordingDirectory(String sessionId) async {
    final Directory recordingsDir = await _getRecordingsDirectory();
    final Directory recordingDir =
        Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }

    return recordingDir.path;
  }

  Future<List<Recording>> loadRecordings() async {
    try {
      final File recordingsFile = await _getRecordingsFile();

      if (!await recordingsFile.exists()) {
        return [];
      }

      final String content = await recordingsFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);

      return jsonList.map((json) => Recording.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading recordings: $e');
      return [];
    }
  }

  Future<void> saveRecording(Recording recording) async {
    try {
      final List<Recording> recordings = await loadRecordings();
      recordings.add(recording);

      final File recordingsFile = await _getRecordingsFile();
      final String content =
          jsonEncode(recordings.map((r) => r.toJson()).toList());

      await recordingsFile.writeAsString(content);
    } catch (e) {
      debugPrint('Error saving recording: $e');
    }
  }

  Future<void> deleteRecording(String sessionId) async {
    try {
      // Remove from recordings list
      final List<Recording> recordings = await loadRecordings();
      recordings.removeWhere((r) => r.sessionId == sessionId);

      final File recordingsFile = await _getRecordingsFile();
      final String content =
          jsonEncode(recordings.map((r) => r.toJson()).toList());
      await recordingsFile.writeAsString(content);

      // Delete the actual recording directory
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir =
          Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

      if (await recordingDir.exists()) {
        await recordingDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  Future<int?> calculateRecordingSize(String sessionId) async {
    try {
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir =
          Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

      if (!await recordingDir.exists()) {
        return null;
      }

      int totalSize = 0;
      await for (final FileSystemEntity entity
          in recordingDir.list(recursive: true)) {
        if (entity is File) {
          final FileStat stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return (totalSize / (1024 * 1024)).round(); // Convert to MB
    } catch (e) {
      debugPrint('Error calculating recording size: $e');
      return null;
    }
  }

  Future<void> saveMetadata(
      String sessionId, RecordingMetadata metadata) async {
    try {
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir =
          Directory(path.join(recordingsDir.path, 'recording_$sessionId'));
      final File metadataFile =
          File(path.join(recordingDir.path, 'metadata.json'));

      await metadataFile.writeAsString(metadata.toJsonString());
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  // Build the export-facing slug for a recording. Used as the outer archive
  // basename so the file the user shares encodes both scene and sub-task.
  // Task IDs follow the convention `<2-letter-prefix>-<action-slug>` (e.g.
  // `br-fold-clothes-multi`); we strip the prefix so the category is not
  // double-encoded. Falls back gracefully when fields are missing on
  // recordings persisted before this scheme.
  String _exportSlug(String sessionId, String? categoryId, String? taskId) {
    String? subSlug;
    if (taskId != null && taskId.isNotEmpty) {
      // Match exactly the 2-letter category abbrev + dash (lr-, br-, kt-,
      // bt-, cs-). Tasks that don't follow this convention pass through
      // unchanged.
      final match = RegExp(r'^[a-z]{2}-').firstMatch(taskId);
      subSlug = match != null ? taskId.substring(match.end) : taskId;
    }
    final hasCategory = categoryId != null && categoryId.isNotEmpty;
    final hasSub = subSlug != null && subSlug.isNotEmpty;
    if (hasCategory && hasSub) return '$categoryId-$subSlug-$sessionId';
    if (hasCategory) return '$categoryId-$sessionId';
    return sessionId;
  }

  Future<String?> exportRecording(String sessionId,
      {String? categoryId, String? taskId}) async {
    try {
      // If caller didn't pass categoryId / taskId, look them up from the
      // persisted recordings list. This keeps export call sites simple.
      String? resolvedCategoryId = categoryId;
      String? resolvedTaskId = taskId;
      if (resolvedCategoryId == null || resolvedTaskId == null) {
        final List<Recording> all = await loadRecordings();
        for (final r in all) {
          if (r.sessionId == sessionId) {
            resolvedCategoryId ??= r.categoryId;
            resolvedTaskId ??= r.taskId;
            break;
          }
        }
      }

      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir =
          Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

      if (!await recordingDir.exists()) {
        debugPrint('Recording directory does not exist: $sessionId');
        return null;
      }

      final String slug =
          _exportSlug(sessionId, resolvedCategoryId, resolvedTaskId);

      final Directory tempDir = await getTemporaryDirectory();
      final String archivePath = path.join(tempDir.path, '$slug.tar.gz');

      // Only the outer archive name encodes the category — the inner layout
      // (video.mp4 / metadata.json / frames.jsonl) stays unchanged so the
      // ego-pose-post-process pipeline and validator (which both hard-code
      // "video.mp4") keep working.
      //
      // The actual archive build runs on a background isolate so the UI
      // thread doesn't freeze for tens of seconds on long recordings — a
      // 240 s bathroom clip is ~450 MB, large enough that the previous
      // in-memory tar+gzip pipeline could OOM the app on mid-tier phones.
      return await compute(_runExportInIsolate, <String, String>{
        'recordingDir': recordingDir.path,
        'tarGzPath': archivePath,
      });
    } catch (e) {
      debugPrint('Error exporting recording: $e');
      return null;
    }
  }

  Future<void> shareRecording(String sessionId,
      {Rect? sharePositionOrigin, String? categoryId, String? taskId}) async {
    try {
      final String? archivePath = await exportRecording(sessionId,
          categoryId: categoryId, taskId: taskId);

      if (archivePath == null) {
        throw Exception('Failed to export recording');
      }

      // Strip both ".gz" and ".tar" so the share subject reads `<slug>` not
      // `<slug>.tar`.
      final String archiveBase =
          path.basename(archivePath).replaceAll(RegExp(r'\.tar\.gz$'), '');

      final XFile file = XFile(archivePath);
      await Share.shareXFiles(
        [file],
        subject: 'Egocentric Video Recording - $archiveBase',
        text: 'Egocentric video recording data package',
        sharePositionOrigin:
            sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      debugPrint('Error sharing recording: $e');
      rethrow;
    }
  }
}
