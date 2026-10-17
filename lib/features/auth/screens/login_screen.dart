import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/features.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sign_in_state.dart';
import '../widgets/social_sign_in.dart';

/// Matches design/screenshots/08-login.png.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SignInState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;

  String? get _emailError =>
      _submitted ? AuthValidators.email(_email.text) : null;
  String? get _passwordError =>
      _submitted ? AuthValidators.loginPassword(_password.text) : null;

  void _onEdit(String _) {
    if (_submitted || error != null) setState(() => error = null);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (_emailError != null || _passwordError != null) return;
    // On success the router moves on by itself.
    await runMain(() => auth.signInWithPassword(_email.text, _password.text));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AuthRoutes.welcome),
      title: 'WELCOME BACK',
      subtitle: 'Log in to keep riding.',
      bottom: [
        AuthErrorText(error),
        PrimaryButton(
          label: 'LOG IN',
          loading: loading,
          onPressed: socialBusy == null ? _submit : null,
        ),
        AuthFooterLink(
          text: 'New here?',
          link: 'Create an account',
          onTap: () => context.pushReplacement(AuthRoutes.register),
        ),
      ],
      children: [
        if (Features.socialSignIn) ...[
          SocialSignInButtons(
            busy: socialBusy,
            onApple: () => runSocial(SocialProvider.apple),
            onGoogle: () => runSocial(SocialProvider.google),
          ),
          const OrDivider(text: 'or log in with email'),
        ],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              PasyarTextField(
                label: 'Email',
                hint: 'you@email.com',
                controller: _email,
                error: _emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: _onEdit,
              ),
              PasyarTextField(
                label: 'Password',
                controller: _password,
                password: true,
                error: _passwordError,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: _onEdit,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AuthTextLink(
                  label: 'Forgot password?',
                  onTap: () => context.push(
                    Uri(
                      path: AuthRoutes.forgotPassword,
                      queryParameters: {
                        if (_email.text.trim().isNotEmpty)
                          'email': _email.text.trim(),
                      },
                    ).toString(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
