import 'package:pasyarph/core/share.dart';
import 'package:pasyarph/data/models/link_preview.dart';
import 'package:pasyarph/data/repositories/link_repository.dart';

/// Answers [previews] by id (missing otherwise); throws when [fail] is set.
class FakeLinkRepository implements LinkRepository {
  FakeLinkRepository([Map<String, LinkPreview>? previews])
    : previews = previews ?? {};

  final Map<String, LinkPreview> previews;
  final calls = <(LinkKind, String)>[];
  bool fail = false;

  @override
  Future<LinkPreview> preview(LinkKind kind, String id) async {
    calls.add((kind, id));
    if (fail) throw LinkException.offline;
    return previews[id] ?? const LinkPreview(status: LinkStatus.missing);
  }
}

/// Records what would have gone to the share sheet.
class FakeSharer implements Sharer {
  final shared = <String>[];

  @override
  Future<void> share(String text, {String? subject}) async => shared.add(text);
}
