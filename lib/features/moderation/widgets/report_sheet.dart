import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/moderation_repository.dart';
import '../moderation_rules.dart';

/// What a report sheet is about.
class ReportSubject {
  const ReportSubject({
    required this.target,
    required this.id,
    required this.what,
    this.authorId,
    this.authorName,
  });

  final ReportTarget target;
  final String id;

  /// "post", "comment", "loop" or "rider", for the title.
  final String what;

  /// Offers "Also block …" when set (never for the rider's own things).
  final String? authorId;
  final String? authorName;
}

/// Report something: pick a reason, optionally add details, optionally
/// block its author too. Returns true when reported (and whether the
/// author was blocked, via [ReportResult]).
Future<ReportResult?> showReportSheet(
  BuildContext context,
  ReportSubject subject,
) {
  return showModalBottomSheet<ReportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReportSheet(subject: subject),
  );
}

class ReportResult {
  const ReportResult({required this.blocked});

  final bool blocked;
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.subject});

  final ReportSubject subject;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _block = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason!;
    final s = widget.subject;
    final moderation = context.read<ModerationRepository>();
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await moderation.report(
        s.target,
        s.id,
        reportReasonText(reason, _details.text),
      );
      if (_block && s.authorId != null) await moderation.block(s.authorId!);
      if (mounted) Navigator.of(context).pop(ReportResult(blocked: _block));
    } on ModerationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final moving = context.watch<LocationProvider>().isMoving;
    final reason = _reason;
    final canSend =
        reason != null &&
        !reportNeedsDetails(reason, _details.text) &&
        !_sending &&
        // Sending counts as posting: not while riding.
        !moving;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: BottomSheetPanel(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            media.viewPadding.bottom + 20,
          ),
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Text(
                      'REPORT ${s.what.toUpperCase()}',
                      style: PasyarTextStyles.screenTitle(28),
                    ),
                    Text(
                      "What's wrong with it? Moderators check every report. "
                      "The rider isn't told who reported them.",
                      style: PasyarTextStyles.label.copyWith(fontSize: 14),
                    ),
                    for (final r in ReportReason.values)
                      ChoiceCard(
                        title: r.label.toUpperCase(),
                        selected: r == reason,
                        onTap: () => setState(() => _reason = r),
                      ),
                    PasyarTextField(
                      label: reason == ReportReason.other
                          ? 'Tell us more'
                          : 'Details (optional)',
                      controller: _details,
                      maxLength: 300,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (s.authorId != null)
                      PillToggle(
                        label: 'Also block ${s.authorName ?? 'this rider'}',
                        value: _block,
                        onChanged: (v) => setState(() => _block = v),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null || moving)
              Text(
                _error ?? 'Stop riding to send a report.',
                textAlign: TextAlign.center,
                style: PasyarTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PasyarColors.accentDark,
                ),
              ),
            PrimaryButton(
              label: 'SEND REPORT',
              loading: _sending,
              onPressed: canSend ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks first, then blocks [name]. Returns true when blocked.
Future<bool> confirmBlock(
  BuildContext context, {
  required String userId,
  required String name,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $name?'),
      content: Text(
        "You won't see $name's rides, loops or comments, and you'll stop "
        "following each other. $name isn't told. You can unblock them in "
        'Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: PasyarColors.accentDark),
          child: const Text('BLOCK'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<ModerationRepository>().block(userId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name is blocked.')));
    return true;
  } on ModerationException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}
