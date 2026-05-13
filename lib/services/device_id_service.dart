import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/recording.dart';

// Stable identity for this physical install of the App.
//
// Per the M-Upload-Lite plan (Phase C decision matrix):
//   * deviceUuid — minted once on first launch, persisted in the platform
//     secure store. iOS Keychain survives app uninstall (Apple default) so
//     reinstalling still maps to the same device; Android EncryptedSharedPrefs
//     is wiped on uninstall, which is an acceptable loss since the only cost
//     is fresh per-device groupings in the S3 layout for that user.
//   * deviceModel — sourced from the existing camera platform channel
//     (UIDevice.model / Build.MODEL); cached after the first lookup since the
//     answer can't change without a relaunch.
//
// We intentionally do NOT use UIDevice.identifierForVendor / Android ID:
// both reset on reinstall (vendor-scoped) or wipe (Android), and Apple
// privacy policy treats them as ad-tracking adjacent. A self-minted UUID is
// decoupled from any platform-policy grey area.
class DeviceIdService {
  static const _uuidKey = 'digients.device_uuid';
  static const _channel = MethodChannel('digients_app/camera');

  final FlutterSecureStorage _storage;
  String? _uuidCache;
  DeviceInfo? _infoCache;

  DeviceIdService()
      : _storage = const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  // Returns the UUID, minting one on first call and caching it in-process
  // for subsequent calls. Always non-null on return — if the keychain read
  // fails for some reason we still proceed with a fresh UUID rather than
  // blocking the upload.
  Future<String> getOrCreateUuid() async {
    if (_uuidCache != null) return _uuidCache!;
    try {
      final existing = await _storage.read(key: _uuidKey);
      if (existing != null && existing.isNotEmpty) {
        _uuidCache = existing;
        return existing;
      }
    } catch (e) {
      debugPrint('[DeviceIdService] secure-storage read failed: $e');
    }
    final fresh = const Uuid().v4();
    try {
      await _storage.write(key: _uuidKey, value: fresh);
    } catch (e) {
      debugPrint('[DeviceIdService] secure-storage write failed: $e');
    }
    _uuidCache = fresh;
    return fresh;
  }

  // Fetches device hardware info (model / modelIdentifier / OS) via the
  // existing camera platform channel. Cached after the first successful
  // call since the values can't change without a relaunch.
  Future<DeviceInfo?> getDeviceInfo() async {
    if (_infoCache != null) return _infoCache;
    try {
      final Map<dynamic, dynamic>? raw =
          await _channel.invokeMethod('getDeviceInfo');
      if (raw == null) return null;
      final map = raw.cast<String, dynamic>();
      final info = DeviceInfo(
        os: (map['os'] as String?) ?? '',
        osVersion: (map['osVersion'] as String?) ?? '',
        manufacturer: (map['manufacturer'] as String?) ?? '',
        model: (map['model'] as String?) ?? '',
        modelIdentifier: (map['modelIdentifier'] as String?) ?? '',
      );
      _infoCache = info;
      return info;
    } catch (e) {
      debugPrint('[DeviceIdService] getDeviceInfo failed: $e');
      return null;
    }
  }

  // Short device label suitable for the submissions.device_model column.
  // Prefer the iOS modelIdentifier (e.g. "iPhone15,3" — distinguishes Pro
  // vs Pro Max), fall back to the friendly model name otherwise.
  Future<String> getDeviceModelLabel() async {
    final info = await getDeviceInfo();
    if (info == null) return 'unknown';
    if (info.modelIdentifier.isNotEmpty) return info.modelIdentifier;
    if (info.model.isNotEmpty) return info.model;
    return 'unknown';
  }
}
