import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/links.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/feed_repository.dart';
import '../club_rules.dart';
import 'person_row.dart';

/// "Your clubs" on the Me tab: the rider's clubs, CREATE A CLUB and JOIN
/// WITH A LINK. Reloads when a club is made, joined or left.
class MyClubsList extends StatefulWidget {
  const MyClubsList({super.key});

  @override
  State<MyClubsList> createState() => _MyClubsListState();
}

class _MyClubsListState extends State<MyClubsList> {
  late final ClubRepository _clubs = context.read<ClubRepository>();
  List<Club>? _mine;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clubs.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _clubs.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final mine = await _clubs.mine();
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _error = null;
      });
    } on ClubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _joinWithLink() async {
    final code = await showJoinLinkSheet(context);
    if (code != null && mounted) context.push(Routes.joinClub(code));
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final avatars = context.read<FeedRepository>();
    final empty = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text('YOUR CLUBS', style: PasyarTextStyles.screenTitle(24)),
        if (mine == null && _error != null)
          Text(_error!, style: empty)
        else if (mine != null && mine.isEmpty)
          Text(
            'Ride with a group? Make a club and invite riders with a link, '
            'or join one with a link from a friend.',
            style: empty,
          ),
        for (final club in mine ?? const <Club>[])
          PersonRow(
            name: club.name,
            image: club.photoUrl == null
                ? null
                : avatars.avatar(club.photoUrl!),
            detail: clubSubtitle(club),
            onTap: () => context.push(Routes.club(club.id)),
          ),
        SecondaryButton(
          label: 'CREATE A CLUB',
          onPressed: () => context.push(Routes.newClub),
        ),
        SecondaryButton(label: 'JOIN WITH A LINK', onPressed: _joinWithLink),
      ],
    );
  }
}

/// Asks for an invite link and returns its code, or null if cancelled.
Future<String?> showJoinLinkSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _JoinLinkSheet(),
  );
}

class _JoinLinkSheet extends StatefulWidget {
  const _JoinLinkSheet();

  @override
  State<_JoinLinkSheet> createState() => _JoinLinkSheetState();
}

class _JoinLinkSheetState extends State<_JoinLinkSheet> {
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _submit() {
    final code = parseInviteCode(_link.text);
    if (code == null) {
      setState(() => _error = "That doesn't look like a Pasyar invite link.");
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: BottomSheetPanel(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + (media.viewInsets.bottom > 0 ? 0 : media.viewPadding.bottom),
        ),
        children: [
          Text('JOIN A CLUB', style: PasyarTextStyles.screenTitle(24)),
          PasyarTextField(
            label: 'Invite link',
            hint: '${AppLinks.domain}/join/…',
            controller: _link,
            error: _error,
            helper: moving ? 'Stop riding to paste a link.' : null,
            enabled: !moving,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          PrimaryButton(label: 'CONTINUE', onPressed: moving ? null : _submit),
        ],
      ),
    );
  }
}
