/// A total result type. `null` is never a failure signal in this codebase
/// (docs/instructions.md §5.3), so every fallible operation returns one of
/// these instead.
sealed class Result<T, E> {
  const Result();

  /// Whether this result carries a value.
  bool get isOk => this is Ok<T, E>;

  /// Whether this result carries an error.
  bool get isErr => this is Err<T, E>;

  /// The value, or `null` when this is an [Err]. Only for call sites that have
  /// already handled the failure — never as a failure test.
  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => null,
  };

  /// The error, or `null` when this is an [Ok].
  E? get errorOrNull => switch (this) {
    Ok<T, E>() => null,
    Err<T, E>(:final error) => error,
  };

  /// Collapses both branches into a single value, forcing the caller to say
  /// what a failure looks like.
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok<T, E>(:final value) => onOk(value),
        Err<T, E>(:final error) => onErr(error),
      };

  /// Maps the success value, preserving any error.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<R, E>(transform(value)),
    Err<T, E>(:final error) => Err<R, E>(error),
  };

  /// Maps the error, preserving any value.
  Result<T, R> mapErr<R>(R Function(E error) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<T, R>(value),
    Err<T, E>(:final error) => Err<T, R>(transform(error)),
  };
}

/// A successful [Result].
final class Ok<T, E> extends Result<T, E> {
  /// Wraps [value] as a success.
  const Ok(this.value);

  /// The successful value.
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result].
final class Err<T, E> extends Result<T, E> {
  /// Wraps [error] as a failure.
  const Err(this.error);

  /// The failure.
  final E error;

  @override
  bool operator ==(Object other) => other is Err<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}

/// The absence of a meaningful success value — `Result<Unit, F>` rather than
/// `Result<void, F>`, which cannot be pattern matched.
final class Unit {
  const Unit._();

  @override
  String toString() => 'unit';
}

/// The single [Unit] instance.
const Unit unit = Unit._();
