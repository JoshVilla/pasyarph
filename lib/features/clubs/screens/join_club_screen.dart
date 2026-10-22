import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/widgets/auth_scaffold.dart';
import '../club_rules.dart';

/// Opened from an invite link: which club it is, and JOIN CLUB.
class JoinClubScreen extends StatefulWidget {
  const JoinClubScreen({super.key, required this.code});

  final String code;

  @override
  State<JoinClubScreen> createState() => _JoinClubScreenState();
}

class _JoinClubScreenState extends State<JoinClubScreen> {
  late final ClubRepository _clubs = context.read<ClubRepository>();
  Club? _club;
  bool _loading = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final club = await _clubs.byInvite(widget.code);
      if (!mounted) return;
      setState(() {
        _club = club;
        if (club == null) _error = ClubException.inviteNotFound.message;
      });
    } on ClubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final id = await _clubs.join(widget.code);
      if (mounted) context.pushReplacement(Routes.club(id));
    } on ClubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.me);

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return AuthScaffold(
      title: "YOU'RE INVITED",
      subtitle: club == null
          ? null
          : (club.isMember
                ? "You're already in this club."
                : "Join to see the club's loops and rides."),
      onBack: _back,
      bottom: [
        AuthErrorText(club == null ? null : _error),
        if (club != null)
          PrimaryButton(
            label: club.isMember ? 'OPEN CLUB' : 'JOIN CLUB',
            loading: _joining,
            onPressed: club.isMember
                ? () => context.pushReplacement(Routes.club(club.id))
                : _join,
          )
        else if (!_loading)
          SecondaryButton(label: 'TRY AGAIN', onPressed: _load),
      ],
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: PasyarColors.accent),
            ),
          )
        else if (club == null)
          Text(
            _error ?? '',
            style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PasyarColors.ground,
              borderRadius: BorderRadius.circular(PasyarRadius.panel),
            ),
            child: Row(
              spacing: 14,
              children: [
                Avatar(
                  name: club.name,
                  image: club.photoUrl == null
                      ? null
                      : context.read<FeedRepository>().avatar(club.photoUrl!),
                  size: 64,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(club.name, style: PasyarTextStyles.screenTitle(26)),
                      if (club.memberCount case final n?)
                        Text(memberCount(n), style: PasyarTextStyles.label),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
