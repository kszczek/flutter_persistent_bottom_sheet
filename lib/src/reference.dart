/// Reference to a mutable value of type [T].
class Reference<T> {
  /// Creates a reference with an optional initial [value].
  Reference([this.value]);

  /// The value this reference points to.
  T? value;
}
