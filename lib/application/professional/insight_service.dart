import 'dart:async';

import 'package:humsukhan/application/common/async_state.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/insight_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// Generates a session summary, as a state machine.
///
/// `generateInsights()` once returned early on five distinct failures with no
/// state change, so failure, in-progress and never-requested all rendered
/// identically (B7). Every path here ends in [AsyncSuccess] or [AsyncFailure].
final class InsightService {
  /// Creates a service over [port].
  InsightService({required InsightPort port}) : _port = port;

  final InsightPort _port;

  final StreamController<AsyncState<Insight>> _states =
      StreamController<AsyncState<Insight>>.broadcast();

  AsyncState<Insight> _state = const AsyncIdle<Insight>();
  int _generation = 0;
  bool _inFlight = false;
  bool _disposed = false;

  /// The state right now.
  AsyncState<Insight> get state => _state;

  /// Every change to [state].
  Stream<AsyncState<Insight>> get states => _states.stream;

  /// Seeds the state with an insight that was already generated and stored.
  void seed(Insight? insight) {
    if (_disposed) return;
    _emit(
      insight == null
          ? const AsyncIdle<Insight>()
          : AsyncSuccess<Insight>(insight),
    );
  }

  /// Summarises [transcript] into [language].
  ///
  /// Returns the outcome and reflects it in [state]; a caller that ignores the
  /// return value still gets a screen that says what happened.
  Future<Result<Insight, InsightFailure>> generate({
    required String transcript,
    required LanguageTag language,
  }) async {
    if (_disposed) {
      return const Err<Insight, InsightFailure>(
        InsightFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_inFlight) {
      return const Err<Insight, InsightFailure>(
        InsightFailure(FailureCode.cancelled, detail: 'already generating'),
      );
    }

    if (transcript.trim().isEmpty) {
      const InsightFailure empty = InsightFailure(
        FailureCode.insightTranscriptEmpty,
        isRecoverable: false,
      );
      _emit(const AsyncFailure<Insight>(empty));
      return const Err<Insight, InsightFailure>(empty);
    }

    // Guard first, await second.
    _inFlight = true;
    final int generation = ++_generation;
    _emit(const AsyncLoading<Insight>());

    final Result<Insight, InsightFailure> result = await _port.summarise(
      transcript: transcript,
      language: language,
    );

    if (_disposed) return result;
    if (generation != _generation) {
      // A newer request took over; this one abandons its work rather than
      // overwriting a fresher state.
      return result;
    }
    _inFlight = false;

    return result.fold(
      (Insight insight) {
        if (insight.isEmpty) {
          const InsightFailure unusable = InsightFailure(
            FailureCode.insightGenerationFailed,
            detail: 'model returned nothing usable',
          );
          _emit(const AsyncFailure<Insight>(unusable));
          return const Err<Insight, InsightFailure>(unusable);
        }
        _emit(AsyncSuccess<Insight>(insight));
        return Ok<Insight, InsightFailure>(insight);
      },
      (InsightFailure failure) {
        _emit(AsyncFailure<Insight>(failure));
        return Err<Insight, InsightFailure>(failure);
      },
    );
  }

  /// Returns to idle, discarding any failure.
  void reset() {
    if (_disposed) return;
    _generation++;
    _inFlight = false;
    _emit(const AsyncIdle<Insight>());
  }

  /// Stops emitting.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }

  void _emit(AsyncState<Insight> next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
