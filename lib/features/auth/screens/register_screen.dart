import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/features.dart';
import '../../../core/links.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sign_in_state.dart';
import '../widgets/social_sign_in.dart';

/// Matches design/screenshots/09-register.png.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SignInState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _termsAccepted = false;
  bool _submitted = false;

  static const _termsRequired =
      'Agree to the Terms and Privacy Policy to continue.';

  String? get _nameError =>
      _submitted ? AuthValidators.fullName(_name.text) : null;
  String? get _emailError =>
      _submitted ? AuthValidators.email(_email.text) : null;
  String? get _passwordError =>
      _submitted ? AuthValidators.newPassword(_password.text) : null;

  void _onEdit(String _) {
    if (_submitted || error != null) setState(() => error = null);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }
    await runMain(() async {
      final email = _email.text.trim();
      final result = await auth.signUp(
        fullName: _name.text,
        email: email,
        password: _password.text,
      );
      if (result == SignUpResult.needsEmailConfirmation && mounted) {
        context.go(
          Uri(
            path: AuthRoutes.checkEmail,
            queryParameters: {'email': email},
          ).toString(),
        );
      }
    });
  }

  void _social(SocialProvider provider) {
    if (!_termsAccepted) {
      setState(() => error = _termsRequired);
      return;
    }
    auth.acceptTermsOnSignIn();
    runSocial(provider);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      gap: 18,
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AuthRoutes.welcome),
      title: 'JOIN THE RIDE',
      subtitle: 'Create your Pasyar account.',
      bottom: [
        AuthErrorText(error),
        PrimaryButton(
          label: 'CREATE ACCOUNT',
          loading: loading,
          onPressed: _termsAccepted && socialBusy == null ? _submit : null,
        ),
        AuthFooterLink(
          text: 'Already have an account?',
          link: 'Log in',
          onTap: () => context.pushReplacement(AuthRoutes.login),
        ),
      ],
      children: [
        if (Features.socialSignIn) ...[
          SocialSignInButtons(
            compact: true,
            busy: socialBusy,
            onApple: () => _social(SocialProvider.apple),
            onGoogle: () => _social(SocialProvider.google),
          ),
          const OrDivider(text: 'or sign up with email'),
        ],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              PasyarTextField(
                label: 'Full name',
                hint: 'Juan Dela Cruz',
                controller: _name,
                error: _nameError,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                onChanged: _onEdit,
              ),
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
                hint: 'At least ${AuthValidators.minPasswordLength} characters',
                controller: _password,
                password: true,
                error: _passwordError,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: _onEdit,
                onSubmitted: (_) => _termsAccepted ? _submit() : null,
              ),
            ],
          ),
        ),
        _TermsCheckbox(
          value: _termsAccepted,
          onChanged: (v) => setState(() {
            _termsAccepted = v;
            if (v && error == _termsRequired) error = null;
          }),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatefulWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<_TermsCheckbox> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open(AppLinks.terms);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(AppLinks.privacy);

  Future<void> _open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = PasyarTextStyles.bodySmall.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: PasyarColors.muted,
    );
    const link = TextStyle(
      fontWeight: FontWeight.w600,
      color: PasyarColors.accentDark,
    );
    return Semantics(
      checked: widget.value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: PasyarCheckbox(value: widget.value, size: 20),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(text: 'Terms', style: link, recognizer: _terms),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: link,
                        recognizer: _privacy,
                      ),
                      const TextSpan(text: ", and I'll ride safely."),
                    ],
                  ),
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
