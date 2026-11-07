import 'package:flutter/material.dart';

/// Shared timing; callbacks and state updates never wait for visual feedback.
abstract final class PasyarMotion {
  static const feedback = Duration(milliseconds: 150);
  static const change = Duration(milliseconds: 180);
  static const sheet = Duration(milliseconds: 220);

  static Duration duration(BuildContext context, Duration normal) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;

  /// Image.frameBuilder: reveal only decoded asynchronous images.
  static Widget imageFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool synchronous,
  ) {
    if (synchronous || MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: feedback,
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}

/// Reveals changed content without retaining stale actions or semantics.
/// Keeps the child's element/state and does not animate initial mounting.
class MotionChange extends StatefulWidget {
  const MotionChange({
    super.key,
    required this.value,
    required this.child,
    this.duration = PasyarMotion.change,
  });
  final Object? value;
  final Widget child;
  final Duration duration;
  @override
  State<MotionChange> createState() => _MotionChangeState();
}

class _MotionChangeState extends State<MotionChange>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  late final _opacity = _controller.drive(
    Tween<double>(
      begin: 0.65,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOutCubic)),
  );

  @override
  void didUpdateWidget(MotionChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.duration = PasyarMotion.duration(context, widget.duration);
      if (_controller.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        // Remain visible and responsive even with rapid repeated updates.
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    alwaysIncludeSemantics: true,
    child: widget.child,
  );
}

/// Animates local layout without keeping outgoing controls alive.
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.duration = PasyarMotion.change,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  @override
  Widget build(BuildContext context) => AnimatedSize(
    // A zero-duration RenderAnimatedSize can notify during its own layout.
    // One microsecond avoids that assertion and settles on the next frame.
    duration: MediaQuery.disableAnimationsOf(context)
        ? const Duration(microseconds: 1)
        : duration,
    curve: Curves.easeOutCubic,
    alignment: alignment,
    child: child,
  );
}
