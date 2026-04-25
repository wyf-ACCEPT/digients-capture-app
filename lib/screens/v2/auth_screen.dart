import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/forms.dart';

enum AuthMode { signIn, register }
enum AuthMethod { phone, email }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signIn;
  AuthMethod _method = AuthMethod.phone;
  bool _otpSent = false;
  final _idController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onAuth() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final isRegister = _mode == AuthMode.register;
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
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                isRegister ? 'Create account' : 'Welcome back',
                style: DCText.inter(size: 30, weight: FontWeight.w700, color: c.text, letterSpacing: -0.75),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister
                    ? 'Sign up to start contributing recordings.'
                    : 'Sign in to continue capturing.',
                style: DCText.inter(size: 15, weight: FontWeight.w500, color: c.textDim),
              ),
              const SizedBox(height: 28),
              DCSegmented<AuthMethod>(
                values: const [AuthMethod.phone, AuthMethod.email],
                labels: const ['Phone', 'Email'],
                selected: _method,
                onChanged: (v) => setState(() => _method = v),
              ),
              const SizedBox(height: 16),
              DCInputField(
                controller: _idController,
                hint: _method == AuthMethod.phone ? '+1 555 0100' : 'you@example.com',
                keyboardType:
                    _method == AuthMethod.phone ? TextInputType.phone : TextInputType.emailAddress,
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
                const SizedBox(height: 4),
                Text(
                  'Code sent · 60s',
                  style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim),
                ),
              ],
              if (isRegister) ...[
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: DCText.inter(size: 12, weight: FontWeight.w500, color: c.textDim),
                    children: [
                      const TextSpan(text: 'By creating an account you agree to our '),
                      TextSpan(text: 'Terms', style: TextStyle(color: c.accent)),
                      const TextSpan(text: ' and '),
                      TextSpan(text: 'Privacy Policy', style: TextStyle(color: c.accent)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              DCButton(
                label: !_otpSent
                    ? 'Send verification code'
                    : (isRegister ? 'Create account' : 'Sign in'),
                onPressed: () {
                  if (!_otpSent) {
                    setState(() => _otpSent = true);
                  } else {
                    _onAuth();
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: c.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textFaint)),
                  ),
                  Expanded(child: Divider(color: c.border)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: DCButton.secondary(label: 'Apple', leadingIcon: Icons.apple, onPressed: _onAuth)),
                  const SizedBox(width: 10),
                  Expanded(child: DCButton.secondary(label: 'Google', leadingIcon: Icons.g_mobiledata, onPressed: _onAuth)),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _mode = isRegister ? AuthMode.signIn : AuthMode.register;
                    _otpSent = false;
                  }),
                  child: Text.rich(
                    TextSpan(
                      style: DCText.inter(size: 14, weight: FontWeight.w500, color: c.textDim),
                      children: [
                        TextSpan(text: isRegister ? 'Already have an account? ' : "Don't have an account? "),
                        TextSpan(
                          text: isRegister ? 'Sign in' : 'Register',
                          style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
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
