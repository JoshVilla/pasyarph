import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/loop_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../create/widgets/create_loop_sheet.dart' show showClubPicker;
import '../providers/text_post_composer.dart';
import '../widgets/post_widgets.dart';
import 'post_loop_screen.dart' show PhotoPicker, pickWithImagePicker;

/// A post without a ride, like a Facebook status: words, up to 10 photos,
/// and who sees it. Pops the visibility it was posted with.
class WritePostScreen extends StatefulWidget {
  const WritePostScreen({super.key, this.pick = pickWithImagePicker});

  final PhotoPicker pick;

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  late final TextPostComposer _composer = TextPostComposer(
    posts: context.read<PostRepository>(),
  );
  final _text = TextEditingController();
  List<Club>? _clubs;

  static const _labels = {
    LoopVisibility.public: 'Public',
    LoopVisibility.club: 'Group',
    LoopVisibility.private: 'Private',
  };

  @override
  void initState() {
    super.initState();
    _text.addListener(() => _composer.setText(_text.text));
    context.read<LoopRepository>().myClubs().then(
      (c) => mounted ? setState(() => _clubs = c) : null,
      onError: (Object _) => mounted ? setState(() => _clubs = []) : null,
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    _text.dispose();
    super.dispose();
  }

  Club? get _club => _clubs?.where((c) => c.id == _composer.clubId).firstOrNull;

  void _close() => context.canPop() ? context.pop() : context.go(Routes.feed);

  Future<void> _add() async {
    final camera = await askPhotoSource(context);
    if (camera == null || !mounted) return;
    final picked = await widget.pick(camera: camera, max: _composer.remaining);
    if (picked.isNotEmpty) await _composer.addPhotos(picked);
  }

  Future<void> _photoTapped(int index) async {
    if (await confirmRemovePhoto(context)) _composer.removePhoto(index);
  }

  Future<void> _pickClub() async {
    final clubs = _clubs;
    if (clubs == null || clubs.isEmpty) return;
    final id = await showClubPicker(
      context,
      clubs: clubs,
      selected: _composer.clubId,
    );
    if (id != null && mounted) {
      _composer.setVisibility(LoopVisibility.club, clubId: id);
    }
  }

  void _setVisibility(LoopVisibility v) {
    _composer.setVisibility(v);
    if (v == LoopVisibility.club && _club == null) _pickClub();
  }

  Future<void> _post() async {
    FocusScope.of(context).unfocus();
    final visibility = _composer.visibility;
    if (await _composer.post() && mounted) {
      if (context.canPop()) {
        context.pop(visibility);
      } else {
        context.go(Routes.feed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    return Scaffold(
      backgroundColor: PasyarColors.of(context).background,
      body: ListenableBuilder(
        listenable: _composer,
        builder: (context, _) => _form(context, moving),
      ),
    );
  }

  Widget _form(BuildContext context, bool moving) {
    final c = _composer;
    final clubs = _clubs;
    final pad = MediaQuery.paddingOf(context);
    final muted = PasyarTextStyles.of(context).body.copyWith(
      fontSize: 14,
      height: 1.2,
      color: PasyarColors.of(context).muted,
    );
    final heading = PasyarTextStyles.of(
      context,
    ).bodyStrong.copyWith(height: 1.2);
    final problem =
        c.error ?? (moving ? 'Stop riding to write and post.' : null);

    // Fills the screen (POST at the bottom) and scrolls when it can't.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              PasyarSpacing.sheet,
              pad.top + PasyarSpacing.floatingTop,
              PasyarSpacing.sheet,
              math.max(36, pad.bottom + 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    RoundIconButton.ground(
                      icon: LucideIcons.x,
                      iconSize: 20,
                      semanticLabel: 'Close',
                      onPressed: c.posting ? null : _close,
                    ),
                    // Shrinks rather than overflows with large text.
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'WRITE A POST',
                            style: PasyarTextStyles.of(context).screenTitle(32),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _TextField(controller: _text, enabled: !c.posting && !moving),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Photos (optional)', style: heading),
                        Text(
                          '${c.photos.length} / ${TextPostComposer.maxPhotos}',
                          style: muted,
                        ),
                      ],
                    ),
                    PhotoGrid(
                      photos: [for (final p in c.photos) p.path],
                      adding: c.adding,
                      onAdd: c.posting ? null : _add,
                      onPhotoTap: c.posting ? (_) {} : _photoTapped,
                    ),
                    for (final line in c.refused)
                      Text(
                        line,
                        style: muted.copyWith(
                          color: PasyarColors.of(context).accentDark,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Text('Who sees this', style: heading),
                    SegmentedChoice<LoopVisibility>(
                      semanticLabel: 'Who sees this post',
                      options: _labels,
                      selected: c.visibility,
                      onChanged: c.posting ? (_) {} : _setVisibility,
                    ),
                    if (c.visibility == LoopVisibility.club)
                      clubs != null && clubs.isEmpty
                          ? Text(
                              'Join or make a club first (Me → Clubs).',
                              style: PasyarTextStyles.of(context).label,
                            )
                          : SecondaryButton(
                              label: _club?.name.toUpperCase() ?? 'PICK A CLUB',
                              icon: LucideIcons.users,
                              onPressed: clubs == null || c.posting
                                  ? null
                                  : _pickClub,
                            ),
                    Text(switch (c.visibility) {
                      LoopVisibility.public =>
                        'Anyone on Pasyar can see it, under Global.',
                      LoopVisibility.club =>
                        'Only members of ${_club?.name ?? 'the club'} will '
                            'see it.',
                      LoopVisibility.private =>
                        'Only you can see it, on your profile.',
                    }, style: PasyarTextStyles.of(context).label),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    if (problem != null)
                      Text(
                        problem,
                        textAlign: TextAlign.center,
                        style: muted.copyWith(
                          color: PasyarColors.of(context).accentDark,
                        ),
                      ),
                    PrimaryButton(
                      label: c.posting && c.photos.isNotEmpty
                          ? 'POSTING ${c.uploaded} / ${c.photos.length}'
                          : 'POST',
                      loading: c.posting && c.photos.isEmpty,
                      onPressed: c.canPost && !moving ? _post : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The words: 140 px, multi-line, focused when the screen opens.
class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return SizedBox(
      height: 140,
      child: TextField(
        controller: controller,
        readOnly: !enabled,
        autofocus: enabled,
        expands: true,
        maxLines: null,
        maxLength: TextPostComposer.maxLength,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: PasyarTextStyles.of(context).bodyLarge,
        decoration: InputDecoration(
          hintText: 'Ask about a road, plan a ride, share an update…',
          hintStyle: PasyarTextStyles.of(
            context,
          ).bodyLarge.copyWith(color: PasyarColors.of(context).muted),
          counterText: '',
          filled: true,
          fillColor: PasyarColors.of(context).card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: border(PasyarColors.of(context).line),
          enabledBorder: border(PasyarColors.of(context).line),
          focusedBorder: border(PasyarColors.of(context).ink),
        ),
      ),
    );
  }
}
