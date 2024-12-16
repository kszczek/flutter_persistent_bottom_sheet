/// Mutable reference to a value of type [T].
class Reference<T> implements ReadOnlyReference<T> {
  /// Creates a reference with an initial [value].
  Reference(this.value);

  /// The value this reference points to.
  @override
  T value;
}

/// Read-only reference to a value of type [T].
abstract class ReadOnlyReference<T> {
  /// The value this reference points to.
  T get value;
}
