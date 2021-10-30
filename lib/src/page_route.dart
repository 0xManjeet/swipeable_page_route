import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:black_hole_flutter/black_hole_flutter.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A specialized [CupertinoPageRoute] that allows for swiping back anywhere on
/// the page unless `canOnlySwipeFromEdge` is `true`.
class SwipeablePageRoute<T> extends CupertinoPageRoute<T> {
  SwipeablePageRoute({
    this.canSwipe = true,
    this.canOnlySwipeFromEdge = false,
    this.backGestureDetectionWidth = kMinInteractiveDimension,
    this.backGestureDetectionStartOffset = 0.0,
    required WidgetBuilder builder,
    String? title,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    Duration? transitionDuration,
    SwipeableTransitionBuilder? transitionBuilder,
  })  : _transitionDuration = transitionDuration,
        transitionBuilder =
            transitionBuilder ?? _defaultTransitionBuilder(fullscreenDialog),
        super(
          builder: builder,
          title: title,
          settings: settings,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog,
        );

  /// Whether the user can swipe to navigate back.
  ///
  /// Set this to `false` to disable swiping completely.
  bool canSwipe;

  /// An optional override for the [transitionDuration].
  final Duration? _transitionDuration;

  @override
  Duration get transitionDuration =>
      _transitionDuration ?? super.transitionDuration;

  /// Whether only back gestures close to the left (LTR) or right (RTL) screen
  /// edge are counted.
  ///
  /// This only takes effect if [canSwipe] ist set to `true`.
  ///
  /// If set to `true`, this distance can be controlled via
  /// [backGestureDetectionWidth].
  /// If set to `false`, the user can start dragging anywhere on the screen.
  final bool canOnlySwipeFromEdge;

  /// If [canOnlySwipeFromEdge] is set to `true`, this value controls the width
  /// of the gesture detection area.
  ///
  /// For comparison, in [CupertinoPageRoute] this value is `20`.
  final double backGestureDetectionWidth;

  /// If [canOnlySwipeFromEdge] is set to `true`, this value controls how far
  /// away from the left (LTR) or right (RTL) screen edge a gesture must start
  /// to be recognized for back navigation.
  final double backGestureDetectionStartOffset;

  /// Custom builder to wrap the child widget.
  ///
  /// By default, this wraps the child in a [CupertinoPageTransition], or, if
  /// it's a full-screen dialog, in a [CupertinoFullscreenDialogTransition].
  ///
  /// You can override this to, e.g., customize the position or shadow
  /// animations.
  final SwipeableTransitionBuilder transitionBuilder;

  static SwipeableTransitionBuilder _defaultTransitionBuilder(
    bool fullscreenDialog,
  ) {
    if (fullscreenDialog) {
      return (context, animation, secondaryAnimation, isSwipeGesture, child) {
        return CupertinoFullscreenDialogTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: isSwipeGesture,
          child: child,
        );
      };
    } else {
      return (context, animation, secondaryAnimation, isSwipeGesture, child) {
        return CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: isSwipeGesture,
          child: child,
        );
      };
    }
  }

  @override
  bool get popGestureEnabled => canSwipe && super.popGestureEnabled;

  // Called by `_FancyBackGestureDetector` when a pop ("back") drag start
  // gesture is detected. The returned controller handles all of the subsequent
  // drag events.
  _CupertinoBackGestureController<T> _startPopGesture() {
    assert(popGestureEnabled);

    return _CupertinoBackGestureController<T>(
      navigator: navigator!,
      controller: controller!, // protected access
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Check if the route has an animation that's currently participating in a
    // back swipe gesture.
    //
    // During a back gesture drag, let the transition be linear to match finger
    // motions.
    final Widget wrappedChild;
    if (fullscreenDialog) {
      wrappedChild = child;
    } else {
      wrappedChild = _FancyBackGestureDetector<T>(
        enabledCallback: () => popGestureEnabled,
        onStartPopGesture: _startPopGesture,
        canOnlySwipeFromEdge: canOnlySwipeFromEdge,
        backGestureDetectionWidth: backGestureDetectionWidth,
        backGestureDetectionStartOffset: backGestureDetectionStartOffset,
        child: child,
      );
    }
    return transitionBuilder(
      context,
      animation,
      secondaryAnimation,
      /* isSwipeGesture: */ popGestureInProgress,
      wrappedChild,
    );
  }
}

typedef SwipeableTransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  bool isSwipeGesture,
  Widget child,
);

extension BuildContextSwipeablePageRoute on BuildContext {
  SwipeablePageRoute<T>? getSwipeablePageRoute<T>() {
    final route = getModalRoute<T>();
    return route is SwipeablePageRoute<T> ? route : null;
  }
}

// Mostly copies and modified variations of the private widgets related to
// [CupertinoPageRoute].

const double _kMinFlingVelocity = 1; // Screen widths per second.

// An eyeballed value for the maximum time it takes for a page to animate
// forward if the user releases a page mid swipe.
const int _kMaxDroppedSwipePageForwardAnimationTime = 800; // Milliseconds.

// The maximum time for a page to get reset to it's original position if the
// user releases a page mid swipe.
const int _kMaxPageBackAnimationTime = 300; // Milliseconds.

// An adapted version of `_CupertinoBackGestureDetector`.
class _FancyBackGestureDetector<T> extends StatefulWidget {
  const _FancyBackGestureDetector({
    Key? key,
    required this.canOnlySwipeFromEdge,
    required this.backGestureDetectionWidth,
    required this.backGestureDetectionStartOffset,
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  }) : super(key: key);

  final bool canOnlySwipeFromEdge;
  final double backGestureDetectionWidth;
  final double backGestureDetectionStartOffset;

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_CupertinoBackGestureController<T>> onStartPopGesture;

  @override
  _FancyBackGestureDetectorState<T> createState() =>
      _FancyBackGestureDetectorState<T>();
}

class _FancyBackGestureDetectorState<T>
    extends State<_FancyBackGestureDetector<T>> {
  _CupertinoBackGestureController<T>? _backGestureController;

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    assert(_backGestureController == null);
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController!.dragUpdate(
      _convertToLogical(details.primaryDelta! / context.size!.width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController!.dragEnd(_convertToLogical(
      details.velocity.pixelsPerSecond.dx / context.size!.width,
    ));
    _backGestureController = null;
  }

  void _handleDragCancel() {
    assert(mounted);
    // This can be called even if start is not called, paired with the "down"
    // event that we don't consider here.
    _backGestureController?.dragEnd(0);
    _backGestureController = null;
  }

  double _convertToLogical(double value) {
    switch (context.directionality) {
      case TextDirection.rtl:
        return -value;
      case TextDirection.ltr:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));

    final gestureDetector = RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _DirectionDependentDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _DirectionDependentDragGestureRecognizer>(
          () {
            final directionality = context.directionality;
            return _DirectionDependentDragGestureRecognizer(
              debugOwner: this,
              canDragToLeft: directionality == TextDirection.rtl,
              canDragToRight: directionality == TextDirection.ltr,
              checkStartedCallback: () => _backGestureController != null,
              enabledCallback: widget.enabledCallback,
            );
          },
          (instance) => instance
            ..onStart = _handleDragStart
            ..onUpdate = _handleDragUpdate
            ..onEnd = _handleDragEnd
            ..onCancel = _handleDragCancel,
        )
      },
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (widget.canOnlySwipeFromEdge)
          PositionedDirectional(
            start: widget.backGestureDetectionStartOffset,
            width: _dragAreaWidth(context),
            top: 0,
            bottom: 0,
            child: gestureDetector,
          )
        else
          Positioned.fill(child: gestureDetector),
      ],
    );
  }

  double _dragAreaWidth(BuildContext context) {
    // For devices with notches, the drag area needs to be larger on the side
    // that has the notch.
    final dragAreaWidth = context.directionality == TextDirection.ltr
        ? context.mediaQuery.padding.left
        : context.mediaQuery.padding.right;
    return math.max(dragAreaWidth, widget.backGestureDetectionWidth);
  }
}

// Copied from `flutter/cupertino`.
class _CupertinoBackGestureController<T> {
  _CupertinoBackGestureController({
    required this.navigator,
    required this.controller,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;

  /// The drag gesture has changed by [delta]. The total range of the
  /// drag should be 0.0 to 1.0.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// The drag gesture has ended with a horizontal motion of [velocity] as a
  /// fraction of screen width per second.
  void dragEnd(double velocity) {
    // Fling in the appropriate direction.
    // AnimationController.fling is guaranteed to
    // take at least one frame.
    //
    // This curve has been determined through rigorously eyeballing native iOS
    // animations.
    const Curve animationCurve = Curves.fastLinearToSlowEaseIn;
    final bool animateForward;

    // If the user releases the page before mid screen with sufficient velocity,
    // or after mid screen, we should animate the page out. Otherwise, the page
    // should be animated back in.
    if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      // The closer the panel is to dismissing, the shorter the animation is.
      // We want to cap the animation time, but we want to use a linear curve
      // to determine it.
      final droppedPageForwardAnimationTime = math.min(
        lerpDouble(
          _kMaxDroppedSwipePageForwardAnimationTime,
          0,
          controller.value,
        )!
            .floor(),
        _kMaxPageBackAnimationTime,
      );
      controller.animateTo(
        1,
        duration: Duration(milliseconds: droppedPageForwardAnimationTime),
        curve: animationCurve,
      );
    } else {
      // This route is destined to pop at this point. Reuse navigator's pop.
      navigator.pop();

      // The popping may have finished inline if already at the target
      // destination.
      if (controller.isAnimating) {
        // Otherwise, use a custom popping animation duration and curve.
        final droppedPageBackAnimationTime = lerpDouble(
          0,
          _kMaxDroppedSwipePageForwardAnimationTime,
          controller.value,
        )!
            .floor();
        controller.animateBack(
          0,
          duration: Duration(milliseconds: droppedPageBackAnimationTime),
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      // Keep the userGestureInProgress in true state so we don't change the
      // curve of the page transition mid-flight since CupertinoPageTransition
      // depends on userGestureInProgress.
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

class _DirectionDependentDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  _DirectionDependentDragGestureRecognizer({
    required this.canDragToLeft,
    required this.canDragToRight,
    required this.enabledCallback,
    required this.checkStartedCallback,
    Object? debugOwner,
  }) : super(debugOwner: debugOwner);

  final bool canDragToLeft;
  final bool canDragToRight;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<bool> checkStartedCallback;

  @override
  void handleEvent(PointerEvent event) {
    final delta = event.delta.dx;
    if (checkStartedCallback() ||
        enabledCallback() &&
            (canDragToLeft && delta < 0 ||
                canDragToRight && delta > 0 ||
                delta == 0)) {
      super.handleEvent(event);
    } else {
      stopTrackingPointer(event.pointer);
    }
  }
}
