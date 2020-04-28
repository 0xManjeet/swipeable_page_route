import 'dart:ui';

import 'package:black_hole_flutter/black_hole_flutter.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_bar.dart';
import 'state.dart';

class AnimatedTitle extends MultiChildRenderObjectWidget {
  AnimatedTitle(MorphingState state)
      : assert(state != null),
        t = state.t,
        super(
          children: [
            _createChild(state.parent),
            _createChild(state.child),
          ],
        );

  final double t;

  static Widget _createChild(EndState state) {
    final title = state.appBar.title;
    if (title == null) {
      return SizedBox();
    }

    var style = state.appBar.textTheme?.title ??
        state.appBarTheme.textTheme?.title ??
        state.theme.primaryTextTheme.title;
    if (style?.color != null) {
      style = style.copyWith(color: style.color.withOpacity(state.opacity));
    }

    return _AnimatedTitleParentDataWidget(
      hasLeading: state.leading != null,
      child: DefaultTextStyle(style: style, child: title),
    );
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _AnimatedTitleLayout(t: t);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _AnimatedTitleLayout renderObject,
  ) {
    renderObject.t = t;
  }
}

class _AnimatedTitleParentDataWidget extends ParentDataWidget<AnimatedTitle> {
  const _AnimatedTitleParentDataWidget({
    Key key,
    @required this.hasLeading,
    @required Widget child,
  })  : assert(hasLeading != null),
        super(key: key, child: child);

  final bool hasLeading;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is _AnimatedTitleParentData);
    final _AnimatedTitleParentData parentData = renderObject.parentData;

    if (parentData.hasLeading == hasLeading) {
      return;
    }
    parentData.hasLeading = hasLeading;
    final targetParent = renderObject.parent;
    if (targetParent is RenderObject) {
      targetParent.markNeedsLayout();
    }
  }
}

class _AnimatedTitleParentData extends ContainerBoxParentData<RenderBox> {
  bool hasLeading;
}

class _AnimatedTitleLayout
    extends AnimatedAppBarLayout<_AnimatedTitleParentData> {
  _AnimatedTitleLayout({double t = 0}) : super(t: t);

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _AnimatedTitleParentData) {
      child.parentData = _AnimatedTitleParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      children.map((c) => c.getMinIntrinsicWidth(height)).max();

  @override
  double computeMaxIntrinsicWidth(double height) =>
      children.map((c) => c.getMaxIntrinsicWidth(height)).max();

  @override
  double computeMinIntrinsicHeight(double width) =>
      children.map((c) => c.getMinIntrinsicHeight(width)).max();

  @override
  double computeMaxIntrinsicHeight(double width) =>
      children.map((c) => c.getMaxIntrinsicHeight(width)).max();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void performLayout() {
    assert(!sizedByParent);

    final parent = firstChild;
    final child = parent.data.nextSibling;

    parent.layout(constraints, parentUsesSize: true);
    child.layout(constraints, parentUsesSize: true);
    size = parent.size.coerceAtLeast(child.size);

    parent.data.offset = Offset(
      lerpDouble(0, -kToolbarHeight, t) +
          (parent.data.hasLeading ? 0 : -kToolbarHeight),
      (size.height - parent.size.height) / 2,
    );
    child.data.offset = Offset(
      lerpDouble(kToolbarHeight, 0, t) +
          (child.data.hasLeading ? 0 : -kToolbarHeight),
      (size.height - child.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final parent = firstChild;
    final child = parent.data.nextSibling;

    context
      ..pushOpacity(
        parent.data.offset + offset,
        (1 - 2 * t).coerceAtLeast(0).opacityToAlpha,
        (context, offset) => context.paintChild(parent, offset),
      )
      ..pushOpacity(
        child.data.offset + offset,
        (2 * t - 1).coerceAtLeast(0).coerceAtLeast(0).opacityToAlpha,
        (context, offset) => context.paintChild(child, offset),
      );
  }
}

extension _ParentData on RenderBox {
  _AnimatedTitleParentData get data => parentData as _AnimatedTitleParentData;
}
