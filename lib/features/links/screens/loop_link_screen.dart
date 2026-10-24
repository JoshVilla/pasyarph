import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../data/models/link_preview.dart';
import '../../../data/repositories/link_repository.dart';
import '../../ride/providers/loop_preview_provider.dart';
import '../link_messages.dart';
import '../widgets/link_scaffold.dart';

/// Opened from a loop link (https://pasyar.pages.dev/l/id): checks the rider
/// may see the loop, then builds Ride this loop from where they are and
/// replaces itself with the loop preview.
class LoopLinkScreen extends StatefulWidget {
  const LoopLinkScreen({
    super.key,
    required this.loopId,
    this.fixTimeout = const Duration(seconds: 15),
  });

  final String loopId;

  /// How long to wait for the first GPS fix.
  final Duration fixTimeout;

  @override
  State<LoopLinkScreen> createState() => _LoopLinkScreenState();
}

class _LoopLinkScreenState extends State<LoopLinkScreen> {
  late final LinkRepository _links = context.read<LinkRepository>();
  late final LocationProvider _location = context.read<LocationProvider>();
  late final LoopPreviewProvider _preview = context.read<LoopPreviewProvider>();

  LinkPreview? _link;
  String? _error;
  bool _needsLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _needsLocation = false;
    });
    try {
      final link = _link ?? await _links.preview(LinkKind.loop, widget.loopId);
      if (!mounted) return;
      setState(() => _link = link);
      if (link.status != LinkStatus.ok) return;

      final here = await _position();
      if (!mounted) return;
      if (here == null) {
        setState(() {
          _needsLocation = true;
          _error = 'Turn on location to ride this loop from where you are.';
        });
        return;
      }
      final ready = await _preview.rideLoop(
        loopId: link.loopId ?? widget.loopId,
        name: link.name ?? 'Loop',
        start: here,
      );
      if (!mounted) return;
      if (ready) {
        context.pushReplacement(Routes.loopPreview);
      } else {
        setState(() => _error = _preview.error?.message ?? 'Try again.');
      }
    } on LinkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// The rider's position, waiting a little for the first fix.
  Future<LatLng?> _position() async {
    await _location.start();
    if (_location.position != null || _location.status != LocationStatus.on) {
      return _location.position;
    }
    final fix = Completer<LatLng?>();
    void listener() {
      if (_location.position != null && !fix.isCompleted) {
        fix.complete(_location.position);
      }
    }

    _location.addListener(listener);
    try {
      return await fix.future.timeout(widget.fixTimeout, onTimeout: () => null);
    } finally {
      _location.removeListener(listener);
    }
  }

  Future<void> _fixLocation() async {
    await _location.fix();
    if (mounted) await _open();
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final blocked = link == null
        ? null
        : blockedLinkMessage(link, what: 'LOOP');
    if (blocked != null) return LinkScaffold.blocked(blocked);

    final title = link?.name?.toUpperCase() ?? 'OPENING LOOP';
    if (_error != null) {
      return LinkScaffold.error(
        title: title,
        error: _error!,
        onRetry: _needsLocation ? _fixLocation : _open,
        retryLabel: _needsLocation ? 'TURN ON LOCATION' : 'TRY AGAIN',
      );
    }
    return LinkScaffold.loading(
      title: title,
      text: link == null ? null : 'Finding your way to this loop…',
    );
  }
}
