import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'hand_presence_state.dart';

/// Plays hand-presence audio cues:
///
///   • a sci-fi recording-start chirp the moment capture begins (the user is
///     wearing the phone on their head and can't see the screen);
///   • a one-shot composite voice announcement at the first frame of
///     recording so the user knows what's in view before they start moving;
///   • per-hand voice cues every time a single hand enters or exits the view
///     during recording ("Left hand enters the view" etc.);
///   • optional sub-second tones bound to composite-state transitions
///     (kept available for users who want a beep on top of the voice).
///
/// One preloaded `AudioPlayer` per cue so playback is non-blocking and has
/// no model-load latency. Audio session is ambient + mix-with-others so we
/// never duck the user's music or fight the silent switch.
class HandAudioPlayer {
  HandAudioPlayer({
    Stream<HandPresenceTransition>? transitions,
    Stream<HandSideTransition>? sideTransitions,
    this.voiceEnabled = true,
    this.tonesEnabled = false,
    this.recordingStartEnabled = true,
  }) {
    if (transitions != null) bind(transitions);
    if (sideTransitions != null) bindSides(sideTransitions);
  }

  bool voiceEnabled;
  bool tonesEnabled;
  bool recordingStartEnabled;

  final Map<HandPresenceState, AudioPlayer> _tonePlayers = {
    HandPresenceState.both: AudioPlayer(),
    HandPresenceState.leftOnly: AudioPlayer(),
    HandPresenceState.rightOnly: AudioPlayer(),
    HandPresenceState.none: AudioPlayer(),
  };

  // Composite voice (used for the first-frame announcement only).
  final Map<HandPresenceState, AudioPlayer> _stateVoicePlayers = {
    HandPresenceState.both: AudioPlayer(),
    HandPresenceState.leftOnly: AudioPlayer(),
    HandPresenceState.rightOnly: AudioPlayer(),
    HandPresenceState.none: AudioPlayer(),
  };

  // Per-hand transition voice (left/right × enter/exit) plus the coalesced
  // both-hand cues, used while recording.
  final Map<String, AudioPlayer> _sideVoicePlayers = {
    'left_enter': AudioPlayer(),
    'left_exit': AudioPlayer(),
    'right_enter': AudioPlayer(),
    'right_exit': AudioPlayer(),
    'both_enter': AudioPlayer(),
    'both_exit': AudioPlayer(),
  };

  // When the two hands enter or exit within ~200 ms of each other we play a
  // single "Both hands enter/exit the view" cue instead of stomping the
  // first per-hand cue with the second one. We hold each side transition for
  // this long; if its mirror arrives we coalesce, otherwise the timer fires
  // and the side-specific cue plays. The detector runs at 10 fps (one tick
  // every ~100 ms), so 200 ms catches "same-tick" and "adjacent-tick" pairs
  // without making the user wait too long for the cue.
  static const Duration _sideCoalesceWindow = Duration(milliseconds: 200);
  HandSideTransition? _pendingSide;
  Timer? _coalesceTimer;

  final AudioPlayer _recordingStartPlayer = AudioPlayer();
  // Session-flow cues used by the vol-button control flow.
  final AudioPlayer _recordingStopPlayer = AudioPlayer();
  final AudioPlayer _submissionSuccessPlayer = AudioPlayer();
  final AudioPlayer _armedPromptPlayer = AudioPlayer();

  StreamSubscription<HandPresenceTransition>? _sub;
  StreamSubscription<HandSideTransition>? _sideSub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.notification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
    ));

    await Future.wait([
      for (final entry in _tonePlayers.entries)
        entry.value.setAsset(_toneAssetFor(entry.key)),
      for (final entry in _stateVoicePlayers.entries)
        entry.value.setAsset(_stateVoiceAssetFor(entry.key)),
      for (final entry in _sideVoicePlayers.entries)
        entry.value.setAsset('assets/audio/hand_state_voice/${entry.key}.wav'),
      _recordingStartPlayer.setAsset('assets/audio/session/recording_start.wav'),
      _recordingStopPlayer.setAsset('assets/audio/session/recording_stop.wav'),
      _submissionSuccessPlayer
          .setAsset('assets/audio/session/submission_success.wav'),
      _armedPromptPlayer.setAsset('assets/audio/session_voice/armed_prompt.wav'),
    ]);
  }

  void bind(Stream<HandPresenceTransition> transitions) {
    _sub?.cancel();
    _sub = transitions.listen(_onTransition);
  }

  void bindSides(Stream<HandSideTransition> sideTransitions) {
    _sideSub?.cancel();
    _sideSub = sideTransitions.listen(_onSideTransition);
  }

  /// Play the sci-fi recording-start chirp. Returns a future that completes
  /// when playback ends so callers can sequence a follow-up cue (e.g. the
  /// first-frame state announcement).
  Future<void> playRecordingStart() => _playAndAwait(_recordingStartPlayer);

  /// Play the descending sci-fi stop chirp. Returns a future that completes
  /// when playback ends so the caller can chain the success-popup chime.
  Future<void> playRecordingStop() => _playAndAwait(_recordingStopPlayer);

  /// Play the affirmative chord chime that pairs with the submission popup.
  Future<void> playSubmissionSuccess() =>
      _playAndAwait(_submissionSuccessPlayer);

  /// Speak "Press volume button to start recording" — the ARMED-state cue.
  /// Silent if voice is disabled in settings.
  Future<void> playArmedPrompt() async {
    if (!_initialized) return;
    if (!voiceEnabled) return;
    // ARMED prompt and per-hand voice both live in the same "voice" lane —
    // make sure neither stomps the other. The detector hasn't started yet
    // when we arm, so in practice no per-hand voice should be in flight.
    await _stopAllVoice();
    await _armedPromptPlayer.stop();
    await _armedPromptPlayer.seek(Duration.zero);
    unawaited(_armedPromptPlayer.play());
  }

  /// Cancel an in-flight ARMED prompt (e.g. when the user presses a vol
  /// button before the prompt finishes — we don't want it talking over the
  /// recording-start chirp).
  Future<void> stopArmedPrompt() async {
    if (!_initialized) return;
    if (_armedPromptPlayer.playing) {
      await _armedPromptPlayer.stop();
    }
  }

  Future<void> _playAndAwait(AudioPlayer player) async {
    if (!_initialized) return;
    if (player == _recordingStartPlayer && !recordingStartEnabled) return;
    await player.seek(Duration.zero);
    final completer = Completer<void>();
    StreamSubscription<ProcessingState>? sub;
    sub = player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    unawaited(player.play());
    return completer.future;
  }

  /// Speak the composite hand-presence state without requiring a transition.
  /// Used at the first frame of recording so the user knows whether their
  /// hands are in frame before they start moving. Silent if voice is disabled.
  Future<void> playStateAnnouncement(HandPresenceState state) async {
    if (!_initialized) return;
    if (!voiceEnabled) return;
    final player = _stateVoicePlayers[state];
    if (player == null) return;
    await _stopAllVoice();
    await player.seek(Duration.zero);
    unawaited(player.play());
  }

  Future<void> _stopAllVoice() async {
    // Last-state-wins per §4.3 — drop in-flight voice across all three
    // banks (composite, per-hand, and the armed-state prompt). Without
    // including the armed prompt here, a state announcement fired right
    // after a fast vol-button press could overlap the tail of the prompt.
    if (_armedPromptPlayer.playing) await _armedPromptPlayer.stop();
    for (final p in _stateVoicePlayers.values) {
      if (p.playing) await p.stop();
    }
    for (final p in _sideVoicePlayers.values) {
      if (p.playing) await p.stop();
    }
  }

  Future<void> _onTransition(HandPresenceTransition t) async {
    if (!_initialized) return;
    if (tonesEnabled) {
      final tonePlayer = _tonePlayers[t.to];
      if (tonePlayer != null) {
        await tonePlayer.seek(Duration.zero);
        unawaited(tonePlayer.play());
      }
    }
  }

  Future<void> _onSideTransition(HandSideTransition t) async {
    if (!_initialized) return;
    if (!voiceEnabled) return;

    final pending = _pendingSide;
    if (pending != null) {
      // Two side events queued within the coalesce window.
      if (pending.side != t.side && pending.entered == t.entered) {
        // Same direction, opposite hand — speak the unified "both" cue and
        // drop the pending single-side cue.
        _coalesceTimer?.cancel();
        _coalesceTimer = null;
        _pendingSide = null;
        await _playSideKey(t.entered ? 'both_enter' : 'both_exit');
        return;
      }
      // Different direction (or same hand, defensive) — flush the pending
      // cue immediately and re-arm with the new event so it isn't lost.
      _coalesceTimer?.cancel();
      _coalesceTimer = null;
      _pendingSide = null;
      await _playSingleSide(pending);
    }

    _pendingSide = t;
    _coalesceTimer = Timer(_sideCoalesceWindow, () {
      final flush = _pendingSide;
      if (flush == null) return;
      _pendingSide = null;
      _coalesceTimer = null;
      // Fire-and-forget — Timer can't await.
      unawaited(_playSingleSide(flush));
    });
  }

  Future<void> _playSingleSide(HandSideTransition t) async {
    final key = '${t.side.name}_${t.entered ? 'enter' : 'exit'}';
    await _playSideKey(key);
  }

  Future<void> _playSideKey(String key) async {
    final player = _sideVoicePlayers[key];
    if (player == null) return;
    await _stopAllVoice();
    await player.seek(Duration.zero);
    unawaited(player.play());
  }

  String _toneAssetFor(HandPresenceState s) =>
      'assets/audio/hand_state/${_baseName(s)}.wav';

  String _stateVoiceAssetFor(HandPresenceState s) =>
      'assets/audio/hand_state_voice/${_baseName(s)}.wav';

  String _baseName(HandPresenceState s) => switch (s) {
        HandPresenceState.both => 'both',
        HandPresenceState.leftOnly => 'left_only',
        HandPresenceState.rightOnly => 'right_only',
        HandPresenceState.none => 'none',
      };

  Future<void> dispose() async {
    await _sub?.cancel();
    await _sideSub?.cancel();
    _sub = null;
    _sideSub = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _pendingSide = null;
    await Future.wait([
      for (final p in _tonePlayers.values) p.dispose(),
      for (final p in _stateVoicePlayers.values) p.dispose(),
      for (final p in _sideVoicePlayers.values) p.dispose(),
      _recordingStartPlayer.dispose(),
      _recordingStopPlayer.dispose(),
      _submissionSuccessPlayer.dispose(),
      _armedPromptPlayer.dispose(),
    ]);
  }
}
