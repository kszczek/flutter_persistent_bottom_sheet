import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that calls a callback whenever the height of its child changes.
class HeightObserver extends SingleChildRenderObjectWidget {
  /// Creates a widget that calls a callback whenever the height of its [child]
  /// changes.
  const HeightObserver({
    super.key,
    super.child,
    required this.onHeightChanged,
  });

  /// Called whenever the height of the [child] widget changes.
  final ValueChanged<double> onHeightChanged;

  @override
  RenderObject createRenderObject(final BuildContext context) =>
      RenderHeightObserver(onHeightChanged);

  @override
  void updateRenderObject(
    final BuildContext context,
    final RenderHeightObserver renderObject,
  ) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

/// A render object that calls a callback whenever the height of its child
/// changes.
class RenderHeightObserver extends RenderProxyBox {
  /// Creates a render object that calls a callback whenever the height of its
  /// child changes.
  RenderHeightObserver(this._onHeightChanged);

  /// Called whenever the height of the [child] render object changes.
  ValueChanged<double> get onHeightChanged => _onHeightChanged;
  ValueChanged<double> _onHeightChanged;
  set onHeightChanged(final ValueChanged<double> value) {
    if (_onHeightChanged == value) {
      return;
    }
    _onHeightChanged = value;
  }

  @override
  set size(final Size value) {
    super.size = value;
    _onHeightChanged(size.height);
  }
}
