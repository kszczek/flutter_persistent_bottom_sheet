import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that invokes callbacks whenever the layout of its child is marked
/// dirty or its dimensions change.
class LayoutObserver extends SingleChildRenderObjectWidget {
  /// Creates a widget that invokes callbacks whenever the layout of its [child]
  /// is marked dirty or its dimensions change.
  const LayoutObserver({
    super.key,
    super.child,
    this.onHeightChanged,
    this.onLayoutMarkedDirty,
  });

  /// Called whenever the height of the [child] widget changes.
  final ValueChanged<double>? onHeightChanged;

  /// Called whenever the layout of the [child] widget is marked dirty.
  final VoidCallback? onLayoutMarkedDirty;

  @override
  RenderObject createRenderObject(final BuildContext context) =>
      RenderLayoutObserver(onHeightChanged, onLayoutMarkedDirty);

  @override
  void updateRenderObject(
    final BuildContext context,
    final RenderLayoutObserver renderObject,
  ) {
    renderObject
      ..onHeightChanged = onHeightChanged
      ..onLayoutMarkedDirty = onLayoutMarkedDirty;
  }
}

/// A render object that invokes callbacks whenever the layout of its child is
/// marked dirty or its dimensions change.
class RenderLayoutObserver extends RenderProxyBox {
  /// Creates a render object that invokes callbacks whenever the layout of its
  /// [child] is marked dirty or its dimensions change.
  RenderLayoutObserver(this._onHeightChanged, this._onLayoutMarkedDirty);

  /// Called whenever the height of the [child] render object changes.
  ValueChanged<double>? get onHeightChanged => _onHeightChanged;
  ValueChanged<double>? _onHeightChanged;
  set onHeightChanged(final ValueChanged<double>? value) {
    if (value == _onHeightChanged) {
      return;
    }
    _onHeightChanged = value;
  }

  /// Called whenever the layout of the [child] render object is marked dirty.
  VoidCallback? get onLayoutMarkedDirty => _onLayoutMarkedDirty;
  VoidCallback? _onLayoutMarkedDirty;
  set onLayoutMarkedDirty(final VoidCallback? value) {
    if (value == _onLayoutMarkedDirty) {
      return;
    }
    _onLayoutMarkedDirty = value;
  }

  double? _lastHeight;

  @override
  set size(final Size value) {
    super.size = value;
    if (size.height != _lastHeight) {
      _lastHeight = size.height;
      _onHeightChanged?.call(size.height);
    }
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    _onLayoutMarkedDirty?.call();
  }
}
