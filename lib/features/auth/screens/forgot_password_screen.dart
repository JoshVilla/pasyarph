import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sign_in_state.dart';

/// No mockup: built from DESIGN.md components in the Log in layout.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SignInState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _submitted = false;
  String? _sentTo;

  String? get _emailError =>
      _submitted ? AuthValidators.email(_email.text) : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (_emailError != null) return;
    final email = _email.text.trim();
    await runMain(() async {
      await auth.sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    });
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AuthRoutes.login);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sentTo != null) {
      return AuthScaffold(
        onBack: _back,
        title: 'CHECK YOUR EMAIL',
        subtitle:
            'If there is a Pasyar account for $_sentTo, we sent it a link to '
            'set a new password.',
        bottom: [
          PrimaryButton(label: 'BACK TO LOG IN', onPressed: _back),
          AuthFooterLink(
            text: 'Wrong email?',
            link: 'Try again',
            onTap: () => setState(() => _sentTo = null),
          ),
        ],
        children: const [
          SafetyRow(
            icon: LucideIcons.mail,
            lead: 'Open the link on this phone.',
            text: ' It brings you back to Pasyar to choose a new password.',
          ),
        ],
      );
    }

    return AuthScaffold(
      onBack: _back,
      title: 'FORGOT PASSWORD',
      subtitle: "Enter your email and we'll send you a link to set a new one.",
      bottom: [
        AuthErrorText(error),
        PrimaryButton(
          label: 'SEND RESET LINK',
          icon: LucideIcons.mail,
          loading: loading,
          onPressed: _submit,
        ),
        AuthFooterLink(text: 'Remembered it?', link: 'Log in', onTap: _back),
      ],
      children: [
        PasyarTextField(
          label: 'Email',
          hint: 'you@email.com',
          controller: _email,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() => error = null),
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}
