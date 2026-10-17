/// Feature switches.
abstract final class Features {
  /// Apple and Google sign-in on Log in and Register. Off for now: email and
  /// password only. The flows are already built (AuthRepository); set this
  /// to true once the providers are set up (see README → Sign-in setup).
  static const socialSignIn = false;
}
