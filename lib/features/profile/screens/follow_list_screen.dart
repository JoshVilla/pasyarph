import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../clubs/widgets/person_row.dart';
import '../../moderation/widgets/titled_page.dart';

enum FollowList { followers, following }

/// A rider's followers, or who they follow. Tapping one opens their
/// profile.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.userId, required this.list});

  final String userId;
  final FollowList list;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late final SocialRepository _social = context.read<SocialRepository>();
  List<ProfileSummary>? _riders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final riders = widget.list == FollowList.followers
          ? await _social.followers(widget.userId)
          : await _social.following(widget.userId);
      if (!mounted) return;
      setState(() {
        _riders = riders;
        _error = null;
      });
    } on SocialException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final riders = _riders;
    final feed = context.read<FeedRepository>();
    final followers = widget.list == FollowList.followers;
    return TitledPage(
      title: followers ? 'FOLLOWERS' : 'FOLLOWING',
      onRefresh: _load,
      children: [
        if (riders == null)
          _error != null ? PageMessage(_error!) : const PageLoading()
        else if (riders.isEmpty)
          PageMessage(
            followers ? 'No followers yet.' : 'Not following anyone yet.',
          )
        else
          for (final r in riders)
            PersonRow(
              name: r.displayName ?? 'A rider',
              detail: r.username == null ? null : '@${r.username}',
              image: r.avatarUrl == null ? null : feed.avatar(r.avatarUrl!),
              onTap: () => context.push(Routes.rider(r.id)),
            ),
      ],
    );
  }
}
