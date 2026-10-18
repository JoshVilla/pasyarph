import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/ride_history_repository.dart';
import '../../ride/loop_stats.dart';
import '../post_draft.dart';
import '../providers/post_composer.dart';
import '../widgets/post_widgets.dart';

/// Picks photos for the post: gallery (several) or camera. Injectable for
/// tests.
typedef PhotoPicker =
    Future<List<PickedPhoto>> Function({
      required bool camera,
      required int max,
    });

Future<List<PickedPhoto>> pickWithImagePicker({
  required bool camera,
  required int max,
}) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (camera) {
    final f = await picker.pickImage(source: ImageSource.camera);
    files = [?f];
  } else if (max == 1) {
    final f = await picker.pickImage(source: ImageSource.gallery);
    files = [?f];
  } else {
    files = await picker.pickMultiImage(limit: max);
  }
  return [for (final f in files) PickedPhoto(await f.readAsBytes())];
}

/// Post a finished ride (mockup 4, adapted for posting after the ride): up
/// to 10 photos taken during it, a caption, and the loop attached.
class PostLoopScreen extends StatefulWidget {
  const PostLoopScreen({
    super.key,
    required this.rideId,
    this.pick = pickWithImagePicker,
  });

  final String rideId;
  final PhotoPicker pick;

  @override
  State<PostLoopScreen> createState() => _PostLoopScreenState();
}

class _PostLoopScreenState extends State<PostLoopScreen> {
  late final PostComposer _composer;
  final _caption = TextEditingController();

  @override
  void initState() {
    super.initState();
    _composer = PostComposer(
      rideId: widget.rideId,
      history: context.read<RideHistoryRepository>(),
      posts: context.read<PostRepository>(),
      drafts: context.read<PostDraftStore>(),
    );
    _composer.load().then((_) {
      if (mounted) _caption.text = _composer.caption;
    });
    _caption.addListener(() => _composer.setCaption(_caption.text));
  }

  @override
  void dispose() {
    _composer.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.ride);
    }
  }

  Future<void> _add() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetPanel(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          math.max(20, MediaQuery.viewPaddingOf(context).bottom + 20),
        ),
        children: [
          Text('ADD PHOTOS', style: PasyarTextStyles.screenTitle(30)),
          PrimaryButton(
            label: 'CHOOSE PHOTOS',
            icon: LucideIcons.images,
            onPressed: () => Navigator.pop(context, false),
          ),
          SecondaryButton(
            label: 'TAKE A PHOTO',
            icon: LucideIcons.camera,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (camera == null || !mounted) return;
    final picked = await widget.pick(camera: camera, max: _composer.remaining);
    if (picked.isNotEmpty) await _composer.addPhotos(picked);
  }

  Future<void> _photoTapped(int index) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetPanel(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          math.max(20, MediaQuery.viewPaddingOf(context).bottom + 20),
        ),
        children: [
          Text('REMOVE THIS PHOTO?', style: PasyarTextStyles.screenTitle(30)),
          PrimaryButton(
            label: 'REMOVE',
            onPressed: () => Navigator.pop(context, true),
          ),
          SecondaryButton(
            label: 'KEEP',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (remove == true) await _composer.removePhoto(index);
  }

  Future<void> _post() async {
    FocusScope.of(context).unfocus();
    if (await _composer.post() && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Posted to the feed.')));
      context.go(Routes.feed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    return ListenableBuilder(
      listenable: _composer,
      builder: (context, _) {
        final c = _composer;
        final ride = c.ride;
        return Scaffold(
          backgroundColor: PasyarColors.card,
          body: switch (c.phase) {
            ComposerPhase.loading => const SizedBox.expand(),
            ComposerPhase.missing ||
            ComposerPhase.posted when ride == null => _Message(
              text: "We couldn't find this ride on your phone.",
              onClose: _close,
            ),
            ComposerPhase.posted => _Message(
              text: 'This ride is already posted.',
              onClose: _close,
            ),
            _ => _Form(
              composer: c,
              ride: ride!,
              caption: _caption,
              moving: moving,
              onClose: _close,
              onAdd: _add,
              onPhotoTap: _photoTapped,
              onPost: _post,
            ),
          },
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.composer,
    required this.ride,
    required this.caption,
    required this.moving,
    required this.onClose,
    required this.onAdd,
    required this.onPhotoTap,
    required this.onPost,
  });

  final PostComposer composer;
  final RideSummary ride;
  final TextEditingController caption;
  final bool moving;
  final VoidCallback onClose;
  final VoidCallback onAdd;
  final ValueChanged<int> onPhotoTap;
  final VoidCallback onPost;

  /// "Bangaan View · Viewpoint · 118 km loop", or "118 km loop · 3 h 50"
  /// when the stop wasn't reached.
  String get _subtitle {
    final loopKm = '${formatDistance(ride.loopM)} loop';
    final stop = composer.stop;
    if (!ride.reachedStop || stop == null) {
      return '$loopKm · ${formatRideTime(ride.duration.inSeconds)}';
    }
    return [?stop.name, ?stop.typeLabel, loopKm].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = composer;
    final posting = c.phase == ComposerPhase.posting;
    final blocked = c.blockedReason;
    final problem =
        blocked ??
        c.error ??
        (moving ? 'Stop riding to write a caption and post.' : null);
    final pad = MediaQuery.paddingOf(context);
    // Browser-normal line height, as in the mockup's labels.
    final muted = PasyarTextStyles.body.copyWith(
      fontSize: 14,
      height: 1.2,
      color: PasyarColors.muted,
    );
    final heading = PasyarTextStyles.bodyStrong.copyWith(height: 1.2);

    // Fills the screen (buttons at the bottom) and scrolls when it can't.
    // The padding is inside: SliverFillRemaining ignores a SliverPadding's.
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RoundIconButton.ground(
                      icon: LucideIcons.x,
                      iconSize: 20,
                      semanticLabel: 'Close',
                      onPressed: posting ? null : onClose,
                    ),
                    const RodeBadge(),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      'YOU MADE IT',
                      style: PasyarTextStyles.screenTitle(
                        36,
                      ).copyWith(letterSpacing: 0.5),
                    ),
                    Text(
                      _subtitle,
                      style: PasyarTextStyles.body.copyWith(
                        fontSize: 16,
                        height: 1.2,
                        color: PasyarColors.muted,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Photos', style: heading),
                        Text(
                          '${c.photos.length} / ${PostComposer.maxPhotos}',
                          style: muted,
                        ),
                      ],
                    ),
                    PhotoGrid(
                      photos: [for (final p in c.photos) p.path],
                      adding: c.adding,
                      onAdd: posting || blocked != null ? null : onAdd,
                      onPhotoTap: posting ? (_) {} : onPhotoTap,
                    ),
                    for (final line in c.refused)
                      Text(
                        line,
                        style: muted.copyWith(color: PasyarColors.accentDark),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Text('Caption', style: heading),
                    _CaptionField(
                      controller: caption,
                      enabled: !posting && !moving,
                    ),
                  ],
                ),
                RouteAttachedCard(
                  route: ride.preview,
                  detail:
                      '${formatDistance(ride.loopM)} loop · '
                      '${formatRideTime(ride.loopDurationS)} ride time',
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
                        style: muted.copyWith(color: PasyarColors.accentDark),
                      ),
                    PrimaryButton(
                      label: posting
                          ? 'POSTING ${c.uploaded} / ${c.photos.length}'
                          : 'POST TO FEED',
                      onPressed: c.canPost && !moving ? onPost : null,
                    ),
                    // Laid out 34 px tall like the mockup's link; the 44 px
                    // touch target overflows it.
                    SizedBox(
                      height: 34,
                      child: OverflowBox(
                        maxHeight: PasyarSpacing.minTouch,
                        child: Center(
                          child: _LinkButton(
                            label: 'Post later',
                            onPressed: posting ? null : onClose,
                          ),
                        ),
                      ),
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

/// 88 px multi-line caption box (mockup 4).
class _CaptionField extends StatelessWidget {
  const _CaptionField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return SizedBox(
      height: 88,
      child: TextField(
        controller: controller,
        readOnly: !enabled,
        expands: true,
        maxLines: null,
        maxLength: 2000,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: PasyarTextStyles.body,
        decoration: InputDecoration(
          hintText: 'How was the ride?',
          hintStyle: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          counterText: '',
          filled: true,
          fillColor: PasyarColors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: border(PasyarColors.line),
          enabledBorder: border(PasyarColors.line),
          focusedBorder: border(PasyarColors.ink),
        ),
      ),
    );
  }
}

/// Underlined 15 / 600 text button, 44 px tall.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, PasyarSpacing.minTouch),
        padding: const EdgeInsets.all(8),
        foregroundColor: PasyarColors.ink,
        textStyle: PasyarTextStyles.bodyStrong.copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(label),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PasyarSpacing.sheet),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PasyarSpacing.groupGap,
        children: [
          Text(text, textAlign: TextAlign.center, style: PasyarTextStyles.body),
          SecondaryButton(label: 'CLOSE', onPressed: onClose),
        ],
      ),
    );
  }
}
