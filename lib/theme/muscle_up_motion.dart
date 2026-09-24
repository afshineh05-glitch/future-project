import 'package:flutter/material.dart';

/// MuscleUp Motion System V1 foundations.
abstract final class MuscleUpMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasis = Duration(milliseconds: 320);
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve enter = Cubic(0.16, 1, 0.3, 1);
  static const Curve exit = Cubic(0.7, 0, 0.84, 0);
  static const Curve standardCurve = Cubic(0.2, 0, 0, 1);

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(BuildContext context, Duration value) =>
      reduceMotion(context) ? Duration.zero : value;
}

/// The app-wide fade-through transition for Material routes.
class MuscleUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const MuscleUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MuscleUpMotion.reduceMotion(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: MuscleUpMotion.enter,
      reverseCurve: MuscleUpMotion.exit,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// A subtle, optionally staggered screen-content entrance.
class MuscleUpEntrance extends StatefulWidget {
  const MuscleUpEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 12),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<MuscleUpEntrance> createState() => _MuscleUpEntranceState();
}

class _MuscleUpEntranceState extends State<MuscleUpEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MuscleUpMotion.emphasis,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: MuscleUpMotion.enter,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (MuscleUpMotion.reduceMotion(context)) {
        _controller.value = 1;
        return;
      }
      if (widget.delay > Duration.zero) {
        await Future<void>.delayed(widget.delay);
      }
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MuscleUpMotion.reduceMotion(context)) return widget.child;
    return FadeTransition(
      opacity: _animation,
      child: AnimatedBuilder(
        animation: _animation,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset.lerp(widget.offset, Offset.zero, _animation.value)!,
          child: child,
        ),
      ),
    );
  }
}

/// Consistent tactile scale feedback for tappable surfaces.
class MuscleUpPressable extends StatefulWidget {
  const MuscleUpPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.985,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<MuscleUpPressable> createState() => _MuscleUpPressableState();
}

class _MuscleUpPressableState extends State<MuscleUpPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MuscleUpMotion.reduceMotion(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: reduced || !_pressed ? 1 : widget.pressedScale,
        duration: MuscleUpMotion.duration(context, MuscleUpMotion.fast),
        curve: MuscleUpMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}
