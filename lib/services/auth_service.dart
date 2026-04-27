import 'dart:async';
import 'dart:math';

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
