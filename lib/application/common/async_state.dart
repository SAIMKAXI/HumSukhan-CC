import 'package:humsukhan/core/failure/failure.dart';

/// The four states every async surface in the app must be able to express.
///
/// An early `return` that changes no state is forbidden (B7): a command either
/// moves this to [AsyncSuccess] or to [AsyncFailure], never leaves it where it
/// was without a reason.
sealed class AsyncState<T> {
  const AsyncState();

  /// Never requested.
  bool get isIdle => this is AsyncIdle<T>;

  /// In flight.
  bool get isLoading => this is AsyncLoading<T>;

  /// The value, when there is one.
  T? get valueOrNull => switch (this) {
    AsyncSuccess<T>(:final T value) => value,
    _ => null,
  };

  /// The failure, when there is one.
  Failure? get failureOrNull => switch (this) {
    AsyncFailure<T>(:final Failure failure) => failure,
    _ => null,
  };
}

/// Nothing has been asked for.
final class AsyncIdle<T> extends AsyncState<T> {
  /// Creates the idle state.
  const AsyncIdle();
}

/// A request is in flight.
final class AsyncLoading<T> extends AsyncState<T> {
  /// Creates the loading state, optionally with progress in `0..1`.
  const AsyncLoading({this.progress});

  /// Fraction complete, when the operation reports it.
  final double? progress;
}

/// The request succeeded.
final class AsyncSuccess<T> extends AsyncState<T> {
  /// Creates the success state.
  const AsyncSuccess(this.value);

  /// What came back.
  final T value;
}

/// The request failed, with a reason the user can read.
final class AsyncFailure<T> extends AsyncState<T> {
  /// Creates the failure state.
  const AsyncFailure(this.failure);

  /// Why it failed.
  final Failure failure;
}
