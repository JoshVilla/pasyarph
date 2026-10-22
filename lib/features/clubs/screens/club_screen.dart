import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../feed/providers/feed_provider.dart';
import '../../feed/widgets/feed_items.dart';
import '../club_rules.dart';
import '../providers/club_controller.dart';
import '../widgets/person_row.dart';

/// A club's page: photo, name, members, and the club's rides and loops.
/// The owner invites riders with a link; members can leave. Expects a
/// [ClubController] and a [FeedProvider] for the club above it.
class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _scroll = ScrollController();
  late final ClubController _club = context.read<ClubController>();
  late final FeedProvider _feed = context.read<FeedProvider>();

  /// Members shown before SHOW ALL.
  static const _firstMembers = 5;
  bool _allMembers = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 1200) _feed.loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await _club.load();
    if (mounted && (_club.club?.isMember ?? false)) _feed.start();
  }

  Future<void> _refresh() async {
    await _club.load();
    if (_club.club?.isMember ?? false) await _feed.refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.me);

  Future<void> _copyInvite({bool reset = false}) async {
    try {
      final link = reset
          ? await _club.resetInviteLink()
          : await _club.inviteLink();
      await Clipboard.setData(ClipboardData(text: link.toString()));
      if (!mounted) return;
      _snack(
        reset
            ? 'New invite link copied. The old one no longer works.'
            : 'Invite link copied. Send it to riders you want in the club.',
      );
    } on ClubException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _leave(Club club) async {
    if (!await _confirm(
      'Leave ${club.name}?',
      "You won't see the club's loops and rides anymore. You can join "
          'again with an invite link.',
      'Leave',
    )) {
      return;
    }
    final error = await _club.leave();
    if (!mounted) return;
    if (error != null) return _snack(error);
    _snack('You left ${club.name}.');
    _back();
  }

  Future<void> _delete(Club club) async {
    if (!await _confirm(
      'Delete ${club.name}?',
      "Members lose access to the club. Its loops become private to the "
          'riders who made them. This can\'t be undone.',
      'Delete',
    )) {
      return;
    }
    final error = await _club.delete();
    if (!mounted) return;
    if (error != null) return _snack(error);
    _snack('${club.name} was deleted.');
    _back();
  }

  Future<void> _ownerOptions(Club club) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetPanel(
        gap: 4,
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          const SizedBox(height: 8),
          _SheetOption(
            icon: LucideIcons.refreshCw,
            label: 'Make a new invite link',
            onTap: () => Navigator.pop(context, 'reset'),
          ),
          _SheetOption(
            icon: LucideIcons.trash2,
            label: 'Delete club',
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'reset':
        await _copyInvite(reset: true);
      case 'delete':
        await _delete(club);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ClubController>();
    final feed = context.watch<FeedProvider>();
    final club = c.club;

    final items = <Widget>[
      _Header(
        club: club,
        loading: c.loading,
        busy: c.busy,
        message: c.notFound
            ? "This club doesn't exist anymore."
            : (club == null ? c.error : null),
        onBack: _back,
        onOptions: club != null && club.isOwner
            ? () => _ownerOptions(club)
            : null,
        onInvite: () => _copyInvite(),
        onLeave: club == null ? null : () => _leave(club),
      ),
      if (club != null && club.isMember) ...[
        if (c.members case final members?)
          _Members(
            members: _allMembers
                ? members
                : members.take(_firstMembers).toList(),
            total: members.length,
            onShowAll: members.length > _firstMembers && !_allMembers
                ? () => setState(() => _allMembers = true)
                : null,
            onOpen: (m) => context.push(Routes.rider(m.userId)),
          ),
        ...feedPostItems(
          feed,
          now: widget.clock(),
          actions: feedCardActions(context, feed, clock: widget.clock),
          repo: context.read<FeedRepository>(),
          emptyText:
              'No club rides yet. In Create, save a loop as Group and pick '
              '${club.name} to share it here.',
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: PasyarColors.line,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => items[i],
        ),
      ),
    );
  }
}

/// White top band: back (and the owner's options), photo, name, role and
/// member count, and INVITE RIDERS or LEAVE CLUB.
class _Header extends StatelessWidget {
  const _Header({
    required this.club,
    required this.loading,
    required this.busy,
    required this.onBack,
    required this.onInvite,
    this.message,
    this.onOptions,
    this.onLeave,
  });

  final Club? club;
  final bool loading;
  final bool busy;
  final String? message;
  final VoidCallback onBack;
  final VoidCallback? onOptions;
  final VoidCallback onInvite;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final club = this.club;
    final muted = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);
    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PasyarSpacing.screen,
          top + 8,
          PasyarSpacing.screen,
          PasyarSpacing.sheet,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RoundIconButton.ground(
                  icon: LucideIcons.chevronLeft,
                  semanticLabel: 'Back',
                  onPressed: onBack,
                ),
                const Spacer(),
                if (onOptions != null)
                  RoundIconButton.ground(
                    icon: LucideIcons.ellipsis,
                    iconSize: 20,
                    semanticLabel: 'Club options',
                    onPressed: onOptions,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (club == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: PasyarColors.accent,
                        ),
                      )
                    : Text(
                        message ?? '',
                        textAlign: TextAlign.center,
                        style: muted,
                      ),
              )
            else ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Avatar(
                  name: club.name,
                  image: club.photoUrl == null
                      ? null
                      : context.read<FeedRepository>().avatar(club.photoUrl!),
                  size: 88,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(club.name, style: PasyarTextStyles.screenTitle(32)),
              ),
              Text(clubSubtitle(club), style: PasyarTextStyles.label),
              const SizedBox(height: PasyarSpacing.groupGap),
              switch (club.myRole) {
                ClubRole.owner => PrimaryButton(
                  label: 'INVITE RIDERS',
                  icon: LucideIcons.link,
                  loading: busy,
                  onPressed: onInvite,
                ),
                ClubRole.member => SecondaryButton(
                  label: 'LEAVE CLUB',
                  onPressed: busy ? null : onLeave,
                ),
                null => Text(
                  "Only members see this club's rides. Ask the owner for an "
                  'invite link.',
                  style: muted,
                ),
              },
            ],
          ],
        ),
      ),
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({
    required this.members,
    required this.total,
    required this.onOpen,
    this.onShowAll,
  });

  final List<ClubMember> members;
  final int total;
  final ValueChanged<ClubMember> onOpen;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final avatars = context.read<FeedRepository>();
    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PasyarSpacing.screen,
          PasyarSpacing.groupGap,
          PasyarSpacing.screen,
          8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MEMBERS', style: PasyarTextStyles.screenTitle(24)),
            const SizedBox(height: 4),
            for (final m in members)
              PersonRow(
                name: m.profile?.displayName ?? 'A rider',
                image: switch (m.profile?.avatarUrl) {
                  final url? => avatars.avatar(url),
                  null => null,
                },
                detail: m.role == ClubRole.owner ? 'Owner' : null,
                onTap: () => onOpen(m),
              ),
            if (onShowAll != null)
              TextButton(
                onPressed: onShowAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(PasyarSpacing.minTouch),
                  foregroundColor: PasyarColors.accentDark,
                ),
                child: Text(
                  'SHOW ALL ${memberCount(total).toUpperCase()}',
                  style: PasyarTextStyles.buttonSecondary.copyWith(
                    fontSize: 16,
                    color: PasyarColors.accentDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PasyarRadius.input),
        child: SizedBox(
          height: 56,
          child: Row(
            spacing: 14,
            children: [
              Icon(icon, size: 22, color: PasyarColors.ink),
              Text(label, style: PasyarTextStyles.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
