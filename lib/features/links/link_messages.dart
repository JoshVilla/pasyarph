import '../../data/models/link_preview.dart';

/// Title and text for a link the rider can't open.
class LinkMessage {
  const LinkMessage(this.title, this.text);

  final String title;
  final String text;
}

/// Why [preview] can't be opened, for a loop or a post ([what]); null when
/// it can.
LinkMessage? blockedLinkMessage(LinkPreview preview, {required String what}) {
  final thing = what.toLowerCase();
  return switch (preview.status) {
    LinkStatus.ok => null,
    LinkStatus.club => LinkMessage(
      'CLUB $what',
      'This $thing is for members of ${preview.clubName ?? 'a club'}. Ask a '
          "member for the club's invite link, then open it to join.",
    ),
    LinkStatus.private => LinkMessage(
      'PRIVATE $what',
      'Only the rider who made this $thing can open it.',
    ),
    LinkStatus.missing => LinkMessage(
      '$what NOT FOUND',
      'This $thing may have been deleted, or the link is incomplete.',
    ),
  };
}
