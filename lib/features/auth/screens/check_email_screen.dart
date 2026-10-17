import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sign_in_state.dart';

/// After email sign-up when Supabase requires email confirmation.
/// No mockup: built from DESIGN.md components.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen>
    with SignInState<CheckEmailScreen> {
  static const cooldown = 60;

  Timer? _timer;
  int _secondsLeft = cooldown;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    // The confirmation email was just sent by sign-up.
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    await runMain(() async {
      await auth.resendSignUpEmail(widget.email);
      if (mounted) {
        setState(() => _resent = true);
        _startCooldown();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _secondsLeft > 0;
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return AuthScaffold(
      leading: const AuthIconBadge(icon: LucideIcons.mail),
      title: 'CHECK YOUR EMAIL',
      subtitle:
          'We sent a link to ${widget.email}. Tap it on this phone to finish '
          'creating your account.',
      bottom: [
        AuthErrorText(error),
        PrimaryButton(
          label: waiting ? 'RESEND IN $m:$s' : 'RESEND EMAIL',
          loading: loading,
          onPressed: waiting ? null : _resend,
        ),
        AuthFooterLink(
          text: '',
          link: 'Back to log in',
          onTap: () => context.go(AuthRoutes.login),
        ),
      ],
      children: [
        SafetyRow(
          icon: _resent ? LucideIcons.check : LucideIcons.inbox,
          lead: _resent ? 'Sent again.' : "Can't find it?",
          text: ' Check your spam or promotions folder.',
        ),
      ],
    );
  }
}
