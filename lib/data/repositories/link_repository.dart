import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json.dart';
import '../models/link_preview.dart';

/// Couldn't check a link, with a message safe to show riders.
class LinkException implements Exception {
  const LinkException(this.message);

  final String message;

  static const offline = LinkException(
    "Couldn't open the link. Check your connection and try again.",
  );
}

/// Kinds of share links (`link_preview()` p_kind).
enum LinkKind { loop, post }

abstract interface class LinkRepository {
  /// Whether the rider may open the loop or post a link points at. Throws
  /// [LinkException].
  Future<LinkPreview> preview(LinkKind kind, String id);
}

class SupabaseLinkRepository implements LinkRepository {
  SupabaseLinkRepository(this._client);

  final SupabaseClient _client;

  /// Link ids are UUIDs; anything else is a broken link, not an error.
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<LinkPreview> preview(LinkKind kind, String id) async {
    if (!_uuid.hasMatch(id)) {
      return const LinkPreview(status: LinkStatus.missing);
    }
    try {
      final json = await _client.rpc<Json>(
        'link_preview',
        params: {'p_kind': kind.name, 'p_id': id},
      );
      return LinkPreview.fromJson(json);
    } on Exception catch (e) {
      debugPrint('links: link_preview($kind, $id) failed: $e');
      throw LinkException.offline;
    }
  }
}
