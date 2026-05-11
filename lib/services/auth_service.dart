import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/auth.dart';

// Client surface for V3 spec §3.1 auth endpoints.
// MockAuthService implements the contract locally; HttpAuthService will swap in
// once the Cloudflare Workers backend is up. UI code talks only to AuthService.
abstract class AuthService {
  Future<void> startOtp({
    required String identifier,
    required AuthIdentifierType type,
  });

  Future<AuthVerifyResponse> verifyOtp({
    required String identifier,
    required String code,
  });

  Future<AuthVerifyResponse> signInWithApple({
    required String identityToken,
    required String nonce,
  });

  Future<AuthVerifyResponse> signInWithGoogle({
    required String idToken,
  });

  // Mints a synthetic local session, no server / OAuth provider involved.
  // Exposed so the UI can offer a "skip sign-in" path for App Review reviewers
  // and team members hitting bugs in the real OTP/refresh path. The returned
  // refresh token is prefixed `demo:` so HttpAuthService.refresh / .logout
  // recognize it and stay local instead of round-tripping the server. Demo
  // sessions cannot upload — see AuthController.canUpload.
  Future<AuthVerifyResponse> signInAsDemo();

  // Exchange a server-issued invite code for a real session. Powers the
  // "我有邀请码 / Use invite code" path for factory contractors who can't
  // reach Resend email. The returned session is a real backend session
  // (refresh tokens persisted server-side) and can upload.
  Future<AuthVerifyResponse> redeemInviteCode({required String code});

  Future<AuthVerifyResponse> refresh({required String refreshToken});

  Future<void> logout({required String refreshToken});
}

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException($code): $message';
}

class MockAuthService implements AuthService {
  // Fixed OTP for local dev — documented in .claude/AUTH_PLAN.md.
  static const _mockOtpCode = '123456';
  static const _networkLatency = Duration(milliseconds: 600);

  final _rng = Random();

  @override
  Future<void> startOtp({
    required String identifier,
    required AuthIdentifierType type,
  }) async {
    await Future.delayed(_networkLatency);
    // ignore: avoid_print
    print('[MockAuth] OTP sent to $identifier (use $_mockOtpCode)');
  }

  @override
  Future<AuthVerifyResponse> verifyOtp({
    required String identifier,
    required String code,
  }) async {
    await Future.delayed(_networkLatency);
    if (code != _mockOtpCode) {
      throw AuthException('Invalid code', code: 'invalid_otp');
    }
    final isEmail = identifier.contains('@');
    return _mintResponse(
      phone: isEmail ? null : identifier,
      email: isEmail ? identifier : null,
    );
  }

  @override
  Future<AuthVerifyResponse> signInWithApple({
    required String identityToken,
    required String nonce,
  }) async {
    await Future.delayed(_networkLatency);
    return _mintResponse(email: 'mock-apple@privaterelay.appleid.com');
  }

  @override
  Future<AuthVerifyResponse> signInWithGoogle({
    required String idToken,
  }) async {
    await Future.delayed(_networkLatency);
    return _mintResponse(email: 'mock-google@example.com');
  }

  @override
  Future<AuthVerifyResponse> signInAsDemo() async {
    await Future.delayed(_networkLatency);
    return _mintResponse(email: 'demo@example.com');
  }

  @override
  Future<AuthVerifyResponse> redeemInviteCode({required String code}) async {
    await Future.delayed(_networkLatency);
    if (code.trim().isEmpty) {
      throw AuthException('Invite code is required', code: 'invalid_code');
    }
    // Mock accepts any non-empty code so UI work can iterate without server.
    return _mintResponse(email: 'invite-${code.trim()}@example.com');
  }

  @override
  Future<AuthVerifyResponse> refresh({required String refreshToken}) async {
    await Future.delayed(_networkLatency);
    return _mintResponse();
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await Future.delayed(_networkLatency);
    // ignore: avoid_print
    print('[MockAuth] Refresh token revoked');
  }

  AuthVerifyResponse _mintResponse({String? phone, String? email}) {
    return AuthVerifyResponse(
      accessToken: _randomToken(32),
      refreshToken: _randomToken(48),
      profile: Profile(
        uid: _mintUid(),
        displayName: 'Mock User',
        phone: phone,
        email: email,
      ),
    );
  }

  // UID format per V3 spec §3.1: DGT-{8-char RFC 4648 base32}.
  String _mintUid() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final chars =
        List.generate(8, (_) => alphabet[_rng.nextInt(alphabet.length)]);
    return 'DGT-${chars.join()}';
  }

  String _randomToken(int len) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }
}

// Real backend implementation against digients-api (Cloudflare Workers + Hono).
// Server contract: V3 spec §3.1, mirrored in digients-api/openapi.yaml.
//
// Implements only the endpoints currently live on prod (M1 era):
//   - POST /v1/auth/start
//   - POST /v1/auth/verify
// Apple/Google OAuth and refresh/logout (M3-M5) throw `not_implemented`; the
// AuthController already swallows refresh/logout failures (best-effort) so the
// only user-visible breakage is OAuth buttons, which the UI can gate later.
class HttpAuthService implements AuthService {
  final String baseUrl;
  final http.Client _client;
  final Duration _timeout;

  HttpAuthService({
    required this.baseUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _timeout = timeout;

  @override
  Future<void> startOtp({
    required String identifier,
    required AuthIdentifierType type,
  }) async {
    final body = type == AuthIdentifierType.email
        ? {'email': identifier}
        : {'phone': identifier};
    final res = await _post('/v1/auth/start', body);
    if (res.statusCode == 204) return;
    throw _toException(res, fallbackCode: 'start_failed');
  }

  @override
  Future<AuthVerifyResponse> verifyOtp({
    required String identifier,
    required String code,
  }) async {
    final res = await _post('/v1/auth/verify', {
      'identifier': identifier,
      'code': code,
    });
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthVerifyResponse.fromJson(json);
    }
    throw _toException(res, fallbackCode: 'verify_failed');
  }

  // Real Sign in with Apple / Google Sign-In are M4 — wiring the native SDKs
  // and server-side identity-token validation. Until then these methods throw
  // `not_implemented`. The auth screen does not surface buttons that call them
  // (the visible "skip sign-in" path goes through signInAsDemo instead), so
  // the throw is a defensive guard that should never fire in normal flow.

  @override
  Future<AuthVerifyResponse> signInWithApple({
    required String identityToken,
    required String nonce,
  }) async {
    throw AuthException(
      'Sign in with Apple not yet implemented (M4).',
      code: 'not_implemented',
    );
  }

  @override
  Future<AuthVerifyResponse> signInWithGoogle({required String idToken}) async {
    throw AuthException(
      'Google sign-in not yet implemented (M4).',
      code: 'not_implemented',
    );
  }

  // Skip-sign-in path. Pure local mint — no server round-trip, refresh token
  // prefixed `demo:` so refresh / logout below recognize it and stay local.
  // The session lets users explore the App but is intentionally NOT able to
  // upload (AuthController.canUpload returns false for these sessions). Users
  // who want to upload must come back to the auth screen and redeem an
  // invite code via /v1/auth/invite-redeem.
  @override
  Future<AuthVerifyResponse> signInAsDemo() async => _mintDemoSession();

  @override
  Future<AuthVerifyResponse> redeemInviteCode({required String code}) async {
    final res = await _post('/v1/auth/invite-redeem', {'code': code.trim()});
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthVerifyResponse.fromJson(json);
    }
    throw _toException(res, fallbackCode: 'redeem_failed');
  }

  // refresh and logout still wrap their bodies as `async`: a sync throw inside
  // a Future-returning function can short-circuit the await mechanism in some
  // Dart frames and bubble up as unhandled — previously crashed the app on
  // relaunch via bootstrap → refresh → sync throw escaping the catch. For demo
  // sessions (refresh token prefixed `demo:`), refresh re-mints locally and
  // logout no-ops; nothing to talk to a server about.

  @override
  Future<AuthVerifyResponse> refresh({required String refreshToken}) async {
    if (refreshToken.startsWith('demo:')) {
      return _mintDemoSession();
    }
    final res = await _post('/v1/auth/refresh', {'refreshToken': refreshToken});
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthVerifyResponse.fromJson(json);
    }
    throw _toException(res, fallbackCode: 'refresh_failed');
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    if (refreshToken.startsWith('demo:')) return;
    final res = await _post('/v1/auth/logout', {'refreshToken': refreshToken});
    if (res.statusCode == 204) return;
    throw _toException(res, fallbackCode: 'logout_failed');
  }

  AuthVerifyResponse _mintDemoSession() {
    final rng = Random();
    String pick(int n, String alphabet) => List.generate(
        n, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
    const tokenChars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const uidChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    return AuthVerifyResponse(
      accessToken: pick(32, tokenChars),
      refreshToken: 'demo:${pick(40, tokenChars)}',
      profile: Profile(
        uid: 'DGT-${pick(8, uidChars)}',
        displayName: 'Demo User',
        email: 'demo@digients.tech',
      ),
    );
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw AuthException('Network unreachable: ${e.message}', code: 'network');
    } on TimeoutException {
      throw AuthException('Request timed out', code: 'timeout');
    } on http.ClientException catch (e) {
      throw AuthException('Transport error: ${e.message}', code: 'transport');
    }
  }

  // The server returns RFC 7807 problem+json on errors; fall back to raw body
  // when parsing fails so we never lose the operator's view of what happened.
  AuthException _toException(http.Response res, {required String fallbackCode}) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final detail = (json['detail'] as String?) ??
          (json['title'] as String?) ??
          'HTTP ${res.statusCode}';
      return AuthException(detail, code: 'http_${res.statusCode}');
    } catch (_) {
      return AuthException(
        'HTTP ${res.statusCode}: ${res.body.isEmpty ? '(empty)' : res.body}',
        code: fallbackCode,
      );
    }
  }
}
