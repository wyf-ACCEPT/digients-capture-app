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
///    `video.mp4` — and not multiples thereof). The output archive lives
///    inside the recording directory, so we skip any `.tar.gz` and
///    `.tmp.tar` siblings when walking — otherwise the build would either
///    pull the previous archive into the new one or crash on its own
///    in-flight temp.
/// 2. The temp `.tar` is then piped through `dart:io`'s streaming
///    `GZipCodec` encoder into the final `.tar.gz`. Level 1 keeps
///    `metadata.json` / `motion.jsonl` compressed but stays cheap on the
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
      if (entity is! File) continue;
      // Skip any tar.gz / tmp.tar siblings so the archive never includes
      // itself or a stale prior one. Recording bundles only ever contain
      // metadata.json / video.mp4 / motion.jsonl, so excluding all
      // `.tar.gz` / `.tmp.tar` files is safe and resilient to renames
      // (e.g. a slug change between two builds).
      final base = path.basename(entity.path);
      if (base.endsWith('.tar.gz') || base.endsWith('.tmp.tar')) continue;
      final relative = path.relative(entity.path, from: root.path);
      encoder.addFile(entity, relative);
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
    final Directory recordingsDir = Directory(path.join(documentsDir.path, 'recordings'));

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
    final Directory recordingDir = Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

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
      print('Error loading recordings: $e');
      return [];
    }
  }

  Future<void> saveRecording(Recording recording) async {
    try {
      final List<Recording> recordings = await loadRecordings();
      recordings.add(recording);

      final File recordingsFile = await _getRecordingsFile();
      final String content = jsonEncode(recordings.map((r) => r.toJson()).toList());

      await recordingsFile.writeAsString(content);
    } catch (e) {
      print('Error saving recording: $e');
    }
  }

  Future<void> deleteRecording(String sessionId) async {
    try {
      // Remove from recordings list
      final List<Recording> recordings = await loadRecordings();
      recordings.removeWhere((r) => r.sessionId == sessionId);

      final File recordingsFile = await _getRecordingsFile();
      final String content = jsonEncode(recordings.map((r) => r.toJson()).toList());
      await recordingsFile.writeAsString(content);

      // Delete the actual recording directory
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir = Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

      if (await recordingDir.exists()) {
        await recordingDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error deleting recording: $e');
    }
  }

  Future<int?> calculateRecordingSize(String sessionId) async {
    try {
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir = Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

      if (!await recordingDir.exists()) {
        return null;
      }

      // Don't double-count the cached archive — the size shown to the user
      // is the recording payload (metadata + video + motion), not the
      // tar.gz we built from it. Skip any `.tar.gz` / `.tmp.tar` siblings.
      int totalSize = 0;
      await for (final FileSystemEntity entity in recordingDir.list(recursive: true)) {
        if (entity is! File) continue;
        final base = path.basename(entity.path);
        if (base.endsWith('.tar.gz') || base.endsWith('.tmp.tar')) continue;
        final FileStat stat = await entity.stat();
        totalSize += stat.size;
      }

      return (totalSize / (1024 * 1024)).round(); // Convert to MB
    } catch (e) {
      print('Error calculating recording size: $e');
      return null;
    }
  }

  /// Canonical on-disk location of the cached tar.gz for a recording. Lives
  /// inside the recording directory so deletion of the recording removes
  /// the archive automatically. The filename is the slug
  /// (`<category>-<subSlug>-<sid>.tar.gz`) so any share sheet — even ones
  /// that read by file path and ignore XFile.name — displays the right
  /// name. Build runs once after capture stops; later shares reuse this
  /// file rather than re-tarring on every share.
  Future<String> archivePathFor(String sessionId,
      {String? categoryId, String? taskId}) async {
    final Directory recordingsDir = await _getRecordingsDirectory();
    _cachedRecordingsDir = recordingsDir;
    final slug = await shareSlugFor(
      sessionId,
      categoryId: categoryId,
      taskId: taskId,
    );
    return path.join(
      recordingsDir.path,
      'recording_$sessionId',
      '$slug.tar.gz',
    );
  }

  /// Synchronously locate any cached archive for a recording. We don't
  /// recompute the slug here — instead we list the recording directory
  /// and return the first `.tar.gz` file (a recording bundle only ever
  /// contains one). Returns null when the documents dir hasn't been
  /// resolved yet (path_provider is async on first call) or when no
  /// archive exists.
  String? findArchivePathSync(String sessionId) {
    final dir = _cachedRecordingsDir;
    if (dir == null) return null;
    final recDir =
        Directory(path.join(dir.path, 'recording_$sessionId'));
    if (!recDir.existsSync()) return null;
    try {
      for (final entity in recDir.listSync()) {
        if (entity is File && entity.path.endsWith('.tar.gz')) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Async variant for callers that already await elsewhere. Same logic
  /// as [findArchivePathSync] but resolves the recordings directory first.
  Future<String?> findArchivePath(String sessionId) async {
    final dir = await _getRecordingsDirectory();
    _cachedRecordingsDir = dir;
    final recDir = Directory(path.join(dir.path, 'recording_$sessionId'));
    if (!await recDir.exists()) return null;
    await for (final entity in recDir.list()) {
      if (entity is File && entity.path.endsWith('.tar.gz')) {
        return entity.path;
      }
    }
    return null;
  }

  Directory? _cachedRecordingsDir;

  /// If any tar.gz already exists for this recording (e.g. one named
  /// `archive.tar.gz` from a pre-rename build, or one with a stale slug
  /// after the slug logic changed), rename it to the current canonical
  /// slug name so the share sheet reads the right filename. Returns the
  /// canonical path on success, or the un-renamed existing path if the
  /// rename failed, or null if no archive exists at all.
  Future<String?> _canonicalizeExistingArchive(String sessionId) async {
    final existing = await findArchivePath(sessionId);
    if (existing == null) return null;
    final desired = await archivePathFor(sessionId);
    if (existing == desired) return existing;
    try {
      final renamed = await File(existing).rename(desired);
      return renamed.path;
    } catch (_) {
      return existing;
    }
  }

  /// Run the tar.gz build once, writing to a slug-named file inside the
  /// recording's own directory. Idempotent — if any tar.gz already exists
  /// in the recording dir this canonicalizes its name and returns it
  /// without rebuilding. The compression queue serializes builds across
  /// recordings; this method assumes no concurrent build for the same sid.
  Future<String?> buildArchive(String sessionId) async {
    try {
      final Directory recordingsDir = await _getRecordingsDirectory();
      _cachedRecordingsDir = recordingsDir;
      final Directory recordingDir =
          Directory(path.join(recordingsDir.path, 'recording_$sessionId'));
      if (!await recordingDir.exists()) {
        // Recording was deleted before its compression got scheduled —
        // not an error, just nothing to do.
        return null;
      }
      final canonical = await _canonicalizeExistingArchive(sessionId);
      if (canonical != null) return canonical;
      final String archivePath = await archivePathFor(sessionId);
      return await compute(_runExportInIsolate, <String, String>{
        'recordingDir': recordingDir.path,
        'tarGzPath': archivePath,
      });
    } catch (e) {
      print('Error building archive for $sessionId: $e');
      return null;
    }
  }

  Future<void> saveMetadata(String sessionId, RecordingMetadata metadata) async {
    try {
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir = Directory(path.join(recordingsDir.path, 'recording_$sessionId'));
      final File metadataFile = File(path.join(recordingDir.path, 'metadata.json'));

      await metadataFile.writeAsString(metadata.toJsonString());
    } catch (e) {
      print('Error saving metadata: $e');
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

  /// Public export entry point. Returns the cached archive path immediately
  /// if it already exists on disk; otherwise builds it now (legacy
  /// recordings made before auto-compression landed). Callers wanting to
  /// participate in queue ordering (so concurrent shares serialize behind
  /// pending compressions) should go through [CompressionQueue.waitForReady]
  /// instead.
  Future<String?> exportRecording(String sessionId,
      {String? categoryId, String? taskId}) async {
    try {
      // Migrate any older `archive.tar.gz` / stale-slug file in place so
      // the share sheet shows the current slug. If nothing's there yet,
      // fall through to a full build.
      final canonical = await _canonicalizeExistingArchive(sessionId);
      if (canonical != null) return canonical;
      return await buildArchive(sessionId);
    } catch (e) {
      print('Error exporting recording: $e');
      return null;
    }
  }

  /// Build the slug used as the share-displayed filename, given a recording
  /// id. Looks up category/taskId from the persisted recordings list when
  /// not passed in.
  Future<String> shareSlugFor(
    String sessionId, {
    String? categoryId,
    String? taskId,
  }) async {
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
    return _exportSlug(sessionId, resolvedCategoryId, resolvedTaskId);
  }

  Future<void> shareRecording(
    String sessionId, {
    Rect? sharePositionOrigin,
    String? categoryId,
    String? taskId,
  }) async {
    try {
      final String? archivePath =
          await exportRecording(sessionId, categoryId: categoryId, taskId: taskId);
      if (archivePath == null) {
        throw Exception('Failed to export recording');
      }
      // The on-disk file is already named with the slug, so the share
      // sheet picks up the right filename without an XFile.name override.
      final String archiveBase =
          path.basenameWithoutExtension(archivePath).replaceAll(
                RegExp(r'\.tar$'),
                '',
              );
      final XFile file = XFile(archivePath);
      await Share.shareXFiles(
        [file],
        subject: 'Egocentric Video Recording - $archiveBase',
        text: 'Egocentric video recording data package',
        sharePositionOrigin: sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      print('Error sharing recording: $e');
      rethrow;
    }
  }
}