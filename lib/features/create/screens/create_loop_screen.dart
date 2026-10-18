import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../ride/widgets/home_controls.dart';
import '../loop_builder.dart';
import '../providers/create_loop_controller.dart';
import '../widgets/create_loop_map.dart';
import '../widgets/create_loop_sheet.dart';

/// Create a loop (design/mockups/06-create-loop.html): tap points on the
/// map, routed S → 1 → … → S, then name, visibility, SAVE and SHARE LINK.
/// Expects a [CreateLoopController] above it.
class CreateLoopScreen extends StatefulWidget {
  const CreateLoopScreen({super.key});

  @override
  State<CreateLoopScreen> createState() => _CreateLoopScreenState();
}

class _CreateLoopScreenState extends State<CreateLoopScreen> {
  late final CreateLoopController _loop = context.read<CreateLoopController>();
  late final LocationProvider _location = context.read<LocationProvider>();
  late final _name = TextEditingController(text: _loop.name);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => _loop.setName(_name.text));
    _location.addListener(_onLocation);
    // Not during the first build: both can notify listeners right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _location.start();
      _onLocation();
    });
  }

  void _onLocation() {
    final here = _location.position;
    if (here != null) _loop.setStart(here);
  }

  @override
  void dispose() {
    _location.removeListener(_onLocation);
    _name.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final ok = await _loop.save();
    if (!mounted) return;
    _snack(ok ? 'Loop saved. Find it under Me.' : _loop.saveError!.message);
  }

  Future<void> _share() async {
    FocusScope.of(context).unfocus();
    final link = await _loop.shareLink();
    if (!mounted) return;
    if (link == null) {
      _snack(_loop.saveError?.message ?? 'Finish your loop first.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (mounted) _snack('Link copied. Paste it anywhere to share your loop.');
  }

  Future<void> _pickClub() async {
    final clubs = _loop.clubs;
    if (clubs == null) return;
    final id = await showClubPicker(
      context,
      clubs: clubs,
      selected: _loop.club?.id,
    );
    if (id != null) _loop.setClub(id);
  }

  Future<void> _back() async {
    final unsaved = _loop.dirty && _loop.points.isNotEmpty;
    if (unsaved && !await _confirmDiscard()) return;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.ride);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('Your points will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final loop = context.watch<CreateLoopController>();
    final location = context.watch<LocationProvider>();
    final moving = location.isMoving;
    final media = MediaQuery.of(context);
    final pad = media.padding;
    final keyboard = media.viewInsets.bottom;

    // The mockup's sheet, plus room for the phone's navigation bar. With the
    // keyboard up it slides up and shrinks to fit under the top controls.
    final bottomInset = math.max(0.0, pad.bottom - 20);
    final top = pad.top + PasyarSpacing.floatingTop;
    final sheetHeight = math.min(
      createSheetHeight + bottomInset,
      media.size.height - keyboard - top - 48 - PasyarSpacing.floatingTop,
    );
    final mapHeight = media.size.height - sheetHeight + PasyarRadius.sheet;

    final status = location.status;
    final locationOff =
        status != LocationStatus.on && status != LocationStatus.checking;
    final error = loop.routeError;

    return PopScope(
      canPop: !(loop.dirty && loop.points.isNotEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: PasyarColors.mapGround,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mapHeight,
              child: CreateLoopMap(
                start: loop.start,
                points: loop.points,
                mainStop: loop.mainStopIndex,
                shape: loop.shape,
                onAdd: loop.addPoint,
                onMainStop: loop.setMainStop,
                onRemove: loop.removePoint,
                onDrag: loop.dragPoint,
                onDragEnd: loop.endDrag,
                attributionBottom: PasyarRadius.sheet,
              ),
            ),
            Positioned(
              top: top,
              left: PasyarSpacing.screen,
              right: PasyarSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      RoundIconButton.floating(
                        icon: LucideIcons.chevronLeft,
                        semanticLabel: 'Back',
                        onPressed: _back,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _HintPill(
                            text: loop.start == null
                                ? 'Finding your location…'
                                : error != null
                                ? '${error.message} Tap to retry.'
                                : hintFor(loop.points.length),
                            onTap: error == null ? null : loop.retryRoute,
                          ),
                        ),
                      ),
                      if (loop.points.isNotEmpty)
                        RoundIconButton.floating(
                          icon: LucideIcons.undo2,
                          semanticLabel: 'Undo last point',
                          onPressed: loop.undo,
                        ),
                    ],
                  ),
                  if (locationOff)
                    LocationOffBanner(status: status, onPressed: location.fix),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              left: 0,
              right: 0,
              bottom: keyboard,
              height: sheetHeight,
              child: CreateLoopSheet(
                name: _name,
                pointCount: loop.points.length,
                totals: loop.totals,
                routing: loop.routing,
                routeFailed: error != null,
                visibility: loop.visibility,
                clubs: loop.clubs,
                club: loop.club,
                moving: moving,
                onVisibility: loop.setVisibility,
                onPickClub: _pickClub,
                saving: loop.saving,
                bottomInset: keyboard > 0 ? 0 : bottomInset,
                onSave: loop.canSave && loop.dirty && !moving ? _save : null,
                onShare: loop.canShareNow && !moving ? _share : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark hint over the map ("Tap the map to add a point"). Tappable when it
/// shows a routing error.
class _HintPill extends StatelessWidget {
  const _HintPill({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: PasyarColors.ink,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PasyarTextStyles.bodySmall.copyWith(
              color: PasyarColors.card,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
