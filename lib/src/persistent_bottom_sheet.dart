import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_persistent_bottom_sheet/src/reference.dart';

const double _minFlingVelocity = 700.0;
const double _closeProgressThreshold = 0.5;

/// Signature for a function that builds a widget given its state.
typedef StatefulWidgetBuilder = Widget Function(
  BuildContext context,
  Set<WidgetState> state,
);

/// A dockable Material Design bottom sheet.
class PersistentBottomSheet extends BottomSheet {
  /// Creates a persistent bottom sheet.
  ///
  /// If no [animationController] is provided, this widget will create and
  /// manage one internally using [BottomSheet.createAnimationController].
  ///
  /// The [dragHandleColor] and [dragHandleSize] parameters are only used for
  /// the default drag handle, i.e. when [showDragHandle] is `true` and
  /// [dragHandleBuilder] is `null`. Otherwise, these parameters are ignored.
  ///
  /// The [constraints] parameter constrains the size of the entire bottom
  /// sheet, including both the content and the drag handle, whereas
  /// [minContentHeight] only constrains the content.
  const PersistentBottomSheet({
    super.key,
    super.animationController,
    super.enableDrag = true,
    super.showDragHandle,
    super.dragHandleColor,
    super.dragHandleSize,
    super.onDragStart,
    super.onDragEnd,
    super.backgroundColor,
    super.shadowColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    this.minContentHeight,
    this.dragHandleBuilder,
    required super.onClosing,
    required super.builder,
  });

  /// Defines the minimum height (or the height at which the sheet "docks")
  /// for the [PersistentBottomSheet]'s content, i.e. the widget returned by
  /// the [builder].
  ///
  /// If both [minContentHeight] and [constraints] are non-null, the minimum
  /// total bottom sheet height is determined as the greater of the following:
  ///
  ///   * [constraints].minHeight
  ///   * [minContentHeight] + drag handle height
  final Reference<double>? minContentHeight;

  /// A builder for the sheet's drag handle.
  ///
  /// The bottom sheet will wrap the widget produced by this builder in a
  /// [Material] widget.
  final StatefulWidgetBuilder? dragHandleBuilder;

  @override
  State<PersistentBottomSheet> createState() => _PersistentBottomSheetState();
}

class _PersistentBottomSheetState extends State<PersistentBottomSheet>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  final Set<WidgetState> _dragHandleWidgetState = <WidgetState>{};
  final Reference<double> _minHeight = Reference<double>();
  final Reference<double> _maxHeight = Reference<double>();
  final Reference<double> _dragHandleHeight = Reference<double>();
  final Reference<Curve> _animationCurve = Reference<Curve>(Easing.legacy);

  AnimationController get _animationController =>
      widget.animationController ?? _controller!;

  bool get _dismissUnderway =>
      _animationController.status == AnimationStatus.reverse;

  double get _dragExtent {
    final double dragHandleHeight = _dragHandleHeight.value ?? 0.0;
    final double minContentHeight = widget.minContentHeight?.value! ?? 0.0;
    final double minHeight = math.max(
      _minHeight.value!,
      dragHandleHeight + minContentHeight,
    );
    return math.max(0.0, _maxHeight.value! - minHeight);
  }

  @override
  void initState() {
    super.initState();
    if (widget.animationController == null) {
      _controller = BottomSheet.createAnimationController(this);
    }
  }

  @override
  void didUpdateWidget(final PersistentBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationController == null && _controller == null) {
      _controller = BottomSheet.createAnimationController(this);
    } else if (widget.animationController != null && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _handleDragStart(final DragStartDetails details) {
    setState(() {
      _dragHandleWidgetState.add(WidgetState.dragged);
    });
    _animationCurve.value = Curves.linear;
    widget.onDragStart?.call(details);
  }

  void _handleDragUpdate(final DragUpdateDetails details) {
    if (_dismissUnderway) {
      return;
    }
    if (_animationController.isDismissed) {
      // When trying to drag the bottom sheet open after closing it, the
      // animation controller will assume the "reverse" direction, which
      // leads the _dismissUnderway property to falsely identifying this
      // gesture as a dismissal. Calling animateTo with the current value
      // of the animation controller enforces the "forward" direction.
      _animationController.animateTo(
        _animationController.value,
        duration: Duration.zero,
      );
    }
    final double unitDelta = details.primaryDelta! / _dragExtent;
    if ((_animationController.value == 0.0 && unitDelta > 0.0) ||
        (_animationController.value == 1.0 && unitDelta < 0.0)) {
      return;
    }
    _animationController.value -= unitDelta;
  }

  void _handleDragEnd(final DragEndDetails details) {
    if (_dismissUnderway) {
      return;
    }
    setState(() {
      _dragHandleWidgetState.remove(WidgetState.dragged);
    });
    bool isClosing = false;
    if (details.velocity.pixelsPerSecond.dy > _minFlingVelocity) {
      final double flingVelocity =
          -details.velocity.pixelsPerSecond.dy / _dragExtent;
      if (_animationController.value > 0.0) {
        _animationController.fling(velocity: flingVelocity);
      }
      if (flingVelocity < 0.0) {
        isClosing = true;
      }
    } else if (_animationController.value < _closeProgressThreshold) {
      if (_animationController.value > 0.0) {
        _animationController.fling(velocity: -1.0);
      }
      isClosing = true;
    } else {
      _animationController.forward();
    }

    _animationCurve.value = Split(
      _animationController.value,
      endCurve: Easing.legacy,
    );

    widget.onDragEnd?.call(
      details,
      isClosing: isClosing,
    );

    if (isClosing) {
      widget.onClosing();
    }
  }

  void _handleDragHandleHover(final bool hovering) {
    if (hovering != _dragHandleWidgetState.contains(WidgetState.hovered)) {
      setState(() {
        if (hovering) {
          _dragHandleWidgetState.add(WidgetState.hovered);
        } else {
          _dragHandleWidgetState.remove(WidgetState.hovered);
        }
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    final BottomSheetThemeData bottomSheetTheme =
        Theme.of(context).bottomSheetTheme;
    final bool useMaterial3 = Theme.of(context).useMaterial3;
    final BottomSheetThemeData defaults = useMaterial3
        ? _BottomSheetDefaultsM3(context)
        : const BottomSheetThemeData();
    final BoxConstraints? constraints = widget.constraints ??
        bottomSheetTheme.constraints ??
        defaults.constraints;
    final Color? color = widget.backgroundColor ??
        bottomSheetTheme.backgroundColor ??
        defaults.backgroundColor;
    final Color? surfaceTintColor =
        bottomSheetTheme.surfaceTintColor ?? defaults.surfaceTintColor;
    final Color? shadowColor = widget.shadowColor ??
        bottomSheetTheme.shadowColor ??
        defaults.shadowColor;
    final double elevation = widget.elevation ??
        bottomSheetTheme.elevation ??
        defaults.elevation ??
        0.0;
    final ShapeBorder? shape =
        widget.shape ?? bottomSheetTheme.shape ?? defaults.shape;
    final Clip clipBehavior =
        widget.clipBehavior ?? bottomSheetTheme.clipBehavior ?? Clip.none;
    final bool showDragHandle = widget.showDragHandle ??
        (widget.enableDrag && (bottomSheetTheme.showDragHandle ?? false));

    Widget? dragHandle;
    if (showDragHandle) {
      dragHandle =
          widget.dragHandleBuilder?.call(context, _dragHandleWidgetState) ??
              _DragHandle(
                onSemanticsTap: widget.onClosing,
                handleHover: _handleDragHandleHover,
                widgetState: _dragHandleWidgetState,
                dragHandleColor: widget.dragHandleColor,
                dragHandleSize: widget.dragHandleSize,
              );
      // Only add [_BottomSheetGestureDetector] to the drag handle when the rest
      // of the bottom sheet is not draggable. If the whole bottom sheet is
      // draggable, no need to add it.
      if (!widget.enableDrag) {
        dragHandle = _BottomSheetGestureDetector(
          onVerticalDragStart: _handleDragStart,
          onVerticalDragUpdate: _handleDragUpdate,
          onVerticalDragEnd: _handleDragEnd,
          child: dragHandle,
        );
      }

      dragHandle = _MeasureHeight(height: _dragHandleHeight, child: dragHandle);
    } else {
      _dragHandleHeight.value = null;
    }

    Widget bottomSheet = _MeasureHeight(
      minHeight: _minHeight,
      maxHeight: _maxHeight,
      child: Material(
        color: color,
        elevation: elevation,
        surfaceTintColor: surfaceTintColor,
        shadowColor: shadowColor,
        shape: shape,
        clipBehavior: clipBehavior,
        child: _SheetContainer(
          minContentHeight: widget.minContentHeight,
          animationCurve: _animationCurve,
          animation: _animationController,
          dragHandle: dragHandle,
          content: widget.builder(context),
        ),
      ),
    );

    if (constraints != null) {
      bottomSheet = ConstrainedBox(
        constraints: constraints,
        child: bottomSheet,
      );
    }

    return !widget.enableDrag
        ? bottomSheet
        : _BottomSheetGestureDetector(
            onVerticalDragStart: _handleDragStart,
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: bottomSheet,
          );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.onSemanticsTap,
    required this.handleHover,
    required this.widgetState,
    this.dragHandleColor,
    this.dragHandleSize,
  });

  final VoidCallback? onSemanticsTap;
  final ValueChanged<bool> handleHover;
  final Set<WidgetState> widgetState;
  final Color? dragHandleColor;
  final Size? dragHandleSize;

  @override
  Widget build(final BuildContext context) {
    final BottomSheetThemeData bottomSheetTheme =
        Theme.of(context).bottomSheetTheme;
    final BottomSheetThemeData m3Defaults = _BottomSheetDefaultsM3(context);
    final Size handleSize = dragHandleSize ??
        bottomSheetTheme.dragHandleSize ??
        m3Defaults.dragHandleSize!;

    return MouseRegion(
      onEnter: (final PointerEnterEvent event) => handleHover(true),
      onExit: (final PointerExitEvent event) => handleHover(false),
      child: Semantics(
        label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        container: true,
        onTap: onSemanticsTap,
        child: SizedBox(
          height: kMinInteractiveDimension,
          width: kMinInteractiveDimension,
          child: Center(
            child: Container(
              height: handleSize.height,
              width: handleSize.width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(handleSize.height / 2),
                color: WidgetStateProperty.resolveAs<Color?>(
                      dragHandleColor,
                      widgetState,
                    ) ??
                    WidgetStateProperty.resolveAs<Color?>(
                      bottomSheetTheme.dragHandleColor,
                      widgetState,
                    ) ??
                    m3Defaults.dragHandleColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSheetGestureDetector extends StatelessWidget {
  const _BottomSheetGestureDetector({
    required this.child,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  final Widget child;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  @override
  Widget build(final BuildContext context) => RawGestureDetector(
        excludeFromSemantics: true,
        gestures: <Type, GestureRecognizerFactory<GestureRecognizer>>{
          VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
              VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(debugOwner: this),
            (final VerticalDragGestureRecognizer instance) {
              instance
                ..onStart = onVerticalDragStart
                ..onUpdate = onVerticalDragUpdate
                ..onEnd = onVerticalDragEnd
                ..onlyAcceptDragOnThreshold = true;
            },
          ),
        },
        child: child,
      );
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({
    super.child,
    this.height,
    this.minHeight,
    this.maxHeight,
  });

  final Reference<double>? height;
  final Reference<double>? minHeight;
  final Reference<double>? maxHeight;

  @override
  RenderObject createRenderObject(final BuildContext context) =>
      _RenderMeasureHeight(height, minHeight, maxHeight);

  @override
  void updateRenderObject(
    final BuildContext context,
    final _RenderMeasureHeight renderObject,
  ) {
    renderObject
      ..height = height
      ..minHeight = minHeight
      ..maxHeight = maxHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this._height, this._minHeight, this._maxHeight);

  Reference<double>? get height => _height;
  Reference<double>? _height;
  set height(final Reference<double>? value) {
    if (_height == value) {
      return;
    }
    if (_height != null && value != null) {
      value.value = _height!.value;
    }
    _height = value;
  }

  Reference<double>? get minHeight => _minHeight;
  Reference<double>? _minHeight;
  set minHeight(final Reference<double>? value) {
    if (_minHeight == value) {
      return;
    }
    if (_minHeight != null && value != null) {
      value.value = _minHeight!.value;
    }
    _minHeight = value;
  }

  Reference<double>? get maxHeight => _maxHeight;
  Reference<double>? _maxHeight;
  set maxHeight(final Reference<double>? value) {
    if (_maxHeight == value) {
      return;
    }
    if (_maxHeight != null && value != null) {
      value.value = _maxHeight!.value;
    }
    _maxHeight = value;
  }

  @override
  void layout(
    final Constraints constraints, {
    final bool parentUsesSize = false,
  }) {
    super.layout(constraints, parentUsesSize: parentUsesSize);
    _minHeight?.value = this.constraints.minHeight;
    _maxHeight?.value = this.constraints.maxHeight;
  }

  @override
  set size(final Size value) {
    super.size = value;
    _height?.value = size.height;
  }
}

enum _SheetContainerSlot {
  dragHandle,
  content,
}

class _SheetContainer extends SlottedMultiChildRenderObjectWidget<
    _SheetContainerSlot, RenderBox> {
  const _SheetContainer({
    this.minContentHeight,
    required this.animationCurve,
    required this.animation,
    required this.dragHandle,
    required this.content,
  });

  final Reference<double>? minContentHeight;
  final Reference<Curve> animationCurve;
  final Animation<double> animation;
  final Widget? dragHandle;
  final Widget content;

  @override
  Iterable<_SheetContainerSlot> get slots => _SheetContainerSlot.values;

  @override
  Widget? childForSlot(final _SheetContainerSlot slot) => switch (slot) {
        _SheetContainerSlot.dragHandle => dragHandle,
        _SheetContainerSlot.content => content,
      };

  @override
  SlottedContainerRenderObjectMixin<_SheetContainerSlot, RenderBox>
      createRenderObject(final BuildContext context) =>
          _RenderSheetContainer(minContentHeight, animationCurve, animation);

  @override
  void updateRenderObject(
    final BuildContext context,
    final _RenderSheetContainer renderObject,
  ) {
    renderObject
      ..minContentHeight = minContentHeight
      ..animationCurve = animationCurve
      ..animation = animation;
  }
}

class _RenderSheetContainer extends RenderBox
    with SlottedContainerRenderObjectMixin<_SheetContainerSlot, RenderBox> {
  _RenderSheetContainer(
    this._minContentHeight,
    this._animationCurve,
    this._animation,
  );

  Reference<double>? get minContentHeight => _minContentHeight;
  Reference<double>? _minContentHeight;
  set minContentHeight(final Reference<double>? value) {
    if (_minContentHeight == value) {
      return;
    }
    if (attached && _minContentHeight?.value != value?.value) {
      markNeedsLayout();
    }
    _minContentHeight = value;
  }

  Reference<Curve> get animationCurve => _animationCurve;
  Reference<Curve> _animationCurve;
  set animationCurve(final Reference<Curve> value) {
    if (_animationCurve == value) {
      return;
    }
    if (attached) {
      final double oldValue =
          _animationCurve.value!.transform(_animation.value);
      final double newValue = value.value!.transform(_animation.value);
      if (oldValue != newValue) {
        markNeedsLayout();
      }
    }
    _animationCurve = value;
  }

  Animation<double> get animation => _animation;
  Animation<double> _animation;
  set animation(final Animation<double> value) {
    if (_animation == value) {
      return;
    }
    _animation.removeListener(markNeedsLayout);
    if (attached && _animation.value != value.value) {
      markNeedsLayout();
    }
    _animation = value;
    if (attached) {
      _animation.addListener(markNeedsLayout);
    }
  }

  @override
  void attach(final PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    super.detach();
    _animation.removeListener(markNeedsLayout);
  }

  @override
  void performLayout() {
    final double minContentHeight = this.minContentHeight?.value! ?? 0.0;
    final RenderBox? dragHandle = childForSlot(_SheetContainerSlot.dragHandle);
    final RenderBox content = childForSlot(_SheetContainerSlot.content)!;

    if (dragHandle != null) {
      final BoxConstraints dragHandleConstraints = constraints
          .widthConstraints()
          .copyWith(maxHeight: constraints.maxHeight - minContentHeight);
      dragHandle.layout(dragHandleConstraints, parentUsesSize: true);
      _centerChildHorizontally(dragHandle);
    }

    final BoxConstraints contentConstraints = constraints.tighten(
      width: constraints.maxWidth,
      height: constraints.maxHeight - (dragHandle?.size.height ?? 0.0),
    );
    content.layout(contentConstraints);
    _positionChild(content, dy: dragHandle?.size.height ?? 0.0);

    final double minHeight = math.max(
      constraints.minHeight,
      (dragHandle?.size.height ?? 0.0) + minContentHeight,
    );
    final double dragExtent = math.max(0.0, constraints.maxHeight - minHeight);

    size = Size(
      constraints.maxWidth,
      minHeight + dragExtent * animationCurve.value!.transform(animation.value),
    );
  }

  void _centerChildHorizontally(
    final RenderBox child, {
    final double dy = 0.0,
  }) =>
      _positionChild(
        child,
        dx: (constraints.maxWidth - child.size.width) / 2,
        dy: dy,
      );

  void _positionChild(
    final RenderBox child, {
    final double dx = 0.0,
    final double dy = 0.0,
  }) {
    (child.parentData! as BoxParentData).offset = Offset(dx, dy);
  }

  @override
  void paint(final PaintingContext context, final Offset offset) {
    for (final RenderBox child in children) {
      final BoxParentData parentData = child.parentData! as BoxParentData;
      context.paintChild(child, parentData.offset + offset);
    }
  }

  @override
  bool hitTestChildren(
    final BoxHitTestResult result, {
    required final Offset position,
  }) {
    for (final RenderBox child in children) {
      final BoxParentData childParentData = child.parentData! as BoxParentData;
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (final BoxHitTestResult result, final Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }
}

class _BottomSheetDefaultsM3 extends BottomSheetThemeData {
  _BottomSheetDefaultsM3(this.context)
      : super(
          elevation: 1.0,
          modalElevation: 1.0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
          ),
          constraints: const BoxConstraints(maxWidth: 640),
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainerLow;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get dragHandleColor => _colors.onSurfaceVariant;

  @override
  Size? get dragHandleSize => const Size(32, 4);

  @override
  BoxConstraints? get constraints => const BoxConstraints(maxWidth: 640.0);
}
