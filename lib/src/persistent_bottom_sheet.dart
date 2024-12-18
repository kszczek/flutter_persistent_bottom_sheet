import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_persistent_bottom_sheet/src/height_observer.dart';
import 'package:flutter_persistent_bottom_sheet/src/reference.dart';

const double _minFlingVelocity = 700.0;
const double _closeProgressThreshold = 0.5;

/// A dockable Material Design bottom sheet.
class PersistentBottomSheet extends StatefulWidget {
  /// Creates a persistent bottom sheet.
  ///
  /// The [dragHandleColor] and [dragHandleSize] parameters are only used for
  /// the default drag handle, i.e. when [showDragHandle] is true and
  /// [dragHandleBuilder] is null. Otherwise, these parameters are ignored.
  ///
  /// The [constraints] parameter constrains the size of the entire bottom
  /// sheet, including both the content and the drag handle, whereas
  /// [dimensions] constrain the discrete parts of the bottom sheet.
  const PersistentBottomSheet({
    super.key,
    this.onClosing,
    this.enableDrag = true,
    this.showDragHandle,
    this.dragHandleColor,
    this.dragHandleSize,
    this.dragHandleBuilder,
    this.onDragStart,
    this.onDragEnd,
    this.backgroundColor,
    this.shadowColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    required this.animationController,
    required this.curve,
    required this.dimensions,
    required this.builder,
  }) : assert(
          elevation == null || elevation >= 0.0,
          'Elevation must not be negative',
        );

  /// The animation controller that controls the bottom sheet's entrance and
  /// exit animations.
  ///
  /// The PersistentBottomSheet widget will manipulate the position of this
  /// animation, it is not just a passive observer.
  final AnimationController animationController;

  /// The animation curve to use when opening/closing the bottom sheet.
  final Reference<Curve> curve;

  /// Mutable dimensions of this bottom sheet.
  ///
  /// [PersistentBottomSheet] will notify listeners of [dimensions] whenever the
  /// bottom sheet's layout is marked dirty. Widgets that depend on the bottom
  /// sheet's dimensions can listen to this notifier and update their own layout
  /// accordingly.
  final BottomSheetDimensions dimensions;

  /// A builder for the contents of the sheet.
  ///
  /// The bottom sheet will wrap the widget produced by this builder in a
  /// [Material] widget.
  final WidgetBuilder builder;

  /// Called when the bottom sheet begins to close.
  ///
  /// A bottom sheet might be prevented from closing (e.g., by user
  /// interaction) even after this callback is called. For this reason, this
  /// callback might be call multiple times for a given bottom sheet.
  final VoidCallback? onClosing;

  /// If true, the bottom sheet can be dragged up and down and dismissed by
  /// swiping downwards.
  ///
  /// If [showDragHandle] is true, this only applies to the content below the
  /// drag handle, because the drag handle is always draggable.
  ///
  /// Default is true.
  final bool enableDrag;

  /// Specifies whether a drag handle is shown.
  ///
  /// The drag handle appears at the top of the bottom sheet.
  ///
  /// If null, then the value of [BottomSheetThemeData.showDragHandle] is used.
  /// If that is also null, defaults to true.
  final bool? showDragHandle;

  /// The bottom sheet drag handle's color.
  ///
  /// Defaults to [BottomSheetThemeData.dragHandleColor].
  /// If that is also null, defaults to [ColorScheme.onSurfaceVariant].
  final Color? dragHandleColor;

  /// Defaults to [BottomSheetThemeData.dragHandleSize].
  /// If that is also null, defaults to Size(32, 4).
  final Size? dragHandleSize;

  /// A builder for the sheet's drag handle.
  ///
  /// Use [DragHandleWidgetState.of] to access current widget state, e.g.
  /// to change appearance when dragging, hovering, etc.
  ///
  /// The bottom sheet will wrap the widget produced by this builder in a
  /// [Material] widget.
  final WidgetBuilder? dragHandleBuilder;

  /// Called when the user begins dragging the bottom sheet vertically, if
  /// [showDragHandle] or [enableDrag] is true.
  ///
  /// Would typically be used to change the bottom sheet animation curve so
  /// that it tracks the user's finger accurately.
  final BottomSheetDragStartHandler? onDragStart;

  /// Called when the user stops dragging the bottom sheet, if [showDragHandle]
  /// or [enableDrag] is true.
  ///
  /// Would typically be used to reset the bottom sheet animation curve, so
  /// that it animates non-linearly. Called before [onClosing] if the bottom
  /// sheet is closing.
  final BottomSheetDragEndHandler? onDragEnd;

  /// The bottom sheet's background color.
  ///
  /// Defines the bottom sheet's [Material.color].
  ///
  /// Defaults to null and falls back to [Material]'s default.
  final Color? backgroundColor;

  /// The color of the shadow below the sheet.
  ///
  /// If this property is null, then [BottomSheetThemeData.shadowColor] of
  /// [ThemeData.bottomSheetTheme] is used. If that is also null, the default
  /// value is transparent.
  ///
  /// See also:
  ///
  ///  * [elevation], which defines the size of the shadow below the sheet.
  ///  * [shape], which defines the shape of the sheet and its shadow.
  final Color? shadowColor;

  /// The z-coordinate at which to place this material relative to its parent.
  ///
  /// This controls the size of the shadow below the material.
  ///
  /// Defaults to 0. The value is non-negative.
  final double? elevation;

  /// The shape of the bottom sheet.
  ///
  /// Defines the bottom sheet's [Material.shape].
  ///
  /// Defaults to null and falls back to [Material]'s default.
  final ShapeBorder? shape;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defines the bottom sheet's [Material.clipBehavior].
  ///
  /// Use this property to enable clipping of content when the bottom sheet has
  /// a custom [shape] and the content can extend past this shape. For example,
  /// a bottom sheet with rounded corners and an edge-to-edge [Image] at the
  /// top.
  ///
  /// If this property is null then [BottomSheetThemeData.clipBehavior] of
  /// [ThemeData.bottomSheetTheme] is used. If that's null then the behavior
  /// will be [Clip.none].
  final Clip? clipBehavior;

  /// Defines minimum and maximum sizes for a [PersistentBottomSheet].
  ///
  /// If null, then the ambient [ThemeData.bottomSheetTheme]'s
  /// [BottomSheetThemeData.constraints] will be used. If that
  /// is null and [ThemeData.useMaterial3] is true, then the bottom sheet
  /// will have a max width of 640dp. If [ThemeData.useMaterial3] is false, then
  /// the bottom sheet's size will be constrained by its parent
  /// (usually a [Scaffold]). In this case, consider limiting the width by
  /// setting smaller constraints for large screens.
  ///
  /// If constraints are specified (either in this property or in the
  /// theme), the bottom sheet will be aligned to the bottom-center of
  /// the available space. Otherwise, no alignment is applied.
  final BoxConstraints? constraints;

  @override
  State<PersistentBottomSheet> createState() => _PersistentBottomSheetState();
}

class _PersistentBottomSheetState extends State<PersistentBottomSheet> {
  final GlobalKey _childKey = GlobalKey();
  final ValueNotifier<Set<WidgetState>> _dragHandleWidgetState =
      ValueNotifier<Set<WidgetState>>(<WidgetState>{});

  bool get _dismissUnderway =>
      widget.animationController.status == AnimationStatus.reverse;

  double get _dragExtent {
    final RenderBox renderBox =
        _childKey.currentContext!.findRenderObject()! as RenderBox;
    final double dragHandleHeight = widget.dimensions.dragHandleHeight ?? 0.0;
    final double minContentHeight = widget.dimensions.minContentHeight ?? 0.0;
    final double minHeight = math.max(
      renderBox.constraints.minHeight,
      dragHandleHeight + minContentHeight,
    );
    return math.max(0.0, renderBox.constraints.maxHeight - minHeight);
  }

  void _handleDragStart(final DragStartDetails details) {
    _dragHandleWidgetState.value =
        _dragHandleWidgetState.value.union(<WidgetState>{WidgetState.dragged});
    widget.onDragStart?.call(details);
  }

  void _handleDragUpdate(final DragUpdateDetails details) {
    if (_dismissUnderway) {
      return;
    }
    final double unitDelta = details.primaryDelta! / _dragExtent;
    if ((widget.animationController.value == 0.0 && unitDelta > 0.0) ||
        (widget.animationController.value == 1.0 && unitDelta < 0.0)) {
      return;
    }
    if (widget.animationController.isDismissed) {
      // When trying to drag the bottom sheet open after closing it, the
      // animation controller will assume the "reverse" direction, which
      // leads the _dismissUnderway property to falsely identifying this
      // gesture as a dismissal. Calling animateTo with the current value
      // of the animation controller enforces the "forward" direction.
      widget.animationController.animateTo(
        widget.animationController.value,
        duration: Duration.zero,
      );
    }
    widget.animationController.value -= unitDelta;
  }

  void _handleDragEnd(final DragEndDetails details) {
    if (_dismissUnderway) {
      return;
    }
    _dragHandleWidgetState.value = _dragHandleWidgetState.value
        .difference(<WidgetState>{WidgetState.dragged});
    bool isClosing = false;
    if (details.velocity.pixelsPerSecond.dy > _minFlingVelocity) {
      final double flingVelocity =
          -details.velocity.pixelsPerSecond.dy / _dragExtent;
      if (widget.animationController.value > 0.0) {
        widget.animationController.fling(velocity: flingVelocity);
      }
      if (flingVelocity < 0.0) {
        isClosing = true;
      }
    } else if (widget.animationController.value < _closeProgressThreshold) {
      if (widget.animationController.value > 0.0) {
        widget.animationController.fling(velocity: -1.0);
      }
      isClosing = true;
    } else {
      widget.animationController.forward();
    }

    widget.onDragEnd?.call(
      details,
      isClosing: isClosing,
    );

    if (isClosing) {
      widget.onClosing?.call();
    }
  }

  void _handleDragHandleHover(final bool hovering) {
    if (hovering ==
        _dragHandleWidgetState.value.contains(WidgetState.hovered)) {
      return;
    }
    if (hovering) {
      _dragHandleWidgetState.value = _dragHandleWidgetState.value
          .union(<WidgetState>{WidgetState.hovered});
    } else {
      _dragHandleWidgetState.value = _dragHandleWidgetState.value
          .difference(<WidgetState>{WidgetState.hovered});
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
    final bool showDragHandle =
        widget.showDragHandle ?? bottomSheetTheme.showDragHandle ?? true;

    Widget? dragHandle;
    if (showDragHandle) {
      dragHandle = MouseRegion(
        onEnter: (final _) => _handleDragHandleHover(true),
        onExit: (final _) => _handleDragHandleHover(false),
        child: DragHandleWidgetState(
          notifier: _dragHandleWidgetState,
          child: widget.dragHandleBuilder?.call(context) ??
              _DragHandle(
                onSemanticsTap: widget.onClosing,
                dragHandleColor: widget.dragHandleColor,
                dragHandleSize: widget.dragHandleSize,
              ),
        ),
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

      dragHandle = HeightObserver(
        onHeightChanged: (final double height) {
          widget.dimensions._dragHandleHeight = height;
        },
        child: dragHandle,
      );
    } else {
      widget.dimensions._dragHandleHeight = null;
    }

    Widget bottomSheet = Material(
      color: color,
      elevation: elevation,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      shape: shape,
      clipBehavior: clipBehavior,
      child: _SheetContainer(
        key: _childKey,
        dimensions: widget.dimensions,
        animation: widget.animationController,
        curve: widget.curve,
        dragHandle: dragHandle,
        content: widget.builder(context),
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

/// A [Listenable] that holds mutable layout properties of a
/// [PersistentBottomSheet].
///
/// Listeners are notified whenever the bottom sheet's layout is marked dirty,
/// allowing dependent widgets to update their own layouts accordingly.
class BottomSheetDimensions with ChangeNotifier {
  /// The height of the drag handle.
  ///
  /// This value is measured by the [PersistentBottomSheet] during the layout
  /// phase.
  double? get dragHandleHeight => _dragHandleHeight;
  double? _dragHandleHeight;

  /// The minimum height of the content.
  ///
  /// If both [minContentHeight] and [PersistentBottomSheet.constraints] are
  /// provided, the total minimum height of the [PersistentBottomSheet] is
  /// the greater of:
  ///
  ///   * [PersistentBottomSheet.constraints].minHeight
  ///   * [minContentHeight] + [dragHandleHeight]
  ///
  /// This property can be hardcoded or measured during the layout phase.
  /// For example, to measure the height of a [NavigationBar] into this
  /// property, you can use the [HeightObserver] widget:
  ///
  /// ```dart
  /// HeightObserver(
  ///   onHeightChanged: (final double height) {
  ///     dimensions.minContentHeight = height;
  ///   },
  ///   child: NavigationBar(
  ///     ...
  ///   ),
  /// )
  /// ```
  double? minContentHeight;

  void _markNeedsLayout() => notifyListeners();
}

/// A widget that determines the interactive state of its descendants.
///
/// For example, a drag handle implementation can use this information to change
/// its color on hover.
class DragHandleWidgetState
    extends InheritedNotifier<ValueNotifier<Set<WidgetState>>> {
  /// Creates a widget that determines the interactive state of its descendants.
  const DragHandleWidgetState({
    super.key,
    required ValueNotifier<Set<WidgetState>> super.notifier,
    required super.child,
  });

  /// A set of widget states from the closest instance of this class that
  /// encloses the given [context].
  ///
  /// If there is no [DragHandleWidgetState] ancestor widget in the tree at the
  /// given context, then this will throw a descriptive [AssertionError] in
  /// debug mode and an exception in release mode.
  ///
  /// See also:
  ///
  ///  * [maybeOf], which will return null if no [DragHandleWidgetState]
  ///    ancestor widget is in the tree.
  static Set<WidgetState> of(final BuildContext context) {
    final Set<WidgetState>? result = maybeOf(context);
    assert(result != null, 'No DragHandleWidgetState found in context');
    return result!;
  }

  /// A set of widget states from the closest instance of this class that
  /// encloses the given [context].
  ///
  /// If there is no [DragHandleWidgetState] ancestor widget in the tree at the
  /// given context, then this will return null.
  ///
  /// See also:
  ///
  ///  * [of], which will throw if no [DragHandleWidgetState] ancestor widget is
  ///    in the tree.
  static Set<WidgetState>? maybeOf(final BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DragHandleWidgetState>()
      ?.notifier!
      .value;
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.onSemanticsTap,
    this.dragHandleColor,
    this.dragHandleSize,
  });

  final VoidCallback? onSemanticsTap;
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
    final Set<WidgetState> widgetState = DragHandleWidgetState.of(context);

    return Semantics(
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

enum _SheetContainerSlot {
  dragHandle,
  content,
}

class _SheetContainer extends SlottedMultiChildRenderObjectWidget<
    _SheetContainerSlot, RenderBox> {
  const _SheetContainer({
    super.key,
    required this.dimensions,
    required this.animation,
    required this.curve,
    required this.dragHandle,
    required this.content,
  });

  final BottomSheetDimensions dimensions;
  final Animation<double> animation;
  final Reference<Curve> curve;
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
          _RenderSheetContainer(dimensions, animation, curve);

  @override
  void updateRenderObject(
    final BuildContext context,
    final _RenderSheetContainer renderObject,
  ) {
    renderObject
      ..dimensions = dimensions
      ..animation = animation
      ..curve = curve;
  }
}

class _RenderSheetContainer extends RenderBox
    with SlottedContainerRenderObjectMixin<_SheetContainerSlot, RenderBox> {
  _RenderSheetContainer(this._dimensions, this._animation, this._curve);

  BottomSheetDimensions get dimensions => _dimensions;
  BottomSheetDimensions _dimensions;
  set dimensions(final BottomSheetDimensions value) {
    if (_dimensions == value) {
      return;
    }
    if (attached && _dimensions.minContentHeight != value.minContentHeight) {
      markNeedsLayout();
    }
    _dimensions = value;
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

  Reference<Curve> get curve => _curve;
  Reference<Curve> _curve;
  set curve(final Reference<Curve> value) {
    if (_curve == value) {
      return;
    }
    if (attached) {
      final double oldValue = _curve.value.transform(_animation.value);
      final double newValue = value.value.transform(_animation.value);
      if (oldValue != newValue) {
        markNeedsLayout();
      }
    }
    _curve = value;
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
    final double minContentHeight = _dimensions.minContentHeight ?? 0.0;
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
      minHeight + dragExtent * curve.value.transform(animation.value),
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

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    _dimensions._markNeedsLayout();
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
