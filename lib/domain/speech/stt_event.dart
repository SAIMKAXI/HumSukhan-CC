import 'package:humsukhan/domain/speech/speech_failure.dart';

/// Why a recognition stream ended.
enum SttEndReason {
  /// The caller asked it to stop.
  stoppedByUser,

  /// The service closed the stream normally (for example, a session limit).
  closedByService,

  /// The audio source ended.
  audioEnded,
}

/// One event from an [SttPort]'s stream.
///
/// [SttEnded] and [SttFailed] are mandatory members: the dead-session bug (B4)
/// existed because the old stream had no way to say "I stopped".
sealed class SttEvent {
  const SttEvent();
}

/// Text recognised so far, subject to change.
final class SttPartial extends SttEvent {
  /// Creates a partial result.
  const SttPartial(this.text);

  /// The unstable text.
  final String text;

  @override
  bool operator ==(Object other) => other is SttPartial && other.text == text;

  @override
  int get hashCode => Object.hash(SttPartial, text);

  @override
  String toString() => 'SttPartial("$text")';
}

/// Text the recogniser will not revise.
final class SttFinal extends SttEvent {
  /// Creates a final result.
  const SttFinal(this.text, {this.confidence});

  /// The settled text.
  final String text;

  /// Recogniser confidence in `0..1`, when the service reports one.
  final double? confidence;

  @override
  bool operator ==(Object other) =>
      other is SttFinal && other.text == text && other.confidence == confidence;

  @override
  int get hashCode => Object.hash(SttFinal, text, confidence);

  @override
  String toString() => 'SttFinal("$text")';
}

/// The stream stopped for an ordinary reason.
final class SttEnded extends SttEvent {
  /// Creates an end event.
  const SttEnded(this.reason);

  /// Why it stopped.
  final SttEndReason reason;

  @override
  bool operator ==(Object other) => other is SttEnded && other.reason == reason;

  @override
  int get hashCode => Object.hash(SttEnded, reason);

  @override
  String toString() => 'SttEnded(${reason.name})';
}

/// The stream stopped because something went wrong.
final class SttFailed extends SttEvent {
  /// Creates a failure event.
  const SttFailed(this.cause);

  /// What went wrong, including whether a retry is worthwhile.
  final SttFailure cause;

  @override
  bool operator ==(Object other) => other is SttFailed && other.cause == cause;

  @override
  int get hashCode => Object.hash(SttFailed, cause);

  @override
  String toString() => 'SttFailed($cause)';
}

/// The transport is down and the adapter is trying to restore it.
///
/// A first-class event, so a long Professional session can render "reconnecting"
/// instead of silently streaming into a dead socket.
final class SttReconnecting extends SttEvent {
  /// Creates a reconnection notice for [attempt] (1-based).
  const SttReconnecting(this.attempt);

  /// Which attempt this is.
  final int attempt;

  @override
  bool operator ==(Object other) =>
      other is SttReconnecting && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(SttReconnecting, attempt);

  @override
  String toString() => 'SttReconnecting($attempt)';
}

/// The transport came back and recognition has resumed.
final class SttReconnected extends SttEvent {
  /// Creates a resumed notice.
  const SttReconnected();

  @override
  bool operator ==(Object other) => other is SttReconnected;

  @override
  int get hashCode => (SttReconnected).hashCode;

  @override
  String toString() => 'SttReconnected()';
}
