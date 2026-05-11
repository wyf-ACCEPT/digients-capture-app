import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/auth.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

// Holds the current auth session and orchestrates sign-in / sign-out.
// The access token lives only on the in-memory AuthSession (rebuilt on every
// app launch via refresh); the refresh token is the only credential that ever
// touches disk, and only via TokenStorage (Keychain/Keystore).
class AuthController extends ChangeNotifier {
  final AuthService _service;
  final TokenStorage _tokens;

  AuthSession? _session;
  bool _isBusy = false;
  Future<String>? _inFlightRefresh;

  AuthController({required AuthService service, required TokenStorage tokens})
      : _service = service,
        _tokens = tokens;

  // Access tokens are HS256 JWTs with a 15-minute TTL (server: ACCESS_TTL_S
  // in digients-api/src/lib/jwt.ts). If a caller asks for a token that's
  // within this margin of expiring, we proactively swap the refresh token
  // for a new pair before handing one out. Demo sessions mint synthetic
  // tokens that don't decode as JWTs — we treat those as "always fresh"
  // (refresh would loop locally anyway) and let the call go through to the
  // backend, which will 401 it and surface a clear error.
  static const _refreshIfExpiresWithin = Duration(minutes: 2);

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isBusy => _isBusy;

  // Returns a non-expiring-soon access token, refreshing in the background
  // if needed. Single-flight: concurrent callers share the same refresh.
  // Throws AuthException if no session is active or refresh fails.
  Future<String> getFreshAccessToken() async {
    final current = _session;
    if (current == null) {
      throw AuthException('Not authenticated', code: 'no_session');
    }
    // Demo sessions can't be JWT-decoded, but they round-trip refresh
    // locally too (HttpAuthService.refresh detects the `demo:` prefix and
    // mints a fresh pair without touching the server). So the policy
    // collapses to: refresh whenever the existing token isn't a JWT we
    // can verify is still valid.
    if (!_isAccessTokenStillFresh(current.accessToken)) {
      return _refreshOnce();
    }
    return current.accessToken;
  }

  Future<String> _refreshOnce() async {
    final inFlight = _inFlightRefresh;
    if (inFlight != null) return inFlight;
    final future = _doRefresh();
    _inFlightRefresh = future;
    try {
      return await future;
    } finally {
      _inFlightRefresh = null;
    }
  }

  Future<String> _doRefresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) {
      throw AuthException('No refresh token on file', code: 'no_refresh_token');
    }
    final res = await _service.refresh(refreshToken: refreshToken);
    await _adopt(res);
    return res.accessToken;
  }

  bool _isAccessTokenStillFresh(String token) {
    final payload = _decodeJwtPayload(token);
    if (payload == null) return false; // not a JWT (demo session) -> refresh
    final exp = payload['exp'];
    if (exp is! int) return false;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final remaining = expiresAt.difference(DateTime.now());
    return remaining > _refreshIfExpiresWithin;
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final raw = parts[1];
      // base64url decode requires padding to a multiple of 4.
      final padded = raw.padRight(raw.length + (4 - raw.length % 4) % 4, '=');
      final decoded = utf8.decode(base64Url.decode(padded));
      final parsed = jsonDecode(decoded);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  // Restore a session from a previously stored refresh token. Call on app start
  // before showing any routed UI so the router can decide auth vs. anon path.
  // Must NEVER throw — it is awaited in main() before runApp(), so any escape
  // would crash the app at launch.
  Future<void> bootstrap() async {
    String? refresh;
    try {
      refresh = await _tokens.readRefreshToken();
    } catch (e) {
      debugPrint('[AuthController] Token read failed on bootstrap: $e');
      return;
    }
    if (refresh == null) return;
    try {
      final res = await _service.refresh(refreshToken: refresh);
      await _adopt(res);
    } catch (e) {
      debugPrint('[AuthController] Refresh failed on bootstrap: $e');
      try {
        await _tokens.deleteRefreshToken();
      } catch (e2) {
        debugPrint('[AuthController] Token delete also failed (ignored): $e2');
      }
    }
  }

  Future<void> startOtp({
    required String identifier,
    required AuthIdentifierType type,
  }) {
    return _withBusy(
      () => _service.startOtp(identifier: identifier, type: type),
    );
  }

  Future<void> verifyOtp({
    required String identifier,
    required String code,
  }) {
    return _withBusy(() async {
      final res =
          await _service.verifyOtp(identifier: identifier, code: code);
      await _adopt(res);
    });
  }

  Future<void> signInWithApple({
    required String identityToken,
    required String nonce,
  }) {
    return _withBusy(() async {
      final res = await _service.signInWithApple(
        identityToken: identityToken,
        nonce: nonce,
      );
      await _adopt(res);
    });
  }

  Future<void> signInWithGoogle({required String idToken}) {
    return _withBusy(() async {
      final res = await _service.signInWithGoogle(idToken: idToken);
      await _adopt(res);
    });
  }

  Future<void> signInAsDemo() {
    return _withBusy(() async {
      final res = await _service.signInAsDemo();
      await _adopt(res);
    });
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    await _tokens.deleteRefreshToken();
    _session = null;
    notifyListeners();
    if (refresh != null) {
      try {
        await _service.logout(refreshToken: refresh);
      } catch (e) {
        // Server-side revoke is best-effort; local state is already cleared.
        debugPrint('[AuthController] Logout API call failed (ignored): $e');
      }
    }
  }

  Future<void> _adopt(AuthVerifyResponse res) async {
    await _tokens.saveRefreshToken(res.refreshToken);
    _session = AuthSession(accessToken: res.accessToken, profile: res.profile);
    notifyListeners();
  }

  Future<T> _withBusy<T>(Future<T> Function() body) async {
    _isBusy = true;
    notifyListeners();
    try {
      return await body();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
