import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// User-facing toggles for the hand-presence feedback layer (§7 of
/// MOBILE_APP_SPECS_V2_HAND_PRESENCE_FEEDBACK.md).
///
/// Persistence is a single JSON file alongside `prefs.json` (matches the
/// existing ThemeController pattern). Defaults match the spec: master ON,
/// tones ON, voice OFF, border ON, vibrate-on-NONE OFF.
class HandPresenceSettingsController extends ChangeNotifier {
  static const _filename = 'hand_presence_prefs.json';

  bool _master = true;
  bool _tones = true;
  bool _voice = false;
  bool _border = true;
  bool _vibrateOnNone = false;

  bool get masterEnabled => _master;
  bool get tonesEnabled => _master && _tones;
  bool get voiceEnabled => _master && _tones && _voice;
  bool get borderEnabled => _master && _border;
  bool get vibrateOnNone => _master && _vibrateOnNone;

  // Raw values (without master gating) — used to render the toggles
  // themselves so they reflect the stored preference.
  bool get rawTones => _tones;
  bool get rawVoice => _voice;
  bool get rawBorder => _border;
  bool get rawVibrateOnNone => _vibrateOnNone;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _master = data['master'] as bool? ?? _master;
      _tones = data['tones'] as bool? ?? _tones;
      _voice = data['voice'] as bool? ?? _voice;
      _border = data['border'] as bool? ?? _border;
      _vibrateOnNone = data['vibrateOnNone'] as bool? ?? _vibrateOnNone;
      notifyListeners();
    } catch (_) {
      // Stick with defaults on parse failure.
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'master': _master,
        'tones': _tones,
        'voice': _voice,
        'border': _border,
        'vibrateOnNone': _vibrateOnNone,
      }));
    } catch (_) {}
  }

  Future<void> setMaster(bool v) async {
    if (_master == v) return;
    _master = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTones(bool v) async {
    if (_tones == v) return;
    _tones = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVoice(bool v) async {
    if (_voice == v) return;
    _voice = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBorder(bool v) async {
    if (_border == v) return;
    _border = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVibrateOnNone(bool v) async {
    if (_vibrateOnNone == v) return;
    _vibrateOnNone = v;
    notifyListeners();
    await _save();
  }
}
