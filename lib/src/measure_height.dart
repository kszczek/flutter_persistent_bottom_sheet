import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_persistent_bottom_sheet/src/reference.dart';

/// A widget that measures height dimensions and constraints of its child.
///
/// This widget works on references instead of values, because the dimensions
/// are meant to be measured and consumed in a single layout phase, which would
/// not have been possible using regular values as they would have had to be
/// passed around the widget tree, thus requiring a build between the
/// measurement and consumption.
class MeasureHeight extends SingleChildRenderObjectWidget {
  /// Creates a widget that measures height dimensions and constraints of
  /// its child.
  const MeasureHeight({
    super.key,
    super.child,
    this.height,
    this.minHeight,
    this.maxHeight,
  });

  /// The measured height of the [child] widget.
  final Reference<double?>? height;

  /// The [BoxConstraints.minHeight] constraint received by the [child] widget.
  final Reference<double?>? minHeight;

  /// The [BoxConstraints.maxHeight] constraint received by the [child] widget.
  final Reference<double?>? maxHeight;

  @override
  RenderObject createRenderObject(final BuildContext context) =>
      RenderMeasureHeight(height, minHeight, maxHeight);

  @override
  void updateRenderObject(
    final BuildContext context,
    final RenderMeasureHeight renderObject,
  ) {
    renderObject
      ..height = height
      ..minHeight = minHeight
      ..maxHeight = maxHeight;
  }
}

/// A render object that measures height dimensions and constraints of its
/// child.
///
/// This render object works on references instead of values, because the
/// dimensions are meant to be measured and consumed in a single layout phase,
/// which would not have been possible using regular values as they would have
/// had to be passed around the widget tree, thus requiring a build between the
/// measurement and consumption.
class RenderMeasureHeight extends RenderProxyBox {
  /// Creates a render object that measures height dimensions and constraints of
  /// its child.
  RenderMeasureHeight(this._height, this._minHeight, this._maxHeight);

  /// The measured height of the [child] render object.
  Reference<double?>? get height => _height;
  Reference<double?>? _height;
  set height(final Reference<double?>? value) {
    if (_height == value) {
      return;
    }
    if (_height != null && value != null) {
      value.value = _height!.value;
    }
    _height = value;
  }

  /// The [BoxConstraints.minHeight] constraint received by the [child]
  /// render object.
  Reference<double?>? get minHeight => _minHeight;
  Reference<double?>? _minHeight;
  set minHeight(final Reference<double?>? value) {
    if (_minHeight == value) {
      return;
    }
    if (_minHeight != null && value != null) {
      value.value = _minHeight!.value;
    }
    _minHeight = value;
  }

  /// The [BoxConstraints.maxHeight] constraint received by the [child]
  /// render object.
  Reference<double?>? get maxHeight => _maxHeight;
  Reference<double?>? _maxHeight;
  set maxHeight(final Reference<double?>? value) {
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
