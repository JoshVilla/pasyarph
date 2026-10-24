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
import '../../auth/providers/auth_provider.dart';

/// What to type to confirm deleting the account.
const deleteConfirmWord = 'DELETE';

/// Me → Settings: voice prompts, units (always km), what home privacy
/// hides, terms and privacy, log out, and delete account. No mockup:
/// built from DESIGN.md components like the rest of Me.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<MeRepository>().deleteAccount();
      if (!context.mounted) return;
      // The user is gone; signing out clears the session and the router
      // goes to Welcome.
      await context.read<AuthProvider>().signOut();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
    } on MeException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final auth = context.read<AuthProvider>();
    final top = MediaQuery.paddingOf(context).top;
    final body = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);

    return Scaffold(
      backgroundColor: PasyarColors.card,
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
            child: Text('SETTINGS', style: PasyarTextStyles.screenTitle(36)),
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
            style: PasyarTextStyles.label,
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
              foregroundColor: PasyarColors.accentDark,
              minimumSize: const Size.fromHeight(48),
              textStyle: PasyarTextStyles.buttonSecondary,
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

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Text(title, style: PasyarTextStyles.overline),
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
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(icon, size: 22, color: PasyarColors.accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: PasyarTextStyles.bodyStrong),
                Text(
                  text,
                  style: PasyarTextStyles.label.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks the rider to type DELETE. Pops true to delete. No typing while
/// moving.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    final ok = _typed.text.trim().toUpperCase() == deleteConfirmWord;
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text(
            'This deletes your profile, loops, rides, posts and photos, '
            "likes, comments and clubs you own. It can't be undone.",
          ),
          PasyarTextField(
            label: 'Type $deleteConfirmWord to confirm',
            controller: _typed,
            enabled: !moving,
            textCapitalization: TextCapitalization.characters,
            error: moving ? 'Stop riding first.' : null,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: ok && !moving
              ? () => Navigator.of(context).pop(true)
              : null,
          style: TextButton.styleFrom(foregroundColor: PasyarColors.accentDark),
          child: const Text('DELETE'),
        ),
      ],
    );
  }
}
