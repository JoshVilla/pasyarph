/// Inline validation for the auth forms. Each returns an error message, or
/// null when the value is fine.
abstract final class AuthValidators {
  static const minPasswordLength = 8;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(v)) return 'Enter a valid email, like you@email.com.';
    return null;
  }

  /// Log in only checks that something was typed; the server decides.
  static String? loginPassword(String value) =>
      value.isEmpty ? 'Enter your password.' : null;

  static String? newPassword(String value) {
    if (value.isEmpty) return 'Enter a password.';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    return null;
  }

  static String? fullName(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your name.';
    if (v.length < 2) return 'Name is too short.';
    if (v.length > 60) return 'Name is too long.';
    return null;
  }

  static String? confirmPassword(String value, String password) =>
      value == password ? null : 'Passwords don\'t match.';
}
