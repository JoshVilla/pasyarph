/// Public web pages linked from the app.
abstract final class AppLinks {
  // TODO(launch): replace with the real domain before release (Prompt 21).
  static const domain = 'pasyar.app';

  static final terms = Uri.https(domain, '/terms');
  static final privacy = Uri.https(domain, '/privacy');

  /// Share link for a loop. Opening it in the app comes with Prompt 18.
  static Uri loop(String id) => Uri.https(domain, '/loop/$id');

  /// Club invite link. Pasting it in Me → JOIN WITH A LINK opens the club;
  /// opening it from outside the app comes with Prompt 18.
  static Uri clubInvite(String code) => Uri.https(domain, '/join/$code');
}
