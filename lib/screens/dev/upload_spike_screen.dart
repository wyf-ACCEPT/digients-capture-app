// THROWAWAY — Tier 2 spike screen, lives until Phase A green-lights the
// background_downloader plugin against iOS 26.4 in our app context. Once
// the spike validates lock-screen survival + app-switch survival + cold-
// start state restoration, Phase B will fold the proven path into
// HttpUploadService and this whole file should be deleted in the same PR.
//
// Plan: .claude/plan/6e15-plan-background-upload.md
//
// The spike duplicates the /v1/submissions/init -> S3 PUT -> /v1/submissions/
// :id/complete pipeline that HttpUploadService already implements, but
// swaps the dio PUT for background_downloader's UploadTask. Keeping the
// pipeline duplicated (rather than reused via HttpUploadService) means
// the spike can fail without poisoning the production upload code path.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../models/recording.dart';
import '../../services/compression_queue.dart';
import '../../services/device_id_service.dart';
import '../../services/recording_manager.dart';
import '../../state/auth_controller.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';

const _kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.digients.tech',
);

class UploadSpikeScreen extends StatefulWidget {
  const UploadSpikeScreen({super.key});

  @override
  State<UploadSpikeScreen> createState() => _UploadSpikeScreenState();
}

class _UploadSpikeScreenState extends State<UploadSpikeScreen>
    with WidgetsBindingObserver {
  final _manager = RecordingManager();
  final _deviceId = DeviceIdService();

  List<Recording> _recordings = [];
  bool _loadingList = true;

  Recording? _runningRecording;
  String _phase = 'idle';
  double _progress = 0;
  String _statusLine = '';
  final List<String> _eventLog = [];
  AppLifecycleState _appState = AppLifecycleState.resumed;

  StreamSubscription<TaskUpdate>? _updateSub;
  String? _activeSubmissionId;
  int _activeFileBytes = 0;
  double _activeDurationSec = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDownloader();
    _loadRecordings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _appState = state;
      _logEvent('app lifecycle -> ${state.name}');
    });
  }

  void _initDownloader() {
    _updateSub = FileDownloader().updates.listen((update) {
      if (!mounted) return;
      final sid = _runningRecording?.sessionId;
      if (sid == null || update.task.taskId != sid) return;
      if (update is TaskStatusUpdate) {
        setState(() {
          _statusLine = 'status=${update.status.name}';
          _logEvent('TaskStatus: ${update.status.name}');
          switch (update.status) {
            case TaskStatus.complete:
              _phase = 'completing';
              _onPutComplete();
              break;
            case TaskStatus.failed:
              _phase = 'failed';
              final ex = update.exception;
              if (ex != null) _logEvent('  exception: ${ex.description}');
              break;
            case TaskStatus.canceled:
              _phase = 'canceled';
              break;
            case TaskStatus.notFound:
              _phase = 'notFound';
              break;
            case TaskStatus.paused:
              _phase = 'paused';
              break;
            default:
              break;
          }
        });
      } else if (update is TaskProgressUpdate) {
        setState(() {
          _progress = update.progress.clamp(0.0, 1.0);
        });
      }
    });
  }

  Future<void> _loadRecordings() async {
    final list = await _manager.loadRecordings();
    list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    if (!mounted) return;
    setState(() {
      _recordings = list;
      _loadingList = false;
    });
  }

  void _logEvent(String e) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _eventLog.insert(0, '$ts  $e');
    if (_eventLog.length > 80) _eventLog.removeLast();
  }

  bool get _spikeIsTerminal =>
      _phase == 'idle' ||
      _phase == 'done' ||
      _phase == 'done (already)' ||
      _phase == 'failed' ||
      _phase == 'canceled' ||
      _phase == 'notFound' ||
      _phase == 'complete-failed';

  Future<void> _runSpike(Recording r) async {
    setState(() {
      _runningRecording = r;
      _phase = 'compressing';
      _progress = 0;
      _statusLine = '';
      _eventLog.clear();
      _activeSubmissionId = null;
      _logEvent('=== spike for ${r.sessionId.substring(0, 8)} ===');
    });

    final compression = context.read<CompressionQueue>();
    final auth = context.read<AuthController>();

    try {
      // 1. Ensure tar.gz is on disk
      final archive = await compression.waitForReady(r.sessionId);
      if (archive == null) {
        throw Exception('compression failed (returned null)');
      }
      final archiveFile = File(archive);
      final bytes = await archiveFile.length();
      _activeFileBytes = bytes;
      _activeDurationSec = (r.durationSeconds ?? 0).toDouble();
      _logEvent('archive ready: $bytes bytes');

      // 2. /v1/submissions/init
      setState(() => _phase = 'init');
      final deviceUuid = await _deviceId.getOrCreateUuid();
      final deviceModel = await _deviceId.getDeviceModelLabel();
      final initToken = await auth.getFreshAccessToken();
      _logEvent('POST /v1/submissions/init');
      final initRes = await http.post(
        Uri.parse('$_kApiBase/v1/submissions/init'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $initToken',
        },
        body: jsonEncode({
          'session_id': r.sessionId,
          'device_uuid': deviceUuid,
          'device_model': deviceModel,
          'content_type': 'application/gzip',
        }),
      );
      if (initRes.statusCode != 200 && initRes.statusCode != 409) {
        throw Exception('init ${initRes.statusCode}: ${initRes.body}');
      }
      final initBody = jsonDecode(initRes.body) as Map<String, dynamic>;
      if (initBody['already_uploaded'] == true) {
        _logEvent('server: already_uploaded — short-circuit');
        setState(() {
          _phase = 'done (already)';
          _progress = 1.0;
        });
        return;
      }
      final uploadUrl = initBody['upload_url'] as String;
      _activeSubmissionId = initBody['submission_id'] as String;
      _logEvent('submission_id=$_activeSubmissionId');

      // 3. background_downloader UploadTask — PUT to presigned S3 URL.
      // `post: 'binary'` puts the file body as the raw HTTP body (vs
      // multipart form-data); S3 presigned PUT expects raw bytes.
      final task = UploadTask.fromFile(
        file: archiveFile,
        taskId: r.sessionId,
        url: uploadUrl,
        httpRequestMethod: 'PUT',
        post: 'binary',
        headers: const {'Content-Type': 'application/gzip'},
        updates: Updates.statusAndProgress,
      );
      _logEvent('FileDownloader.enqueue(taskId=${task.taskId})');
      setState(() => _phase = 'uploading');
      final ok = await FileDownloader().enqueue(task);
      if (!ok) throw Exception('FileDownloader.enqueue returned false');
      _logEvent('enqueue ok — handing off to nsurlsessiond');
      // Status + progress now flow via _updateSub.
    } catch (e) {
      _logEvent('error: $e');
      setState(() => _phase = 'failed');
    }
  }

  Future<void> _onPutComplete() async {
    final subId = _activeSubmissionId;
    if (subId == null) {
      _logEvent('PUT complete but no submission_id?');
      return;
    }
    final auth = context.read<AuthController>();
    try {
      final token = await auth.getFreshAccessToken();
      _logEvent('POST /v1/submissions/$subId/complete');
      final res = await http.post(
        Uri.parse('$_kApiBase/v1/submissions/$subId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'size_bytes': _activeFileBytes,
          'duration_sec': _activeDurationSec,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _logEvent('/complete -> ${res.statusCode} OK');
        setState(() {
          _phase = 'done';
          _progress = 1.0;
        });
      } else {
        _logEvent('/complete -> ${res.statusCode}: ${res.body}');
        setState(() => _phase = 'complete-failed');
      }
    } catch (e) {
      _logEvent('/complete error: $e');
      setState(() => _phase = 'complete-failed');
    }
  }

  Future<void> _cancelRunning() async {
    final sid = _runningRecording?.sessionId;
    if (sid == null) return;
    _logEvent('user requested cancel');
    final ok = await FileDownloader().cancelTaskWithId(sid);
    _logEvent('cancelTaskWithId -> $ok');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Upload Spike (DEV)',
          style: DCText.inter(size: 17, weight: FontWeight.w600, color: c.text),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tier 2 spike — background_downloader PUT to S3 via '
                '/v1/submissions/{init,complete}. Pick a recording, then '
                'try locking the screen / switching apps / killing the app '
                'mid-upload. nsurlsessiond should keep the transfer alive.',
                style: DCText.inter(
                  size: 11,
                  weight: FontWeight.w400,
                  color: c.textDim,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _StatusCard(
                phase: _phase,
                progress: _progress,
                statusLine: _statusLine,
                appState: _appState,
                eventLog: _eventLog,
                onCancel: _runningRecording != null && !_spikeIsTerminal
                    ? _cancelRunning
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Pick a recording to spike (tap disabled while running):',
                style: DCText.inter(
                  size: 12,
                  weight: FontWeight.w500,
                  color: c.textDim,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildList(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(DCColors c) {
    if (_loadingList) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }
    if (_recordings.isEmpty) {
      return Center(
        child: Text(
          'no recordings — record one first',
          style: DCText.inter(
            size: 13,
            weight: FontWeight.w500,
            color: c.textDim,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _recordings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = _recordings[i];
        final isRunning = _runningRecording?.sessionId == r.sessionId;
        final tappable = _spikeIsTerminal;
        return GestureDetector(
          onTap: tappable ? () => _runSpike(r) : null,
          child: Opacity(
            opacity: tappable || isRunning ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isRunning ? c.accentTint : c.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRunning ? c.accent : c.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.sessionId.substring(0, 12),
                    style: DCText.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.durationSeconds ?? 0}s · ${r.fileSizeMB ?? 0} MB',
                    style: DCText.mono(
                      size: 10,
                      weight: FontWeight.w500,
                      color: c.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String phase;
  final double progress;
  final String statusLine;
  final AppLifecycleState appState;
  final List<String> eventLog;
  final VoidCallback? onCancel;

  const _StatusCard({
    required this.phase,
    required this.progress,
    required this.statusLine,
    required this.appState,
    required this.eventLog,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'phase: $phase',
                  style: DCText.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: DCText.mono(
                  size: 14,
                  weight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'cancel',
                      style: DCText.mono(
                        size: 10,
                        weight: FontWeight.w600,
                        color: c.danger,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: c.accent,
              backgroundColor: c.surface2,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'app=${appState.name}   $statusLine',
            style: DCText.mono(
              size: 10,
              weight: FontWeight.w500,
              color: c.textDim,
            ),
          ),
          if (eventLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: SelectableText(
                  eventLog.join('\n'),
                  style: DCText.mono(
                    size: 10,
                    weight: FontWeight.w400,
                    color: c.textFaint,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
