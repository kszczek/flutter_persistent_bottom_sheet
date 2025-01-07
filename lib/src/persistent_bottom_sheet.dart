import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double _kCloseProgressThreshold = 0.5;
const double _kMinFlingVelocity = 700.0;

const double _kBottomSheetDominatesPercentage = 0.7;

// https://m3.material.io/styles/elevation/applying-elevation
const double _kBottomSheetScrimOpacity = 0.32;

// https://github.com/material-components/material-components-android/blob/37a85c3b293c7ee353e24e065cd726ec8dae8718/lib/java/com/google/android/material/bottomsheet/res/anim/m3_bottom_sheet_slide_in.xml
// https://github.com/material-components/material-components-android/blob/37a85c3b293c7ee353e24e065cd726ec8dae8718/lib/java/com/google/android/material/bottomsheet/res/anim/m3_bottom_sheet_slide_out.xml
const Curve _kBottomSheetCurve = Curves.easeInOutCubicEmphasized;
const Duration _kBottomSheetEnterDuration = Duration(milliseconds: 400);
const Duration _kBottomSheetExitDuration = Duration(milliseconds: 350);

/// A Material Design persistent bottom sheet.
///
/// This widget extends Flutter's built-in [BottomSheet], providing several
/// enhancements, including:
///
///   * The sheet is overlaid above the [child] widget, typically a [Scaffold].
///   * The sheet's drag handle, defined by the [dragHandle] parameter, is
///     separate from the sheet's body, allowing the handle to remain visible
///     when the sheet is collapsed.
///   * A [navigationBar] widget can be displayed above both the [child] and
///     the bottom sheet, sliding out of view or back into view as the sheet is
///     opened or closed.
class PersistentBottomSheet extends BottomSheet {
  /// Creates a Material Design persistent bottom sheet.
  ///
  /// The [dragHandleColor] and [dragHandleSize] parameters apply only to the
  /// default drag handle, i.e. when [showDragHandle] is true, but
  /// [dragHandleBuilder] is null. If a custom [dragHandleBuilder] is provided,
  /// these parameters are ignored.
  ///
  /// When [showDragHandle] is true, the [shape] parameter applies to the
  /// [Material] of the drag handle, while the [Material] of the content remains
  /// rectangular. If [showDragHandle] is false, the [shape] parameter applies
  /// only to the [Material] of the content.
  const PersistentBottomSheet({
    super.key,
    super.animationController,
    super.enableDrag = true,
    super.showDragHandle,
    this.dragHandleBuilder,
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
    this.navigationBar,
    required super.onClosing,
    required super.builder,
    required this.child,
  });

  /// A builder for the drag handle of the sheet.
  ///
  /// Use [DragHandleWidgetState.of] to access the current state of the drag
  /// handle, e.g. to change its appearance when dragging, hovering, etc.
  ///
  /// When the sheet is collapsed, the drag handle rests on the [navigationBar],
  /// if one is provided. Otherwise, it rests on the bottom edge of the view.
  final WidgetBuilder? dragHandleBuilder;

  /// A navigation bar displayed at the bottom of this widget, above the sheet.
  ///
  /// The [navigationBar] slides out of view as the sheet is opened and slides
  /// back into view as the sheet is closed.
  final Widget? navigationBar;

  /// The widget below this widget in the tree.
  ///
  /// Typically a [Scaffold].
  final Widget child;

  @override
  State<PersistentBottomSheet> createState() => _PersistentBottomSheetState();

  /// Creates an [AnimationController] suitable for a
  /// [PersistentBottomSheet.animationController].
  ///
  /// This API is available as a convenience for a Material compliant bottom
  /// sheet animation. If alternative animation durations are required,
  /// a different animation controller could be provided.
  static AnimationController createAnimationController(
    final TickerProvider vsync, {
    final Duration? duration,
    final Duration? reverseDuration,
  }) =>
      AnimationController(
        duration: duration ?? _kBottomSheetEnterDuration,
        reverseDuration: reverseDuration ?? _kBottomSheetExitDuration,
        debugLabel: 'PersistentBottomSheet',
        vsync: vsync,
      );
}

class _PersistentBottomSheetState extends State<PersistentBottomSheet> {
  late Animation<double> _animation;
  final CurveTween _tween = CurveTween(curve: _kBottomSheetCurve);
  final GlobalKey _contentKey =
      GlobalKey(debugLabel: 'PersistentBottomSheet content');
  final GlobalKey _navigationBarKey =
      GlobalKey(debugLabel: 'PersistentBottomSheet navigation bar');
  final ValueNotifier<Set<WidgetState>> _dragHandleWidgetState =
      ValueNotifier<Set<WidgetState>>(<WidgetState>{});

  @override
  void initState() {
    super.initState();
    _animation =
        widget.animationController?.drive(_tween) ?? kAlwaysCompleteAnimation;
  }

  @override
  void didUpdateWidget(final PersistentBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationController != widget.animationController) {
      _animation =
          widget.animationController?.drive(_tween) ?? kAlwaysCompleteAnimation;
    }
  }

  bool get _dismissUnderway =>
      widget.animationController!.status == AnimationStatus.reverse;

  double get _dragExtent {
    assert(
      _contentKey.currentContext != null,
      "PersistentBottomSheet's content is expected to be present in the tree "
      "unconditionally. 'PersistentBottomSheet.builder' is a required "
      'parameter always returning a non-nullable widget.',
    );
    final RenderBox? contentRenderBox =
        _contentKey.currentContext!.findRenderObject() as RenderBox?;
    double dragExtent = contentRenderBox?.size.height ?? 0.0;

    if (_navigationBarKey.currentContext != null) {
      final RenderBox? navigationBarRenderBox =
          _navigationBarKey.currentContext!.findRenderObject() as RenderBox?;
      if (navigationBarRenderBox != null) {
        dragExtent -= navigationBarRenderBox.size.height;
      }
    }

    return dragExtent;
  }

  double get _scrimOpacity {
    if (_animation.value <= _kBottomSheetDominatesPercentage) {
      return 0.0;
    }

    return (_animation.value - _kBottomSheetDominatesPercentage) /
        (1.0 - _kBottomSheetDominatesPercentage) *
        _kBottomSheetScrimOpacity;
  }

  void _handleDragStart(final DragStartDetails details) {
    _dragHandleWidgetState.value =
        _dragHandleWidgetState.value.union(<WidgetState>{WidgetState.dragged});
    widget.onDragStart?.call(details);
    _tween.curve = Curves.linear;
  }

  void _handleDragUpdate(final DragUpdateDetails details) {
    assert(
      (widget.enableDrag || (widget.showDragHandle ?? false)) &&
          widget.animationController != null,
      "'PersistentBottomSheet.animationController' cannot be null when "
      "'PersistentBottomSheet.enableDrag' or "
      "'PersistentBottomSheet.showDragHandle' is true. "
      "Use 'PersistentBottomSheet.createAnimationController' to create one, "
      'or provide another AnimationController.',
    );
    if (_dismissUnderway) {
      return;
    }
    final double unitDelta = details.primaryDelta! / _dragExtent;
    if ((widget.animationController!.value <= 0.0 && unitDelta > 0.0) ||
        (widget.animationController!.value >= 1.0 && unitDelta < 0.0)) {
      return;
    }
    if (widget.animationController!.isDismissed) {
      // When trying to drag the bottom sheet open after closing it, the
      // animation controller will assume the "reverse" direction, which
      // leads the _dismissUnderway property to falsely identifying this
      // gesture as a dismissal. Calling animateTo with the current value
      // of the animation controller enforces the "forward" direction.
      widget.animationController!.animateTo(
        widget.animationController!.value,
        duration: Duration.zero,
      );
    }
    widget.animationController!.value -= unitDelta;
  }

  void _handleDragEnd(final DragEndDetails details) {
    assert(
      (widget.enableDrag || (widget.showDragHandle ?? false)) &&
          widget.animationController != null,
      "'PersistentBottomSheet.animationController' cannot be null when "
      "'PersistentBottomSheet.enableDrag' or "
      "'PersistentBottomSheet.showDragHandle' is true. "
      "Use 'PersistentBottomSheet.createAnimationController' to create one, "
      'or provide another AnimationController.',
    );
    if (_dismissUnderway) {
      return;
    }
    _dragHandleWidgetState.value = _dragHandleWidgetState.value
        .difference(<WidgetState>{WidgetState.dragged});
    bool isClosing = false;
    if (details.velocity.pixelsPerSecond.dy > _kMinFlingVelocity) {
      final double flingVelocity =
          -details.velocity.pixelsPerSecond.dy / _dragExtent;
      if (widget.animationController!.value > 0.0) {
        widget.animationController!.fling(velocity: flingVelocity);
      }
      if (flingVelocity < 0.0) {
        isClosing = true;
      }
    } else if (widget.animationController!.value < _kCloseProgressThreshold) {
      if (widget.animationController!.value > 0.0) {
        widget.animationController!.fling(velocity: -1.0);
      }
      isClosing = true;
    } else {
      widget.animationController!.forward();
    }

    widget.onDragEnd?.call(
      details,
      isClosing: isClosing,
    );

    _tween.curve = Split(
      widget.animationController!.value,
      endCurve: _kBottomSheetCurve,
    );

    if (isClosing) {
      widget.onClosing();
    }
  }

  void _handleDragHandleHover(final bool hovering) {
    final bool containsHovered =
        _dragHandleWidgetState.value.contains(WidgetState.hovered);
    if (hovering == containsHovered) {
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

  void _handleSemanticsTap() {
    widget.animationController?.toggle();
    if (_dismissUnderway) {
      widget.onClosing();
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
        0;
    final ShapeBorder? shape =
        widget.shape ?? bottomSheetTheme.shape ?? defaults.shape;
    final Clip clipBehavior =
        widget.clipBehavior ?? bottomSheetTheme.clipBehavior ?? Clip.none;
    final bool showDragHandle = widget.showDragHandle ??
        (widget.enableDrag && (bottomSheetTheme.showDragHandle ?? false));

    Widget? dragHandle;
    if (showDragHandle) {
      dragHandle = Material(
        color: color,
        elevation: elevation,
        surfaceTintColor: surfaceTintColor,
        shadowColor: shadowColor,
        shape: shape,
        clipBehavior: clipBehavior,
        child: _BottomSheetGestureDetector(
          onVerticalDragStart: _handleDragStart,
          onVerticalDragUpdate: _handleDragUpdate,
          onVerticalDragEnd: _handleDragEnd,
          child: MouseRegion(
            onEnter: (final _) => _handleDragHandleHover(true),
            onExit: (final _) => _handleDragHandleHover(false),
            child: DragHandleWidgetState(
              notifier: _dragHandleWidgetState,
              child: Builder(
                builder: (final BuildContext context) =>
                    widget.dragHandleBuilder?.call(context) ??
                    SizedBox(
                      width: double.infinity,
                      child: _DragHandle(
                        onSemanticsTap: _handleSemanticsTap,
                        dragHandleColor: widget.dragHandleColor,
                        dragHandleSize: widget.dragHandleSize,
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget content = Material(
      key: _contentKey,
      color: color,
      elevation: elevation,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      shape: showDragHandle ? null : shape,
      clipBehavior: clipBehavior,
      child: !widget.enableDrag
          ? widget.builder(context)
          : _BottomSheetGestureDetector(
              onVerticalDragStart: _handleDragStart,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: widget.builder(context),
            ),
    );

    final Widget modalBarrier = AnimatedBuilder(
      animation: _animation,
      builder: (final BuildContext context, final _) {
        final double opacity = _scrimOpacity;
        return IgnorePointer(
          ignoring: opacity == 0.0,
          child: ModalBarrier(
            color: Colors.black.withValues(alpha: opacity),
            dismissible: false,
          ),
        );
      },
    );

    return CustomMultiChildLayout(
      delegate: _LayoutDelegate(
        animation: _animation,
        constraints: constraints,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
      children: <Widget>[
        LayoutId(id: _Slot.child, child: widget.child),
        LayoutId(id: _Slot.modalBarrier, child: modalBarrier),
        LayoutId(id: _Slot.content, child: content),
        if (dragHandle != null)
          LayoutId(id: _Slot.dragHandle, child: dragHandle),
        if (widget.navigationBar != null)
          LayoutId(
            id: _Slot.navigationBar,
            child: KeyedSubtree(
              key: _navigationBarKey,
              child: widget.navigationBar!,
            ),
          ),
      ],
    );
  }
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
        width: math.max(handleSize.width, kMinInteractiveDimension),
        height: math.max(handleSize.height, kMinInteractiveDimension),
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
        behavior: HitTestBehavior.opaque,
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

enum _Slot {
  child,
  modalBarrier,
  content,
  dragHandle,
  navigationBar,
}

class _LayoutDelegate extends MultiChildLayoutDelegate {
  _LayoutDelegate({
    required this.animation,
    required this.constraints,
    required this.devicePixelRatio,
  }) : super(relayout: animation);

  final Animation<double> animation;
  final BoxConstraints? constraints;
  final double devicePixelRatio;

  @override
  void performLayout(final Size size) {
    double navigationBarVisibleHeight = 0.0;
    Size navigationBarSize = Size.zero;
    Size dragHandleSize = Size.zero;
    Size contentSize = Size.zero;
    late Offset contentOffset;

    if (hasChild(_Slot.navigationBar)) {
      navigationBarSize = layoutChild(
        _Slot.navigationBar,
        BoxConstraints.tight(size).copyWith(minHeight: 0.0),
      );

      navigationBarVisibleHeight =
          navigationBarSize.height * (1 - animation.value);

      positionChild(
        _Slot.navigationBar,
        Offset(0.0, size.height - navigationBarVisibleHeight),
      );
    }

    BoxConstraints sheetConstraints = BoxConstraints.loose(size);
    if (constraints != null) {
      sheetConstraints = constraints!.enforce(sheetConstraints);
    }

    if (hasChild(_Slot.dragHandle)) {
      dragHandleSize = layoutChild(
        _Slot.dragHandle,
        sheetConstraints.copyWith(
          minHeight: 0.0,
          maxHeight: math.max(
            0.0,
            sheetConstraints.maxHeight - navigationBarVisibleHeight,
          ),
        ),
      );

      sheetConstraints =
          sheetConstraints.deflate(EdgeInsets.only(top: dragHandleSize.height));
    }

    contentSize = layoutChild(_Slot.content, sheetConstraints);
    final double dragExtent = contentSize.height - navigationBarSize.height;
    contentOffset = Offset(
      (size.width - contentSize.width) / 2,
      size.height - navigationBarSize.height - dragExtent * animation.value,
    );
    positionChild(_Slot.content, contentOffset);

    if (hasChild(_Slot.dragHandle)) {
      positionChild(
        _Slot.dragHandle,
        Offset(
          (size.width - dragHandleSize.width) / 2,
          contentOffset.dy - dragHandleSize.height,
        ),
      );
    }

    layoutChild(_Slot.modalBarrier, BoxConstraints.tight(size));
    positionChild(_Slot.modalBarrier, Offset.zero);

    layoutChild(
      _Slot.child,
      BoxConstraints.tightFor(
        width: size.width,
        height: size.height - dragHandleSize.height - navigationBarSize.height,
      ),
    );
    positionChild(_Slot.child, Offset.zero);
  }

  @override
  bool shouldRelayout(final _LayoutDelegate oldDelegate) =>
      oldDelegate.animation.value != animation.value ||
      oldDelegate.constraints != constraints ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
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
