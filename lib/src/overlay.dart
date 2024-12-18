import 'package:flutter/material.dart';
import 'package:flutter_persistent_bottom_sheet/src/persistent_bottom_sheet.dart';

/// Signature for a function that creates overlay widgets displayed above the
/// widget created by [PersistentBottomSheetOverlay.overlaidBuilder].
///
/// {@template flutter_persistent_bottom_sheet.OverlayBuilder}
/// This function is called repeatedly with an incrementing [index] until it
/// returns null. Widgets returned by this function are laid out in ascending
/// [index] order, with the [OverlaidBuilder] laid out last. The widgets are
/// then painted in reverse order, starting with the [OverlaidBuilder] and then
/// the widgets created by this function in descending [index] order.
///
/// The provided [dimensions] may optionally be used by widgets created by this
/// function to measure or consume bottom sheet's dimensions at layout time.
/// Those dimensions will be used by the [PersistentBottomSheetOverlay] to size
/// the placeholder passed to the [OverlaidBuilder].
/// {@endtemplate}
typedef OverlayBuilder = Widget? Function(
  BuildContext context,
  int index,
  BottomSheetDimensions dimensions,
);

/// Signature for a function that creates a widget displayed below all of the
/// widgets created by [PersistentBottomSheetOverlay.overlayBuilder].
///
/// {@template flutter_persistent_bottom_sheet.OverlaidBuilder}
/// The widget returned by this function is laid out after all overlay widgets
/// have been laid out, but painted before any of them. This order of operations
/// introduces the ability to create dependencies on the dimensions of overlay
/// widgets.
///
/// The [bottomSheetPlaceholder] is a transparent widget that has the same
/// height as the overlaid [PersistentBottomSheet] in its closed position.
/// {@endtemplate}
typedef OverlaidBuilder = Widget Function(
  BuildContext context,
  Widget bottomSheetPlaceholder,
);

/// A widget that overlays multiple widgets over a single widget.
///
/// Typically, one of the overlaying widgets is a [PersistentBottomSheet], and
/// the overlaid widget is a [Scaffold], however that is not enforced.
class PersistentBottomSheetOverlay extends StatefulWidget {
  /// Creates a widget that overlays multiple widgets over a single widget.
  const PersistentBottomSheetOverlay({
    super.key,
    required this.overlayBuilder,
    required this.overlaidBuilder,
  });

  /// Creates widgets displayed above the widget created by [overlaidBuilder].
  ///
  /// {@macro flutter_persistent_bottom_sheet.OverlayBuilder}
  final OverlayBuilder overlayBuilder;

  /// Creates a widget displayed below all of the widgets created by
  /// [overlayBuilder].
  ///
  /// {@macro flutter_persistent_bottom_sheet.OverlaidBuilder}
  final OverlaidBuilder overlaidBuilder;

  @override
  State<PersistentBottomSheetOverlay> createState() =>
      _PersistentBottomSheetOverlayState();
}

class _PersistentBottomSheetOverlayState
    extends State<PersistentBottomSheetOverlay> {
  final BottomSheetDimensions _dimensions = BottomSheetDimensions();
  late final SingleChildLayoutDelegate _placeholderDelegate;

  @override
  void initState() {
    super.initState();
    _placeholderDelegate = _PlaceholderLayoutDelegate(_dimensions);
  }

  @override
  Widget build(final BuildContext context) {
    final List<Widget> children = <Widget>[];

    Widget? overlayWidget;
    do {
      overlayWidget = widget.overlayBuilder(
        context,
        children.length,
        _dimensions,
      );
      if (overlayWidget != null) {
        children.add(overlayWidget);
      }
    } while (overlayWidget != null);

    final Widget placeholder = CustomSingleChildLayout(
      delegate: _placeholderDelegate,
    );
    children.add(widget.overlaidBuilder(context, placeholder));

    return Flow(
      delegate: const _OverlayFlowDelegate(),
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

class _PlaceholderLayoutDelegate extends SingleChildLayoutDelegate {
  const _PlaceholderLayoutDelegate(this.dimensions)
      : super(relayout: dimensions);

  final BottomSheetDimensions dimensions;

  @override
  Size getSize(final BoxConstraints constraints) => dimensions.minHeight != null
      ? constraints.tighten(height: dimensions.minHeight).biggest
      : constraints.smallest;

  @override
  bool shouldRelayout(final _PlaceholderLayoutDelegate oldDelegate) =>
      oldDelegate.dimensions.minHeight != dimensions.minHeight;
}

class _OverlayFlowDelegate extends FlowDelegate {
  const _OverlayFlowDelegate();

  @override
  void paintChildren(final FlowPaintingContext context) {
    // Paint children in reverse layout order. This enables the overlaid widget
    // to create dependencies on the dimensions of widgets overlaying it, which
    // is not possible with a regular Stack, because it lays out and paints its
    // children in the same order.
    for (int i = context.childCount - 1; i >= 0; i--) {
      context.paintChild(i);
    }
  }

  @override
  bool shouldRepaint(final _OverlayFlowDelegate oldDelegate) => false;
}
