import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/widgets.dart';
import '../auth_errors.dart';
import '../providers/auth_provider.dart';

/// Busy/error handling shared by the Log in and Register screens.
mixin SignInState<T extends StatefulWidget> on State<T> {
  bool loading = false;
  SocialProvider? socialBusy;
  String? error;

  bool get busy => loading || socialBusy != null;

  AuthProvider get auth => context.read<AuthProvider>();

  /// Runs an email action with the main button's spinner.
  Future<void> runMain(Future<void> Function() action) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Runs a Google or Apple sign-in. Cancelling is not an error.
  Future<void> runSocial(SocialProvider provider) async {
    if (busy) return;
    setState(() {
      socialBusy = provider;
      error = null;
    });
    try {
      await switch (provider) {
        SocialProvider.apple => auth.signInWithApple(),
        SocialProvider.google => auth.signInWithGoogle(),
      };
    } on SignInCancelled {
      // User closed the sheet.
    } catch (e) {
      if (mounted) setState(() => error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => socialBusy = null);
    }
  }
}
