import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/utterance.dart';

/// What the synthesiser is doing right now.
enum TtsActivity {
  /// Not speaking.
  idle,

  /// Preparing to speak (resolving a voice, fetching audio).
  preparing,

  /// Audible.
  speaking,
}

/// Text to speech.
abstract interface class TtsPort {
  /// Changes in what the synthesiser is doing.
  ///
  /// Consumers render this; the button label is never a local boolean guess.
  Stream<TtsActivity> get activity;

  /// Speaks [utterance].
  ///
  /// Completes when speech finishes or fails. Never throws: a failure the call
  /// site cannot see is a failure the user cannot see (B8).
  Future<Result<Unit, TtsFailure>> speak(Utterance utterance);

  /// Stops any speech in progress.
  Future<void> stop();

  /// Releases the engine.
  Future<void> dispose();
}
