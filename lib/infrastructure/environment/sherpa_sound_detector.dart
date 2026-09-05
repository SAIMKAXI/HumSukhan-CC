import 'dart:async';
import 'dart:typed_data';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/detection_policy.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/infrastructure/audio/microphone_source.dart';
import 'package:humsukhan/infrastructure/environment/audio_tagging_map.dart';
import 'package:humsukhan/infrastructure/environment/window_buffer.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Classifies one window of audio. Injected so the pipeline — gating, framing,
/// index mapping — is testable without the native model.
abstract interface class AudioTagger {
  /// Loads the model. Returns false when the artefact will not load.
  Future<bool> load({required String modelPath, required String labelsPath});

  /// The most likely events for [samples] at [sampleRate].
  List<TaggedEvent> classify(Float32List samples, int sampleRate);

  /// Releases native resources.
  void release();
}

/// One classifier output.
final class TaggedEvent {
  /// Creates a tagged event.
  const TaggedEvent({required this.index, required this.probability});

  /// The AudioSet class index.
  final int index;

  /// Model confidence in `0..1`.
  final double probability;
}

/// [AudioTagger] backed by sherpa-onnx CED-Tiny INT8.
final class SherpaAudioTagger implements AudioTagger {
  /// Creates a tagger.
  SherpaAudioTagger({AppLogger logger = const SilentLogger()})
    : _logger = logger;

  final AppLogger _logger;
  sherpa.AudioTagging? _tagger;

  @override
  Future<bool> load({
    required String modelPath,
    required String labelsPath,
  }) async {
    release();
    try {
      sherpa.initBindings();
      _tagger = sherpa.AudioTagging(
        config: sherpa.AudioTaggingConfig(
          model: sherpa.AudioTaggingModelConfig(ced: modelPath, debug: false),
          labels: labelsPath,
        ),
      );
      return true;
    } on Object catch (error, stackTrace) {
      // A load failure is the only truthful definition of "not ready" (B6).
      _logger.log(
        LogLevel.error,
        'tagger',
        'the model would not load',
        error: error,
        stackTrace: stackTrace,
      );
      _tagger = null;
      return false;
    }
  }

  @override
  List<TaggedEvent> classify(Float32List samples, int sampleRate) {
    final sherpa.AudioTagging? tagger = _tagger;
    if (tagger == null) return const <TaggedEvent>[];
    sherpa.OfflineStream? stream;
    try {
      stream = tagger.createStream()
        ..acceptWaveform(samples: samples, sampleRate: sampleRate);
      return tagger
          .compute(stream: stream, topK: 5)
          .map(
            (sherpa.AudioEvent e) =>
                TaggedEvent(index: e.index, probability: e.prob),
          )
          .toList(growable: false);
    } on Object catch (error) {
      _logger.log(LogLevel.warning, 'tagger', 'classify failed', error: error);
      return const <TaggedEvent>[];
    } finally {
      stream?.free();
    }
  }

  @override
  void release() {
    _tagger?.free();
    _tagger = null;
  }
}

/// The on-device detection pipeline.
///
/// microphone → 16 kHz mono PCM16 → RMS gate → 3 s window / 1 s hop →
/// CED-Tiny INT8 → observations. Nothing leaves the device: this class produces
/// [SoundObservation]s and never audio.
final class SherpaSoundDetector implements SoundDetectorPort {
  /// Creates a detector.
  SherpaSoundDetector({
    required MicrophoneSource microphone,
    required ModelRepositoryPort models,
    required AudioTagger tagger,
    WindowBuffer? buffer,
    AppLogger logger = const SilentLogger(),
    DateTime Function()? now,
  }) : _microphone = microphone,
       _models = models,
       _tagger = tagger,
       _buffer = buffer ?? WindowBuffer(),
       _logger = logger,
       _now = now ?? DateTime.now;

  final MicrophoneSource _microphone;
  final ModelRepositoryPort _models;
  final AudioTagger _tagger;
  final WindowBuffer _buffer;
  final AppLogger _logger;
  final DateTime Function() _now;

  final StreamController<SoundObservation> _observations =
      StreamController<SoundObservation>.broadcast();
  final StreamController<DetectorFailure> _failures =
      StreamController<DetectorFailure>.broadcast();

  StreamSubscription<Uint8List>? _audio;
  bool _running = false;
  bool _loaded = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  Stream<SoundObservation> get observations => _observations.stream;

  @override
  Stream<DetectorFailure> get failures => _failures.stream;

  @override
  Future<Result<Unit, DetectorFailure>> start() async {
    if (_disposed) {
      return const Err<Unit, DetectorFailure>(
        DetectorFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_running) return const Ok<Unit, DetectorFailure>(unit);

    // Guard before the first await.
    _running = true;
    final int generation = ++_generation;

    final ModelState model = await _models.ensureReady();
    if (_superseded(generation)) return const Ok<Unit, DetectorFailure>(unit);

    if (model is! ModelReady) {
      _running = false;
      final FailureCode code = model is ModelFailed
          ? model.cause.code
          : FailureCode.modelAbsent;
      return Err<Unit, DetectorFailure>(DetectorFailure(code));
    }

    if (!_loaded) {
      _loaded = await _tagger.load(
        modelPath: model.path,
        labelsPath: model.path.replaceFirst(
          RegExp(r'[^/]+$'),
          'ced-tiny-labels.csv',
        ),
      );
      if (!_loaded) {
        _running = false;
        // An artefact that will not load is quarantined, so the next attempt
        // reinstalls it rather than failing the same way forever.
        await _models.quarantine();
        return const Err<Unit, DetectorFailure>(
          DetectorFailure(FailureCode.modelLoadFailed),
        );
      }
    }

    final Result<Stream<Uint8List>, AudioFailure> audio = await _microphone
        .start();
    if (_superseded(generation)) return const Ok<Unit, DetectorFailure>(unit);

    if (audio case Err<Stream<Uint8List>, AudioFailure>(
      :final AudioFailure error,
    )) {
      _running = false;
      return Err<Unit, DetectorFailure>(
        DetectorFailure(
          error.code,
          detail: error.detail,
          isRecoverable: error.isRecoverable,
        ),
      );
    }

    _buffer.reset();
    _audio = (audio as Ok<Stream<Uint8List>, AudioFailure>).value.listen(
      _onAudio,
      onError: (Object error, StackTrace stackTrace) {
        _logger.log(
          LogLevel.error,
          'detector',
          'audio stream error',
          error: error,
          stackTrace: stackTrace,
        );
        _emitFailure(
          DetectorFailure(FailureCode.microphoneUnavailable, detail: '$error'),
        );
      },
      // Never empty: a monitor that dies has to say so, or the user is left
      // believing they are protected.
      onDone: () {
        if (!_running) return;
        _emitFailure(
          const DetectorFailure(
            FailureCode.microphoneUnavailable,
            detail: 'the audio stream ended while monitoring',
          ),
        );
      },
    );

    return const Ok<Unit, DetectorFailure>(unit);
  }

  @override
  Future<void> stop() async {
    if (_disposed || !_running) return;
    _running = false;
    _generation++;
    await _audio?.cancel();
    _audio = null;
    _buffer.reset();
    await _microphone.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    _tagger.release();
    _loaded = false;
    await _observations.close();
    await _failures.close();
  }

  bool _superseded(int generation) => _disposed || generation != _generation;

  void _onAudio(Uint8List chunk) {
    if (!_running || _disposed) return;
    for (final Float32List window in _buffer.add(chunk)) {
      for (final TaggedEvent event in _tagger.classify(
        window,
        _buffer.sampleRate,
      )) {
        final SoundKind? kind = AudioTaggingMap.byIndex[event.index];
        if (kind == null) continue;
        if (_observations.isClosed) return;
        _observations.add(
          SoundObservation(
            kind: kind,
            confidence: event.probability,
            at: _now(),
          ),
        );
      }
    }
  }

  void _emitFailure(DetectorFailure failure) {
    _running = false;
    if (!_failures.isClosed) _failures.add(failure);
  }
}
