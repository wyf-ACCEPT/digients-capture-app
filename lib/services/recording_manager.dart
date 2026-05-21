import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/recording.dart';

// Cross-isolate request for [_runExportIsolate]. Carries the input paths
// and the SendPort the worker uses to push progress / done / error
// messages back to the main isolate.
class _ExportRequest {
  final String recordingDir;
  final String tarGzPath;
  final SendPort sendPort;
  _ExportRequest({
    required this.recordingDir,
    required this.tarGzPath,
    required this.sendPort,
  });
}

/// Top-level isolate entry. Does a *single-pass* tar+gzip build of the
/// recording directory, emitting byte-level progress over [req.sendPort]
/// throttled to 10 Hz. Replaces the older two-pass implementation that
/// wrote a full temp `.tar` to disk and then re-read it through gzip —
/// the new path runs ~30 % faster on multi-GB takes and avoids the temp
/// file altogether.
///
/// Output flow:
///   raw tar bytes (header + streamed file body + padding)
///     -> ChunkedConversionSink (GZipCodec level 1 encoder)
///     -> ByteConversionSink (over IOSink)
///     -> on-disk `.tar.gz` file
///
/// Tar format: minimal USTAR. Recording bundles only contain
/// `metadata.json`, `video.mp4`, `motion.jsonl` (and optionally
/// `thumbnail.jpg`), all with paths short enough to fit in the 100-byte
/// name field, so we don't need the GNU long-name extension.
///
/// Compression level 1: cheap on the already-compressed HEVC video where
/// higher levels would just burn CPU for ~1 % gain; still effective on
/// `metadata.json` / `motion.jsonl`.
///
/// Messages on [req.sendPort]:
///   { 'type': 'progress', 'fraction': 0.0..1.0 }   — source bytes done
///   { 'type': 'done',     'path': '<absolute>' }   — terminal success
///   { 'type': 'error',    'message': '<text>' }    — terminal failure
Future<void> _runExportIsolate(_ExportRequest req) async {
  try {
    final root = Directory(req.recordingDir);
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          // Skip any tar.gz / tmp.tar siblings so the archive never
          // includes itself or a stale prior one. Recording bundles only
          // ever contain metadata.json / video.mp4 / motion.jsonl /
          // thumbnail.jpg, so excluding all `.tar.gz` / `.tmp.tar` files
          // is safe and resilient to renames.
          final base = path.basename(f.path);
          return !base.endsWith('.tar.gz') && !base.endsWith('.tmp.tar');
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final totalBytes = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    if (totalBytes == 0) {
      req.sendPort
          .send({'type': 'error', 'message': 'No files to archive'});
      return;
    }

    final destination = File(req.tarGzPath).openWrite();
    final gzSink = GZipCodec(level: 1)
        .encoder
        .startChunkedConversion(ByteConversionSink.from(destination));

    int processedBytes = 0;
    var lastEmitMs = 0;

    void emitProgress({bool force = false}) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!force && nowMs - lastEmitMs < 100) return;
      lastEmitMs = nowMs;
      final fraction = (processedBytes / totalBytes).clamp(0.0, 1.0);
      req.sendPort.send({'type': 'progress', 'fraction': fraction});
    }

    emitProgress(force: true); // baseline 0 %

    // 1024 zeros = max padding (512) + reused for the two-block
    // end-of-archive marker (also 1024). Reuse to avoid extra allocs.
    final zeroBlock = Uint8List(1024);

    for (final file in files) {
      final relative = path.relative(file.path, from: root.path);
      final size = await file.length();
      final stat = await file.stat();

      gzSink.add(_buildUstarHeader(
        name: relative,
        size: size,
        mtime: stat.modified.millisecondsSinceEpoch ~/ 1000,
        mode: stat.mode & 0xfff,
      ));

      await for (final chunk in file.openRead()) {
        gzSink.add(chunk);
        processedBytes += chunk.length;
        emitProgress();
      }

      final remainder = size % 512;
      if (remainder != 0) {
        gzSink.add(zeroBlock.sublist(0, 512 - remainder));
      }
    }

    // End-of-archive marker: two consecutive 512-byte zero blocks.
    gzSink.add(zeroBlock);

    gzSink.close(); // flushes pending gzip output to destination
    await destination.close();

    emitProgress(force: true); // final 100 %
    req.sendPort.send({'type': 'done', 'path': req.tarGzPath});
  } catch (e, st) {
    req.sendPort.send({'type': 'error', 'message': '$e\n$st'});
  }
}

/// Build a 512-byte USTAR header for a regular file. Caller must ensure
/// [name] is ≤ 100 bytes when UTF-8 encoded — recording bundle filenames
/// always are.
Uint8List _buildUstarHeader({
  required String name,
  required int size,
  required int mtime,
  required int mode,
}) {
  final h = Uint8List(512);

  final nameBytes = utf8.encode(name);
  if (nameBytes.length > 100) {
    throw Exception(
        'Path too long for USTAR header (${nameBytes.length} > 100): $name');
  }
  h.setRange(0, nameBytes.length, nameBytes);

  // Write an unsigned int as a zero-padded, null-terminated octal field
  // of [width] bytes (the trailing null is included in [width]).
  void writeOctal(int offset, int width, int value) {
    final str = value.toRadixString(8).padLeft(width - 1, '0');
    final bytes = ascii.encode(str);
    h.setRange(offset, offset + bytes.length, bytes);
    h[offset + bytes.length] = 0;
  }

  writeOctal(100, 8, mode);
  writeOctal(108, 8, 0); // uid
  writeOctal(116, 8, 0); // gid
  writeOctal(124, 12, size);
  writeOctal(136, 12, mtime);

  // Checksum field starts as 8 spaces while the checksum is computed.
  for (var i = 148; i < 156; i++) {
    h[i] = 0x20;
  }

  h[156] = 0x30; // typeflag '0' = regular file
  // linkname (100 B at 157), uname/gname (32 B each at 265/297),
  // devmajor/devminor (8 B each at 329/337), prefix (155 B at 345)
  // all left zero — fine for our short, single-file-typed bundle.

  // POSIX USTAR magic at 257-262: 'ustar' + NUL.
  // Version at 263-264: '00' (two ASCII zeros).
  // Written via explicit byte writes (not an embedded NUL in a string
  // literal) so the source file stays text in git's eyes — otherwise a
  // single embedded \x00 flips diff rendering to binary for the whole
  // file.
  h.setRange(257, 262, ascii.encode('ustar'));
  h[262] = 0;
  h[263] = 0x30;
  h[264] = 0x30;

  var checksum = 0;
  for (final b in h) {
    checksum += b;
  }
  // Checksum format is non-standard: 6-digit zero-padded octal, then
  // NUL, then space (not the more uniform "octal + NUL" pattern used by
  // the other numeric fields).
  final chkBytes = ascii.encode(checksum.toRadixString(8).padLeft(6, '0'));
  h.setRange(148, 148 + chkBytes.length, chkBytes);
  h[154] = 0;
  h[155] = 0x20;

  return h;
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

      // Don't double-count the cached archive — the size shown to the user
      // is the recording payload (metadata + video + motion), not the
      // tar.gz we built from it. Skip any `.tar.gz` / `.tmp.tar` siblings.
      int totalSize = 0;
      await for (final FileSystemEntity entity
          in recordingDir.list(recursive: true)) {
        if (entity is! File) continue;
        final base = path.basename(entity.path);
        if (base.endsWith('.tar.gz') || base.endsWith('.tmp.tar')) continue;
        final FileStat stat = await entity.stat();
        totalSize += stat.size;
      }

      return (totalSize / (1024 * 1024)).round(); // Convert to MB
    } catch (e) {
      debugPrint('Error calculating recording size: $e');
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

  // Static so it's shared across every fresh RecordingManager() instance.
  // Many call sites (UI cards, services) construct a new instance on each
  // use because the class is stateless apart from this cache; without
  // `static` the *first* sync lookup from a freshly-built widget always
  // returned null and the lazy thumbnail rebuild never landed.
  static Directory? _cachedRecordingsDir;

  // Thumbnail = first frame of video.mp4 saved alongside metadata. ~10–30 KB
  // and survives the post-compression cleanup of the raw video, so the
  // submissions list always has a preview to render.
  static const String _thumbnailFilename = 'thumbnail.jpg';

  Future<String> thumbnailPathFor(String sessionId) async {
    final Directory recordingsDir = await _getRecordingsDirectory();
    _cachedRecordingsDir = recordingsDir;
    return path.join(
      recordingsDir.path,
      'recording_$sessionId',
      _thumbnailFilename,
    );
  }

  /// Synchronous existence check + path. Returns null when the thumbnail
  /// hasn't been generated yet (or when path_provider hasn't been awaited
  /// once at app start). Submissions list uses this in build() so cards
  /// can decide between Image.file and a placeholder without an async hop.
  String? thumbnailPathSync(String sessionId) {
    final dir = _cachedRecordingsDir;
    if (dir == null) return null;
    final p = path.join(dir.path, 'recording_$sessionId', _thumbnailFilename);
    return File(p).existsSync() ? p : null;
  }

  /// Extract the first frame of video.mp4 to a JPEG. Idempotent — returns
  /// the existing path if a thumbnail is already on disk. Returns null if
  /// the source video isn't available (e.g. compression cleanup ran first
  /// in some edge case, or the recording was deleted).
  Future<String?> ensureThumbnail(String sessionId) async {
    final Directory recordingsDir = await _getRecordingsDirectory();
    _cachedRecordingsDir = recordingsDir;
    final recDir =
        Directory(path.join(recordingsDir.path, 'recording_$sessionId'));
    if (!await recDir.exists()) return null;
    final thumbPath = path.join(recDir.path, _thumbnailFilename);
    if (await File(thumbPath).exists()) return thumbPath;
    final videoPath = path.join(recDir.path, 'video.mp4');
    if (!await File(videoPath).exists()) return null;
    try {
      // 320 px wide max keeps the file small (~10–30 KB) and the platform
      // call fast (~100 ms). The list cards downsample further; quality
      // beyond this is wasted bytes.
      final result = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        timeMs: 0,
        quality: 75,
      );
      if (result == null) return null;
      return result;
    } catch (e) {
      print('Error generating thumbnail for $sessionId: $e');
      return null;
    }
  }

  /// Absolute path to the recording's directory on disk. Idempotent
  /// directory create — safe to call before the native recorder has
  /// written anything. Used by callers (UploadController, etc.) that
  /// need to address files by FileKind without re-implementing the
  /// `recording_<sid>` path scheme.
  Future<String> recordingDirFor(String sessionId) async {
    final Directory recordingsDir = await _getRecordingsDirectory();
    _cachedRecordingsDir = recordingsDir;
    return path.join(recordingsDir.path, 'recording_$sessionId');
  }

  /// After a successful upload, remove the loose `metadata.json`,
  /// `video.mp4`, and `motion.jsonl` so the recording dir holds only
  /// the thumbnail (for UI preview). Frees ~99% of the recording's disk
  /// footprint while keeping the card preview alive.
  ///
  /// Unlike the v1 [cleanupOriginalsAfterCompression] this does NOT
  /// require a tar.gz to exist — under the /v2 multi-file pipeline the
  /// originals were uploaded directly. Defensive: requires the thumbnail
  /// to be on disk, otherwise we leave everything intact so a retry can
  /// still find the source files.
  ///
  /// Side effect for the share path: once originals are gone, a later
  /// "share" of this recording can't lazy-build a tar.gz. Acceptable
  /// trade-off — share is a pre-upload fallback by design (plan 6e19
  /// §2.2). Submission_detail short-circuits with a clear toast.
  Future<void> cleanupOriginalsAfterUpload(String sessionId) async {
    try {
      final thumb = await thumbnailPathFor(sessionId);
      if (!await File(thumb).exists()) return;
      final Directory recordingsDir = await _getRecordingsDirectory();
      final recDir =
          Directory(path.join(recordingsDir.path, 'recording_$sessionId'));
      if (!await recDir.exists()) return;
      for (final name in const ['metadata.json', 'video.mp4', 'motion.jsonl']) {
        final f = File(path.join(recDir.path, name));
        if (await f.exists()) {
          try { await f.delete(); } catch (_) {}
        }
      }
    } catch (e) {
      print('Error cleaning up originals for $sessionId: $e');
    }
  }

  /// True when [sessionId]'s raw source files (video / metadata / motion)
  /// still live on disk. Used by the share path to decide whether a
  /// lazy tar.gz build is possible — after [cleanupOriginalsAfterUpload]
  /// has run, only the thumbnail remains and share is unavailable.
  bool hasOriginalsSync(String sessionId) {
    final dir = _cachedRecordingsDir;
    if (dir == null) return false;
    final recDir = Directory(path.join(dir.path, 'recording_$sessionId'));
    if (!recDir.existsSync()) return false;
    return File(path.join(recDir.path, 'video.mp4')).existsSync();
  }

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
  ///
  /// [onProgress] (optional) fires on the main isolate with byte-level
  /// fractions (0.0..1.0) as the worker tar+gzips through the source
  /// files. Throttled to ~10 Hz by the worker. Will not fire when the
  /// build is short-circuited by an existing archive.
  Future<String?> buildArchive(
    String sessionId, {
    void Function(double fraction)? onProgress,
  }) async {
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

      // Spawn the worker isolate manually (rather than via `compute`) so
      // we can receive periodic progress messages over a ReceivePort.
      // The isolate's lifecycle is bounded by the completer below: it
      // resolves on `done` / `error`, after which we tear down the ports.
      final receivePort = ReceivePort();
      final errorPort = ReceivePort();
      final completer = Completer<String?>();

      void finish(String? result) {
        if (completer.isCompleted) return;
        completer.complete(result);
        receivePort.close();
        errorPort.close();
      }

      receivePort.listen((msg) {
        if (msg is! Map) return;
        switch (msg['type']) {
          case 'progress':
            final f = msg['fraction'];
            if (f is num) onProgress?.call(f.toDouble());
            break;
          case 'done':
            finish(msg['path'] as String?);
            break;
          case 'error':
            debugPrint('[RecordingManager] export isolate error: '
                '${msg['message']}');
            finish(null);
            break;
        }
      });
      errorPort.listen((err) {
        debugPrint('[RecordingManager] export isolate crashed: $err');
        finish(null);
      });

      try {
        await Isolate.spawn<_ExportRequest>(
          _runExportIsolate,
          _ExportRequest(
            recordingDir: recordingDir.path,
            tarGzPath: archivePath,
            sendPort: receivePort.sendPort,
          ),
          onError: errorPort.sendPort,
          errorsAreFatal: true,
        );
      } catch (e) {
        debugPrint('[RecordingManager] Isolate.spawn failed: $e');
        finish(null);
      }

      return await completer.future;
    } catch (e) {
      print('Error building archive for $sessionId: $e');
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

  // Build the export-facing slug for a recording. Used as the outer
  // archive basename so the file the user shares encodes both major scene
  // and minor task.
  //
  // WF2 catalog convention: task id is `<major>-<minor>` (e.g.
  // `kitchen-cook`) and matches `categoryId-<minor>`. We strip the
  // `<categoryId>-` prefix so the category isn't double-encoded.
  //
  // Legacy 0.2.3-era recordings used a 2-letter category abbrev prefix
  // (`lr-pick-remote` under `living-room`); the fallback regex below keeps
  // those exports readable until they age out.
  String _exportSlug(String sessionId, String? categoryId, String? taskId) {
    String? subSlug;
    if (taskId != null && taskId.isNotEmpty) {
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          taskId.startsWith('$categoryId-')) {
        subSlug = taskId.substring(categoryId.length + 1);
      } else {
        final match = RegExp(r'^[a-z]{2}-').firstMatch(taskId);
        subSlug = match != null ? taskId.substring(match.end) : taskId;
      }
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
      debugPrint('Error exporting recording: $e');
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
        sharePositionOrigin:
            sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      debugPrint('Error sharing recording: $e');
      rethrow;
    }
  }
}
