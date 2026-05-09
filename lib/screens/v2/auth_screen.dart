import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/auth.dart';
import '../../services/auth_service.dart';
import '../../state/auth_controller.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/buttons.dart';
import '../../widgets/forms.dart';

enum AuthMode { signIn, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signIn;
  AuthIdentifierType _method = AuthIdentifierType.phone;
  bool _otpSent = false;
  final _idController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      final l10n = context.l10n;
      _showError(_method == AuthIdentifierType.phone
          ? l10n.authEnterPhoneFirst
          : l10n.authEnterEmailFirst);
      return;
    }
    try {
      await context
          .read<AuthController>()
          .startOtp(identifier: id, type: _method);
      if (!mounted) return;
      setState(() => _otpSent = true);
    } catch (e) {
      if (!mounted) return;
      _showError(_describe(e));
    }
  }

  Future<void> _verifyOtp() async {
    final id = _idController.text.trim();
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError(context.l10n.authEnterSixDigitCode);
      return;
    }
    try {
      await context
          .read<AuthController>()
          .verifyOtp(identifier: id, code: code);
      // Router redirect picks up the auth state change and navigates.
    } catch (e) {
      if (!mounted) return;
      _showError(_describe(e));
    }
  }

  Future<void> _signInWithApple() async {
    try {
      // Real Apple Sign-In is not wired yet; the mock returns a synthetic
      // session so the rest of the flow stays testable end-to-end.
      await context.read<AuthController>().signInWithApple(
            identityToken: 'mock-identity-token',
            nonce: 'mock-nonce',
          );
    } catch (e) {
      if (!mounted) return;
      _showError(_describe(e));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await context
          .read<AuthController>()
          .signInWithGoogle(idToken: 'mock-id-token');
    } catch (e) {
      if (!mounted) return;
      _showError(_describe(e));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _describe(Object e) {
    if (e is AuthException) {
      if (e.code == 'invalid_otp') return context.l10n.authInvalidCode;
      return e.message;
    }
    return context.l10n.authSomethingWentWrong(e.toString());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    final auth = context.watch<AuthController>();
    final isRegister = _mode == AuthMode.register;
    final busy = auth.isBusy;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.accent, c.accentStrong],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                isRegister ? l10n.authCreateAccount : l10n.authWelcomeBack,
                style: DCText.inter(
                    size: 30,
                    weight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -0.75),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister ? l10n.authSignUpSubtitle : l10n.authSignInSubtitle,
                style: DCText.inter(
                    size: 15, weight: FontWeight.w500, color: c.textDim),
              ),
              const SizedBox(height: 28),
              DCSegmented<AuthIdentifierType>(
                values: const [
                  AuthIdentifierType.phone,
                  AuthIdentifierType.email
                ],
                labels: [l10n.authPhone, l10n.authEmail],
                selected: _method,
                onChanged: (v) {
                  if (busy) return;
                  setState(() {
                    _method = v;
                    _otpSent = false;
                    _otpController.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              DCInputField(
                controller: _idController,
                hint: _method == AuthIdentifierType.phone
                    ? '+1 555 0100'
                    : 'you@example.com',
                keyboardType: _method == AuthIdentifierType.phone
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                DCInputField(
                  controller: _otpController,
                  hint: '000000',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  mono: true,
                ),
              ],
              if (isRegister) ...[
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: DCText.inter(
                        size: 12, weight: FontWeight.w500, color: c.textDim),
                    children: [
                      TextSpan(text: l10n.authAgreementPrefix),
                      TextSpan(
                          text: l10n.authTerms,
                          style: TextStyle(color: c.accent)),
                      TextSpan(text: l10n.authAgreementMiddle),
                      TextSpan(
                          text: l10n.authPrivacyPolicy,
                          style: TextStyle(color: c.accent)),
                      TextSpan(text: l10n.authAgreementSuffix),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              DCButton(
                label: !_otpSent
                    ? (busy ? l10n.authSending : l10n.authSendVerificationCode)
                    : (busy
                        ? l10n.authVerifying
                        : (isRegister
                            ? l10n.authCreateAccount
                            : l10n.authSignIn)),
                onPressed: busy ? null : (!_otpSent ? _sendOtp : _verifyOtp),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: c.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(l10n.authOr,
                        style: DCText.mono(
                            size: 11,
                            weight: FontWeight.w500,
                            color: c.textFaint)),
                  ),
                  Expanded(child: Divider(color: c.border)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DCButton.secondary(
                      label: l10n.authApple,
                      leadingIcon: Icons.apple,
                      onPressed: busy ? null : _signInWithApple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DCButton.secondary(
                      label: l10n.authGoogle,
                      leadingIcon: Icons.g_mobiledata,
                      onPressed: busy ? null : _signInWithGoogle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: busy
                      ? null
                      : () => setState(() {
                            _mode = isRegister
                                ? AuthMode.signIn
                                : AuthMode.register;
                            _otpSent = false;
                            _otpController.clear();
                          }),
                  child: Text.rich(
                    TextSpan(
                      style: DCText.inter(
                          size: 14, weight: FontWeight.w500, color: c.textDim),
                      children: [
                        TextSpan(
                            text: isRegister
                                ? l10n.authAlreadyHaveAccount
                                : l10n.authDontHaveAccount),
                        TextSpan(
                          text:
                              isRegister ? l10n.authSignIn : l10n.authRegister,
                          style: TextStyle(
                              color: c.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
