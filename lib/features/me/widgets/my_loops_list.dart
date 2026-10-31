import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/links.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/share.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/loop.dart';
import '../../../data/repositories/loop_repository.dart';
import '../../create/widgets/create_loop_sheet.dart' show showClubPicker;
import '../../ride/ride_this_loop.dart';
import 'loop_row.dart';

enum _LoopAction { edit, share, delete }

/// "My loops" on the Me tab: loops the rider made, with who can see each
/// one. Tap to ride it; ⋯ to rename it, change who sees it, share or
/// delete it. Reloads after every save.
class MyLoopsList extends StatefulWidget {
  const MyLoopsList({super.key});

  @override
  State<MyLoopsList> createState() => _MyLoopsListState();
}

class _MyLoopsListState extends State<MyLoopsList> {
  late final LoopRepository _loops = context.read<LoopRepository>();
  List<Loop>? _mine;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loops.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _loops.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final mine = await _loops.mine();
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _error = null;
      });
    } on LoopException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _more(Loop loop) async {
    final action = await showActionSheet<_LoopAction>(
      context,
      title: loop.name,
      actions: [
        const SheetAction(
          value: _LoopAction.edit,
          label: 'Edit name and who sees it',
          icon: LucideIcons.pencil,
        ),
        SheetAction(
          value: _LoopAction.share,
          label: 'Share link',
          icon: LucideIcons.share2,
          // Private loops have no link to share.
          enabled: loop.visibility != LoopVisibility.private,
        ),
        const SheetAction(
          value: _LoopAction.delete,
          label: 'Delete loop',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _LoopAction.edit:
        await _edit(loop);
      case _LoopAction.share:
        await context.read<Sharer>().share(
          shareMessage(
            loopName: loop.name,
            distanceM: loop.distanceM,
            link: AppLinks.loop(loop.id),
          ),
          subject: loop.name,
        );
      case _LoopAction.delete:
        await _delete(loop);
    }
  }

  Future<void> _edit(Loop loop) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditLoopSheet(loop: loop, loops: _loops),
    );
    if (saved == true && mounted) _snack('Loop updated.');
  }

  Future<void> _delete(Loop loop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this loop?'),
        content: Text(
          '"${loop.name}" and any rides you posted with it will be deleted. '
          'Riders who saved it lose it too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: PasyarColors.of(context).accentDark,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _loops.delete(loop.id);
      if (mounted) _snack('Loop deleted.');
    } on LoopException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final empty = PasyarTextStyles.of(
      context,
    ).body.copyWith(color: PasyarColors.of(context).muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (mine == null && _error != null)
          Text(_error!, style: empty)
        else if (mine != null && mine.isEmpty)
          Text('Loops you make in Create show up here.', style: empty),
        for (final loop in mine ?? const <Loop>[])
          LoopRow(
            loop: loop,
            detail: loop.source == LoopSource.custom
                ? 'Made by you'
                : 'Generated',
            onTap: () =>
                rideThisLoop(context, loopId: loop.id, name: loop.name),
            onMore: () => _more(loop),
          ),
      ],
    );
  }
}

/// Rename a loop and change who sees it. Pops true when saved.
class EditLoopSheet extends StatefulWidget {
  const EditLoopSheet({super.key, required this.loop, required this.loops});

  final Loop loop;
  final LoopRepository loops;

  @override
  State<EditLoopSheet> createState() => _EditLoopSheetState();
}

class _EditLoopSheetState extends State<EditLoopSheet> {
  late final _name = TextEditingController(text: widget.loop.name);
  late LoopVisibility _visibility = widget.loop.visibility;
  late String? _clubId = widget.loop.clubId;
  List<Club>? _clubs;
  bool _saving = false;
  String? _error;

  static const _labels = {
    LoopVisibility.public: 'Public',
    LoopVisibility.club: 'Group',
    LoopVisibility.private: 'Private',
  };

  @override
  void initState() {
    super.initState();
    widget.loops.myClubs().then(
      (c) => mounted ? setState(() => _clubs = c) : null,
      onError: (Object _) => mounted ? setState(() => _clubs = []) : null,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  Club? get _club => _clubs?.where((c) => c.id == _clubId).firstOrNull;

  String? get _nameError => _trimmed.isEmpty
      ? 'Give your loop a name.'
      : _trimmed.length > 80
      ? 'At most 80 characters.'
      : null;

  bool get _clubMissing => _visibility == LoopVisibility.club && _club == null;

  Future<void> _pickClub() async {
    final clubs = _clubs;
    if (clubs == null || clubs.isEmpty) return;
    final id = await showClubPicker(context, clubs: clubs, selected: _clubId);
    if (id != null && mounted) setState(() => _clubId = id);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.loops.editSharing(
        widget.loop.id,
        name: _trimmed,
        visibility: _visibility,
        clubId: _clubId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on LoopException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    final clubs = _clubs;
    final canSave = _nameError == null && !_clubMissing && !_saving && !moving;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: BottomSheetPanel(
        children: [
          Text(
            'EDIT LOOP',
            style: PasyarTextStyles.of(context).screenTitle(24),
          ),
          PasyarTextField(
            label: 'Name',
            controller: _name,
            enabled: !moving,
            maxLength: 80,
            error: _name.text.isEmpty ? null : _nameError,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          SegmentedChoice<LoopVisibility>(
            semanticLabel: 'Who sees this loop',
            options: _labels,
            selected: _visibility,
            onChanged: (v) {
              setState(() => _visibility = v);
              if (v == LoopVisibility.club && _club == null) _pickClub();
            },
          ),
          if (_visibility == LoopVisibility.club)
            clubs != null && clubs.isEmpty
                ? Text(
                    'Join or make a club first (Me → Clubs).',
                    style: PasyarTextStyles.of(context).label,
                  )
                : SecondaryButton(
                    label: _club?.name.toUpperCase() ?? 'PICK A CLUB',
                    icon: LucideIcons.users,
                    onPressed: clubs == null ? null : _pickClub,
                  ),
          Text(switch (_visibility) {
            LoopVisibility.public =>
              'Anyone on Pasyar can see and ride this loop.',
            LoopVisibility.club =>
              'Only members of ${_club?.name ?? 'the club'} will see this loop.',
            LoopVisibility.private => 'Only you can see this loop.',
          }, style: PasyarTextStyles.of(context).label),
          if (_error != null || moving)
            Text(
              _error ?? 'Stop riding to edit your loop.',
              style: PasyarTextStyles.of(context).bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: PasyarColors.of(context).accentDark,
              ),
            ),
          PrimaryButton(
            label: 'SAVE',
            loading: _saving,
            onPressed: canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}
