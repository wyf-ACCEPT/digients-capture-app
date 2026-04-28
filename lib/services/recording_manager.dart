import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recording.dart';

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

      int totalSize = 0;
      await for (final FileSystemEntity entity in recordingDir.list(recursive: true)) {
        if (entity is File) {
          final FileStat stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return (totalSize / (1024 * 1024)).round(); // Convert to MB
    } catch (e) {
      print('Error calculating recording size: $e');
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

  Future<String?> exportRecording(String sessionId) async {
    try {
      final Directory recordingsDir = await _getRecordingsDirectory();
      final Directory recordingDir = Directory(path.join(recordingsDir.path, 'recording_$sessionId'));

      if (!await recordingDir.exists()) {
        print('Recording directory does not exist: $sessionId');
        return null;
      }

      // Create temporary file for the tar.gz
      final Directory tempDir = await getTemporaryDirectory();
      final String archivePath = path.join(tempDir.path, 'recording_$sessionId.tar.gz');

      // Create the archive
      final Archive archive = Archive();

      await for (final FileSystemEntity entity in recordingDir.list(recursive: true)) {
        if (entity is File) {
          final String relativePath = path.relative(entity.path, from: recordingDir.path);
          final List<int> fileBytes = await entity.readAsBytes();

          final ArchiveFile archiveFile = ArchiveFile(
            relativePath,
            fileBytes.length,
            fileBytes,
          );
          archive.addFile(archiveFile);
        }
      }

      // Write the tar.gz file
      final List<int>? tarBytesNullable = TarEncoder().encode(archive);
      if (tarBytesNullable == null) throw Exception('Failed to create tar archive');

      final List<int>? gzipBytesNullable = GZipEncoder().encode(tarBytesNullable);
      if (gzipBytesNullable == null) throw Exception('Failed to compress archive');

      final List<int> gzipBytes = gzipBytesNullable;

      final File archiveFile = File(archivePath);
      await archiveFile.writeAsBytes(gzipBytes);

      return archivePath;
    } catch (e) {
      print('Error exporting recording: $e');
      return null;
    }
  }

  Future<void> shareRecording(String sessionId, {Rect? sharePositionOrigin}) async {
    try {
      final String? archivePath = await exportRecording(sessionId);

      if (archivePath == null) {
        throw Exception('Failed to export recording');
      }

      final XFile file = XFile(archivePath);
      await Share.shareXFiles(
        [file],
        subject: 'Egocentric Video Recording - $sessionId',
        text: 'Egocentric video recording data package',
        sharePositionOrigin: sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      print('Error sharing recording: $e');
      rethrow;
    }
  }
}