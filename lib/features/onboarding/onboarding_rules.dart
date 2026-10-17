/// Field rules for the rider profile step.
abstract final class OnboardingRules {
  static const riderNameMin = 2;
  static const riderNameMax = 30;
  static const homeAreaMax = 60;

  static String? riderName(String value) {
    final v = value.trim();
    if (v.length < riderNameMin) {
      return 'Use at least $riderNameMin characters.';
    }
    if (v.length > riderNameMax) {
      return 'Use at most $riderNameMax characters.';
    }
    return null;
  }

  /// Optional. Town only (e.g. "Cordon, Isabela"): numbers usually mean a
  /// street or house number, which we never store.
  static String? homeArea(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    if (v.length > homeAreaMax) return 'Keep it to your town and province.';
    if (RegExp(r'\d').hasMatch(v)) {
      return 'Town only. No street or house number.';
    }
    return null;
  }

  /// Rider name suggestion from the account's full name: the first word,
  /// cut to the maximum length. "Juan Dela Cruz" → "Juan".
  static String suggestRiderName(String? fullName) {
    final first = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
    return first.length > riderNameMax
        ? first.substring(0, riderNameMax)
        : first;
  }
}
