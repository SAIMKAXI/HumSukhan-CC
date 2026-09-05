import 'dart:async';

import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/core/id/id_generator.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';
import 'package:humsukhan/domain/speech/utterance.dart';

/// A recogniser under the test's control.
///
/// The whole speech stack is exercised through this: no device, no network.
final class FakeSttPort implements SttPort {
  /// Creates a fake recogniser.
  FakeSttPort();

  final StreamController<SttEvent> _events =
      StreamController<SttEvent>.broadcast();

  /// Every request [start] was called with, in order.
  final List<SttRequest> startRequests = <SttRequest>[];

  /// How many times [stop] was called.
  int stopCount = 0;

  /// How many times [dispose] was called.
  int disposeCount = 0;

  /// When set, [start] fails with this instead of succeeding.
  SttFailure? failOnStart;

  /// How long [start] takes to complete. Lets a test supersede a slow start.
  Duration startDelay = Duration.zero;

  /// Whether recognition is running.
  bool get isRunning => startRequests.length > stopCount;

  @override
  Stream<SttEvent> get events => _events.stream;

  @override
  Future<Result<Unit, SttFailure>> start(SttRequest request) async {
    startRequests.add(request);
    if (startDelay > Duration.zero) await Future<void>.delayed(startDelay);
    final SttFailure? failure = failOnStart;
    if (failure != null) return Err<Unit, SttFailure>(failure);
    return const Ok<Unit, SttFailure>(unit);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _events.close();
  }

  /// Emits [event] to whoever is listening.
  void emit(SttEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Emits an unstable result.
  void partial(String text) => emit(SttPartial(text));

  /// Emits a settled result.
  void finalResult(String text) => emit(SttFinal(text));

  /// Pushes a raw error onto the stream, as a transport would.
  void emitStreamError(Object error) {
    if (!_events.isClosed) _events.addError(error);
  }

  /// Closes the stream with no terminal event at all — the shape of the bug
  /// that left the UI reading "Listening…" forever (B4).
  Future<void> closeSilently() => _events.close();
}

/// A synthesiser under the test's control.
final class FakeTtsPort implements TtsPort {
  /// Creates a fake synthesiser.
  FakeTtsPort();

  final StreamController<TtsActivity> _activity =
      StreamController<TtsActivity>.broadcast();

  /// Everything [speak] was asked to say.
  final List<Utterance> spoken = <Utterance>[];

  /// How many times [stop] was called.
  int stopCount = 0;

  /// When set, [speak] fails with this.
  TtsFailure? failOnSpeak;

  /// How long [speak] takes.
  Duration speakDuration = Duration.zero;

  @override
  Stream<TtsActivity> get activity => _activity.stream;

  @override
  Future<Result<Unit, TtsFailure>> speak(Utterance utterance) async {
    spoken.add(utterance);
    _push(TtsActivity.speaking);
    if (speakDuration > Duration.zero) {
      await Future<void>.delayed(speakDuration);
    }
    _push(TtsActivity.idle);
    final TtsFailure? failure = failOnSpeak;
    if (failure != null) return Err<Unit, TtsFailure>(failure);
    return const Ok<Unit, TtsFailure>(unit);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _push(TtsActivity.idle);
  }

  @override
  Future<void> dispose() async {
    await _activity.close();
  }

  void _push(TtsActivity value) {
    if (!_activity.isClosed) _activity.add(value);
  }
}

/// Capability answers a test dictates.
final class FakeCapabilityPort implements SpeechCapabilityPort {
  /// Creates a fake capability probe.
  FakeCapabilityPort({
    Map<LanguageTag, Capability>? sttAnswers,
    Map<LanguageTag, Capability>? ttsAnswers,
  }) : _stt = sttAnswers ?? <LanguageTag, Capability>{},
       _tts = ttsAnswers ?? <LanguageTag, Capability>{};

  final Map<LanguageTag, Capability> _stt;
  final Map<LanguageTag, Capability> _tts;

  /// How many times the cache was invalidated.
  int invalidateCount = 0;

  @override
  Future<Capability> stt(LanguageTag language) async =>
      _stt[language] ?? const CapabilityAvailable();

  @override
  Future<Capability> tts(LanguageTag language) async =>
      _tts[language] ??
      const CapabilityUnavailable(FailureCode.ttsVoiceMissing);

  @override
  Future<void> invalidate() async {
    invalidateCount++;
  }
}

/// Ids a test can predict.
final class FakeIdGenerator implements IdGenerator {
  /// Creates a generator producing `prefix-1`, `prefix-2`, …
  FakeIdGenerator({this.prefix = 'id'});

  /// What each id starts with.
  final String prefix;

  int _counter = 0;

  @override
  String next() {
    _counter++;
    return '$prefix-$_counter';
  }
}

/// A clock a test moves by hand.
final class FakeClock implements Clock {
  /// Creates a clock reading [start].
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 3, 1, 9);

  DateTime _now;

  /// Moves the clock forward.
  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
