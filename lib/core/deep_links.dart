/// Share link paths the app opens: `/l/<loop>`, `/p/<post>`,
/// `/join/<code>`.
bool isShareLinkPath(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  return segments.length == 2 && const {'l', 'p', 'join'}.contains(segments[0]);
}

/// Remembers a share link opened before the rider could see it (signed
/// out, loading, onboarding) so they land on it once they're in, instead
/// of on Home. Pure so it can be unit tested.
class PendingLink {
  String? _path;

  String? get path => _path;

  /// Wraps the auth redirect: [target] is where it sends [path], [home]
  /// where signed-in riders go from the auth screens.
  String? redirect({
    required String path,
    required String? target,
    required String home,
  }) {
    if (target != null && target != home && isShareLinkPath(path)) {
      _path = path;
      return target;
    }
    if (target == home && _path != null) {
      final saved = _path;
      _path = null;
      return saved;
    }
    return target;
  }
}
