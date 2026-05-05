import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// User-facing toggles for hand-presence feedback. Three independent
/// switches:
///   • voiceCues — speak the composite first-frame state and the per-hand
///     "enters/exits the view" cues during recording.
///   • border — show the colored border around the camera preview that
///     tracks the composite hand-presence state.
///   • vibrateOnNone — fire a single medium haptic when state enters NONE.
///
/// The recording-start chirp (sci-fi cue at the moment capture begins) is
/// always on — it's a recording-state signal, not a hand-presence one.
class HandPresenceSettingsController extends ChangeNotifier {
  static const _filename = 'hand_presence_prefs.json';

  bool _voiceCues = true;
  bool _border = true;
  bool _vibrateOnNone = false;

  bool get voiceCuesEnabled => _voiceCues;
  bool get borderEnabled => _border;
  bool get vibrateOnNoneEnabled => _vibrateOnNone;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      // Prefer the new key for voice; fall back to the old `voice` key so a
      // prefs file written by a previous build still resolves correctly.
      _voiceCues = (data['voice_cues'] as bool?) ??
          (data['voice'] as bool?) ??
          _voiceCues;
      _border = (data['border'] as bool?) ?? _border;
      _vibrateOnNone = (data['vibrateOnNone'] as bool?) ?? _vibrateOnNone;
      notifyListeners();
    } catch (_) {
      // Stick with defaults on parse failure.
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'voice_cues': _voiceCues,
        'border': _border,
        'vibrateOnNone': _vibrateOnNone,
      }));
    } catch (_) {}
  }

  Future<void> setVoiceCuesEnabled(bool v) async {
    if (_voiceCues == v) return;
    _voiceCues = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBorderEnabled(bool v) async {
    if (_border == v) return;
    _border = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVibrateOnNoneEnabled(bool v) async {
    if (_vibrateOnNone == v) return;
    _vibrateOnNone = v;
    notifyListeners();
    await _save();
  }
}
