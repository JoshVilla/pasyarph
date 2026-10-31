import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
import '../../../core/links.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/me_repository.dart';
import '../../../data/repositories/moderation_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// What to type to confirm deleting the account.
const deleteConfirmWord = 'DELETE';

/// Me → Settings: voice prompts, units (always km), what home privacy
/// hides, terms and privacy, log out, and delete account. No mockup:
/// built from DESIGN.md components like the rest of Me.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _delete(BuildContext context) async {
    final me = context.read<MeRepository>();
    final deleted = await showDialog<bool>(
      context: context,
      // Not while it's deleting; the dialog closes itself when done.
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(onDelete: me.deleteAccount),
    );
    if (deleted != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // The user is gone; signing out clears the session and the router goes
    // to Welcome.
    await context.read<AuthProvider>().signOut();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account was deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final auth = context.read<AuthProvider>();
    final top = MediaQuery.paddingOf(context).top;
    final body = PasyarTextStyles.of(
      context,
    ).body.copyWith(color: PasyarColors.of(context).muted);

    return Scaffold(
      backgroundColor: PasyarColors.of(context).background,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          PasyarSpacing.sheet,
          top + 8,
          PasyarSpacing.sheet,
          36,
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RoundIconButton.ground(
              icon: LucideIcons.chevronLeft,
              semanticLabel: 'Back',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.me),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              'SETTINGS',
              style: PasyarTextStyles.of(context).screenTitle(36),
            ),
          ),
          const _Section('APPEARANCE'),
          Text('Theme', style: PasyarTextStyles.of(context).bodyStrong),
          const SizedBox(height: 10),
          SegmentedChoice<ThemeMode>(
            semanticLabel: 'App theme',
            options: const {
              ThemeMode.system: 'System',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            },
            selected: settings.themeMode,
            onChanged: settings.setThemeMode,
          ),
          const SizedBox(height: 8),
          Text(
            'Dark uses the Midnight Blue palette. System follows your device.',
            style: PasyarTextStyles.of(context).label,
          ),
          const _Section('RIDING'),
          PillToggle(
            label: 'Voice prompts',
            value: settings.voicePrompts,
            onChanged: settings.setVoicePrompts,
          ),
          const SizedBox(height: 6),
          Text(
            'Says ride alerts out loud: reaching the main stop, leaving the '
            'loop, and getting back home.',
            style: PasyarTextStyles.of(context).label,
          ),
          const _Section('UNITS'),
          const _InfoPanel(
            icon: LucideIcons.ruler,
            title: 'Kilometers',
            text: 'Pasyar shows every distance in km.',
          ),
          const _Section('PRIVACY'),
          const _InfoPanel(
            icon: LucideIcons.shieldCheck,
            title: 'Home privacy: 800 m hidden',
            text:
                'Loops you share start and end 800 m away from where you '
                "really start, so riders can't find your home. Only you see "
                'the full route.',
          ),
          const SizedBox(height: 10),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'TERMS',
                  onPressed: () => launchUrl(AppLinks.terms),
                ),
              ),
              Expanded(
                child: SecondaryButton(
                  label: 'PRIVACY',
                  onPressed: () => launchUrl(AppLinks.privacy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'BLOCKED RIDERS',
            icon: LucideIcons.ban,
            onPressed: () => context.push(Routes.blockedRiders),
          ),
          const _AdminSection(),
          const _Section('ACCOUNT'),
          if (auth.user?.email case final email?) ...[
            Text(email, style: body),
            const SizedBox(height: 10),
          ],
          SecondaryButton(
            label: 'LOG OUT',
            icon: LucideIcons.logOut,
            onPressed: auth.signOut,
          ),
          const SizedBox(height: PasyarSpacing.buttonGap),
          TextButton(
            onPressed: () => _delete(context),
            style: TextButton.styleFrom(
              foregroundColor: PasyarColors.of(context).accentDark,
              minimumSize: const Size.fromHeight(48),
              textStyle: PasyarTextStyles.of(context).buttonSecondary,
            ),
            child: const Text('DELETE ACCOUNT'),
          ),
          if (Env.isDev) ...[
            const _Section('DEVELOPER'),
            SecondaryButton(
              label: 'WIDGET GALLERY',
              onPressed: () => context.push(Routes.devWidgets),
            ),
          ],
        ],
      ),
    );
  }
}

/// MODERATION → the report queue, shown only to admins.
class _AdminSection extends StatefulWidget {
  const _AdminSection();

  @override
  State<_AdminSection> createState() => _AdminSectionState();
}

class _AdminSectionState extends State<_AdminSection> {
  late final Future<bool> _admin = context
      .read<ModerationRepository>()
      .isAdmin();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _admin,
      builder: (context, snap) => snap.data != true
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Section('MODERATION'),
                SecondaryButton(
                  label: 'REVIEW REPORTS',
                  icon: LucideIcons.flag,
                  onPressed: () => context.push(Routes.moderation),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Text(title, style: PasyarTextStyles.of(context).overline),
    );
  }
}

/// `ground` panel with an icon, a bold line and muted text.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PasyarColors.of(context).ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(icon, size: 22, color: PasyarColors.of(context).accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: PasyarTextStyles.of(context).bodyStrong),
                Text(
                  text,
                  style: PasyarTextStyles.of(
                    context,
                  ).label.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks the rider to type DELETE, then runs [onDelete] with a spinner and
/// pops true once the account is gone. A failure shows in the dialog so
/// the rider can try again. No typing while moving.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.onDelete});

  /// Throws [MeException] when it fails.
  final Future<void> Function() onDelete;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _typed = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } on MeException catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    final ok = _typed.text.trim().toUpperCase() == deleteConfirmWord;
    return PopScope(
      // Back can't interrupt a delete halfway.
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('Delete your account?'),
        content: _deleting
            ? Semantics(
                liveRegion: true,
                child: Row(
                  spacing: 16,
                  children: [
                    SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        color: PasyarColors.of(context).accent,
                        strokeWidth: 3,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Deleting your account and photos…',
                        style: PasyarTextStyles.of(context).body,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  const Text(
                    'This deletes your profile, loops, rides, posts and '
                    "photos, likes, comments and clubs you own. It can't be "
                    'undone.',
                  ),
                  PasyarTextField(
                    label: 'Type $deleteConfirmWord to confirm',
                    controller: _typed,
                    enabled: !moving,
                    textCapitalization: TextCapitalization.characters,
                    error: moving ? 'Stop riding first.' : _error,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
        actions: _deleting
            ? const []
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: ok && !moving ? _delete : null,
                  style: TextButton.styleFrom(
                    foregroundColor: PasyarColors.of(context).accentDark,
                  ),
                  child: const Text('DELETE'),
                ),
              ],
      ),
    );
  }
}
