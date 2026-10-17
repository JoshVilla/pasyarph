import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/widgets.dart';
import '../auth_validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sign_in_state.dart';

/// Opened from the password reset email. No mockup: built from DESIGN.md
/// components. Saving clears the recovery state and the router moves on.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SignInState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitted = false;

  String? get _passwordError =>
      _submitted ? AuthValidators.newPassword(_password.text) : null;
  String? get _confirmError => _submitted
      ? AuthValidators.confirmPassword(_confirm.text, _password.text)
      : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (_passwordError != null || _confirmError != null) return;
    await runMain(() => auth.updatePassword(_password.text));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: const AuthIconBadge(icon: LucideIcons.keyRound),
      title: 'SET NEW PASSWORD',
      subtitle: 'Choose a new password for your Pasyar account.',
      bottom: [
        AuthErrorText(error),
        PrimaryButton(
          label: 'SAVE PASSWORD',
          loading: loading,
          onPressed: _submit,
        ),
        AuthFooterLink(
          text: 'Changed your mind?',
          link: 'Log out',
          onTap: () => auth.signOut(),
        ),
      ],
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              PasyarTextField(
                label: 'New password',
                hint: 'At least ${AuthValidators.minPasswordLength} characters',
                controller: _password,
                password: true,
                error: _passwordError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() => error = null),
              ),
              PasyarTextField(
                label: 'Confirm password',
                controller: _confirm,
                password: true,
                error: _confirmError,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => error = null),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
