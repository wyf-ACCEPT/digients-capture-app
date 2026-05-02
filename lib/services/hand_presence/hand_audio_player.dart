import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'hand_presence_state.dart';

/// Plays hand-presence audio cues on every committed state transition.
///
/// Uses one preloaded `AudioPlayer` per cue so playback is non-blocking and
/// has no model-load latency. The audio session is configured as ambient with
/// mix-with-others so we never duck the user's music or fight the silent
/// switch (§4.4 of the addendum).
///
/// Voice phrases are preloaded too but only played when [voiceEnabled] is
/// true; the default path is tones-only.
class HandAudioPlayer {
  HandAudioPlayer({
    Stream<HandPresenceTransition>? transitions,
    this.voiceEnabled = false,
    this.tonesEnabled = true,
  }) {
    if (transitions != null) bind(transitions);
  }

  bool voiceEnabled;
  bool tonesEnabled;

  final Map<HandPresenceState, AudioPlayer> _tonePlayers = {
    HandPresenceState.both: AudioPlayer(),
    HandPresenceState.leftOnly: AudioPlayer(),
    HandPresenceState.rightOnly: AudioPlayer(),
    HandPresenceState.none: AudioPlayer(),
  };

  final Map<HandPresenceState, AudioPlayer> _voicePlayers = {
    HandPresenceState.both: AudioPlayer(),
    HandPresenceState.leftOnly: AudioPlayer(),
    HandPresenceState.rightOnly: AudioPlayer(),
    HandPresenceState.none: AudioPlayer(),
  };

  StreamSubscription<HandPresenceTransition>? _sub;
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
      for (final entry in _voicePlayers.entries)
        entry.value.setAsset(_voiceAssetFor(entry.key)),
    ]);
  }

  void bind(Stream<HandPresenceTransition> transitions) {
    _sub?.cancel();
    _sub = transitions.listen(_onTransition);
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
    if (voiceEnabled) {
      final voicePlayer = _voicePlayers[t.to];
      if (voicePlayer != null) {
        // Drop in-flight voice (last-state-wins per §4.3).
        for (final p in _voicePlayers.values) {
          if (p.playing) await p.stop();
        }
        await voicePlayer.seek(Duration.zero);
        unawaited(voicePlayer.play());
      }
    }
  }

  String _toneAssetFor(HandPresenceState s) =>
      'assets/audio/hand_state/${_baseName(s)}.wav';

  String _voiceAssetFor(HandPresenceState s) =>
      'assets/audio/hand_state_voice/${_baseName(s)}.wav';

  String _baseName(HandPresenceState s) => switch (s) {
        HandPresenceState.both => 'both',
        HandPresenceState.leftOnly => 'left_only',
        HandPresenceState.rightOnly => 'right_only',
        HandPresenceState.none => 'none',
      };

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await Future.wait([
      for (final p in _tonePlayers.values) p.dispose(),
      for (final p in _voicePlayers.values) p.dispose(),
    ]);
  }
}
