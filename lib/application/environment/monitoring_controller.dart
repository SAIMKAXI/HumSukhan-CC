import 'dart:async';

import 'package:humsukhan/application/common/clock.dart';
import 'package:humsukhan/application/common/id_generator.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/alert_presenter_port.dart';
import 'package:humsukhan/domain/environment/detection_policy.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';

/// What environmental monitoring is doing.
enum MonitoringPhase {
  /// Off.
  off,

  /// Preparing the model and the microphone.
  starting,

  /// Listening.
  active,

  /// Stopped because something went wrong. Carries the reason and a remedy.
  failed,
}

/// What the Alerts screen renders.
final class MonitoringState {
  /// Creates a monitoring state.
  const MonitoringState({
    this.phase = MonitoringPhase.off,
    this.model = const ModelAbsent(),
    this.events = const <SoundEvent>[],
    this.failure,
  });

  /// Whether monitoring is on, starting, off, or broken.
  final MonitoringPhase phase;

  /// Where the on-device model is in its lifecycle.
  final ModelState model;

  /// Alert history, newest first.
  final List<SoundEvent> events;

  /// Why monitoring stopped, when [phase] is [MonitoringPhase.failed].
  final Failure? failure;

  /// Whether the microphone is open.
  bool get isRunning =>
      phase == MonitoringPhase.starting || phase == MonitoringPhase.active;

  /// A copy with the given fields replaced.
  MonitoringState copyWith({
    MonitoringPhase? phase,
    ModelState? model,
    List<SoundEvent>? events,
    Failure? failure,
    bool clearFailure = false,
  }) => MonitoringState(
    phase: phase ?? this.phase,
    model: model ?? this.model,
    events: events ?? this.events,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Turns detector observations into confirmed, alerted sound events.
///
/// Owns the model lifecycle, the detector subscription, and the decision to
/// alert. Audio never leaves the device: this class only ever sees
/// [SoundObservation]s.
final class MonitoringController {
  /// Creates a controller.
  MonitoringController({
    required SoundDetectorPort detector,
    required ModelRepositoryPort models,
    required AlertPresenterPort presenter,
    required IdGenerator ids,
    required Clock clock,
    DetectionPolicy policy = const DetectionPolicy(),
    AppLogger logger = const SilentLogger(),
    int historyLimit = 100,
  }) : _detector = detector,
       _models = models,
       _presenter = presenter,
       _ids = ids,
       _clock = clock,
       _policy = policy,
       _logger = logger,
       _historyLimit = historyLimit;

  final SoundDetectorPort _detector;
  final ModelRepositoryPort _models;
  final AlertPresenterPort _presenter;
  final IdGenerator _ids;
  final Clock _clock;
  final DetectionPolicy _policy;
  final AppLogger _logger;
  final int _historyLimit;

  final StreamController<MonitoringState> _states =
      StreamController<MonitoringState>.broadcast();
  final List<SoundObservation> _recent = <SoundObservation>[];
  final Map<SoundKind, DateTime> _lastAlerted = <SoundKind, DateTime>{};

  MonitoringState _state = const MonitoringState();
  StreamSubscription<SoundObservation>? _observations;
  StreamSubscription<DetectorFailure>? _detectorFailures;
  StreamSubscription<ModelState>? _modelStates;
  AlertChannels _channels = const AlertChannels();
  bool _startInFlight = false;
  bool _disposed = false;
  int _generation = 0;

  /// The state right now.
  MonitoringState get state => _state;

  /// Every change to [state].
  Stream<MonitoringState> get states => _states.stream;

  /// Sets which channels alerts use.
  void setChannels(AlertChannels channels) {
    _channels = channels;
  }

  /// Turns monitoring on.
  ///
  /// Ensures the model is genuinely loadable first — "ready" means loaded, not
  /// present (B6) — and reports exactly why it could not start otherwise.
  Future<Result<Unit, Failure>> start() async {
    if (_disposed) {
      return const Err<Unit, Failure>(
        DetectorFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_startInFlight || _state.isRunning) {
      return const Ok<Unit, Failure>(unit);
    }

    // Guard synchronously, before the first await.
    _startInFlight = true;
    final int generation = ++_generation;
    _emit(_state.copyWith(phase: MonitoringPhase.starting, clearFailure: true));

    final Result<Unit, Failure> outcome = await _startInternal(generation);
    if (generation == _generation) _startInFlight = false;
    return outcome;
  }

  Future<Result<Unit, Failure>> _startInternal(int generation) async {
    _modelStates ??= _models.state.listen(
      (ModelState model) {
        if (_disposed) return;
        _emit(_state.copyWith(model: model));
      },
      onError: (Object error, StackTrace stackTrace) => _logger.log(
        LogLevel.warning,
        'monitoring',
        'model state stream error',
        error: error,
        stackTrace: stackTrace,
      ),
    );

    final ModelState model = await _models.ensureReady();
    if (_superseded(generation)) return const Ok<Unit, Failure>(unit);
    _emit(_state.copyWith(model: model));

    if (model is ModelFailed) {
      _fail(model.cause);
      return Err<Unit, Failure>(model.cause);
    }
    if (model is! ModelReady) {
      const ModelFailure notReady = ModelFailure(FailureCode.modelAbsent);
      _fail(notReady);
      return const Err<Unit, Failure>(notReady);
    }

    await _observations?.cancel();
    await _detectorFailures?.cancel();
    if (_superseded(generation)) return const Ok<Unit, Failure>(unit);

    _observations = _detector.observations.listen(
      _onObservation,
      onError: (Object error, StackTrace stackTrace) => _fail(
        DetectorFailure(FailureCode.detectorStartFailed, detail: '$error'),
      ),
      onDone: _onDetectorDone,
    );
    _detectorFailures = _detector.failures.listen(
      _fail,
      onError: (Object error, StackTrace stackTrace) => _fail(
        DetectorFailure(FailureCode.detectorStartFailed, detail: '$error'),
      ),
    );

    final Result<Unit, DetectorFailure> started = await _detector.start();
    if (_superseded(generation)) return const Ok<Unit, Failure>(unit);

    return started.fold(
      (Unit _) {
        _emit(
          _state.copyWith(phase: MonitoringPhase.active, clearFailure: true),
        );
        return const Ok<Unit, Failure>(unit);
      },
      (DetectorFailure failure) {
        _fail(failure);
        return Err<Unit, Failure>(failure);
      },
    );
  }

  /// Turns monitoring off.
  Future<void> stop() async {
    if (_disposed) return;
    _generation++;
    _startInFlight = false;
    await _detector.stop();
    if (_disposed) return;
    _emit(_state.copyWith(phase: MonitoringPhase.off, clearFailure: true));
  }

  /// Marks [event] as seen.
  void acknowledge(SoundEvent event) {
    if (_disposed) return;
    _emit(
      _state.copyWith(
        events: _state.events
            .map((SoundEvent e) => e.id == event.id ? e.acknowledge() : e)
            .toList(growable: false),
      ),
    );
  }

  /// Empties the alert history.
  void clearHistory() {
    if (_disposed) return;
    _emit(_state.copyWith(events: const <SoundEvent>[]));
  }

  /// Discards the current failure so the toggle is usable again.
  void acknowledgeFailure() {
    if (_disposed || _state.failure == null) return;
    _emit(_state.copyWith(clearFailure: true, phase: MonitoringPhase.off));
  }

  /// Releases the detector and the model.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _observations?.cancel();
    await _detectorFailures?.cancel();
    await _modelStates?.cancel();
    await _states.close();
  }

  bool _superseded(int generation) => _disposed || generation != _generation;

  void _onObservation(SoundObservation observation) {
    if (_disposed) return;

    final bool alert = _policy.shouldAlert(
      observation: observation,
      history: _recent,
      lastAlertedAt: _lastAlerted[observation.kind],
    );

    _recent.add(observation);
    // Keep only what the confirmation window could still need.
    _recent.removeWhere(
      (SoundObservation o) =>
          observation.at.difference(o.at) > _policy.confirmationWindow,
    );

    if (!alert) return;

    _lastAlerted[observation.kind] = observation.at;
    final SoundEvent event = SoundEvent(
      id: _ids.next(),
      kind: observation.kind,
      confidence: observation.confidence,
      detectedAt: _clock.now(),
    );
    _emit(
      _state.copyWith(
        events: <SoundEvent>[event, ..._state.events.take(_historyLimit - 1)],
      ),
    );
    unawaited(_present(event));
  }

  Future<void> _present(SoundEvent event) async {
    try {
      await _presenter.present(event, _channels);
    } on Object catch (error, stackTrace) {
      // An alert channel failing must not take monitoring down with it, but it
      // is never swallowed silently either.
      _logger.log(
        LogLevel.error,
        'monitoring',
        'alert presentation failed for ${event.kind.name}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onDetectorDone() {
    if (_disposed || !_state.isRunning) return;
    _fail(
      const DetectorFailure(
        FailureCode.detectorStartFailed,
        detail: 'detector stream closed while monitoring',
      ),
    );
  }

  void _fail(Failure failure) {
    if (_disposed) return;
    _logger.log(LogLevel.warning, 'monitoring', 'monitoring failed: $failure');
    _startInFlight = false;
    _emit(_state.copyWith(phase: MonitoringPhase.failed, failure: failure));
  }

  void _emit(MonitoringState next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
