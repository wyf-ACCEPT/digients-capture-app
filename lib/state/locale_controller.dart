import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocaleController extends ChangeNotifier {
  static const Locale zh = Locale('zh');
  static const Locale en = Locale('en');
  static const _filename = 'locale_prefs.json';

  Locale _locale = zh;
  Locale get locale => _locale;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final code = data['locale'] as String?;
      if (code == en.languageCode) {
        _locale = en;
      } else {
        _locale = zh;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = locale.languageCode == en.languageCode ? en : zh;
    if (_locale == normalized) return;
    _locale = normalized;
    notifyListeners();
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'locale': _locale.languageCode}));
    } catch (_) {}
  }
}
