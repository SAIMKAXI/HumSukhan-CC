import 'package:humsukhan/core/failure/failure.dart';

/// The four states every async surface in the app must be able to express.
///
/// Named `Operation*` rather than `Async*` so it never collides with Riverpod's
/// `AsyncValue` family at a call site that uses both.
///
/// An early `return` that changes no state is forbidden (B7): a command either
/// moves this to [OperationSuccess] or to [OperationFailure], never leaves it where it
/// was without a reason.
sealed class OperationState<T> {
  const OperationState();

  /// Never requested.
  bool get isIdle => this is OperationIdle<T>;

  /// In flight.
  bool get isLoading => this is OperationLoading<T>;

  /// The value, when there is one.
  T? get valueOrNull => switch (this) {
    OperationSuccess<T>(:final T value) => value,
    _ => null,
  };

  /// The failure, when there is one.
  Failure? get failureOrNull => switch (this) {
    OperationFailure<T>(:final Failure failure) => failure,
    _ => null,
  };
}

/// Nothing has been asked for.
final class OperationIdle<T> extends OperationState<T> {
  /// Creates the idle state.
  const OperationIdle();
}

/// A request is in flight.
final class OperationLoading<T> extends OperationState<T> {
  /// Creates the loading state, optionally with progress in `0..1`.
  const OperationLoading({this.progress});

  /// Fraction complete, when the operation reports it.
  final double? progress;
}

/// The request succeeded.
final class OperationSuccess<T> extends OperationState<T> {
  /// Creates the success state.
  const OperationSuccess(this.value);

  /// What came back.
  final T value;
}

/// The request failed, with a reason the user can read.
final class OperationFailure<T> extends OperationState<T> {
  /// Creates the failure state.
  const OperationFailure(this.failure);

  /// Why it failed.
  final Failure failure;
}
