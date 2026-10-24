import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet (Messenger, SMS, …). Provided at the top
/// of the app so tests can see what would be shared.
abstract interface class Sharer {
  Future<void> share(String text, {String? subject});
}

class PlatformSharer implements Sharer {
  const PlatformSharer();

  @override
  Future<void> share(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));
}
