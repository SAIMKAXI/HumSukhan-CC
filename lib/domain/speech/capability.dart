import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// Whether a facility exists for a language.
///
/// Never a bare `bool`: "we have not checked" has to be distinguishable from
/// "checked, absent" (architecture.md §6).
sealed class Capability {
  const Capability();

  /// Whether this is [CapabilityAvailable].
  bool get isAvailable => this is CapabilityAvailable;
}

/// The facility exists and can be used.
final class CapabilityAvailable extends Capability {
  /// Creates an available capability, optionally naming the resolved locale.
  const CapabilityAvailable({this.locale});

  /// The locale the engine actually matched, when it reported one.
  final String? locale;

  @override
  bool operator ==(Object other) =>
      other is CapabilityAvailable && other.locale == locale;

  @override
  int get hashCode => Object.hash(CapabilityAvailable, locale);

  @override
  String toString() => 'CapabilityAvailable($locale)';
}

/// The facility was checked and is not usable.
final class CapabilityUnavailable extends Capability {
  /// Creates an unavailable capability with the [reason] to show the user.
  const CapabilityUnavailable(this.reason);

  /// Why it cannot be used.
  final FailureCode reason;

  @override
  bool operator ==(Object other) =>
      other is CapabilityUnavailable && other.reason == reason;

  @override
  int get hashCode => Object.hash(CapabilityUnavailable, reason);

  @override
  String toString() => 'CapabilityUnavailable(${reason.name})';
}

/// Nothing has been checked yet.
final class CapabilityUnknown extends Capability {
  /// Creates the unknown capability.
  const CapabilityUnknown();

  @override
  bool operator ==(Object other) => other is CapabilityUnknown;

  @override
  int get hashCode => (CapabilityUnknown).hashCode;

  @override
  String toString() => 'CapabilityUnknown()';
}

/// What the platform speech engine reports about itself.
///
/// Narrow on purpose: answering a capability question must never require the
/// ability to speak, so the probe cannot make a sound even by accident (B5).
abstract interface class VoiceCataloguePort {
  /// The locales the engine has voices for, lower-cased. Empty means the engine
  /// could not be asked — which is not the same as having no voices.
  Future<Set<String>> availableLocales();

  /// Identifies the engine, so a cached answer expires when the user installs
  /// a different one.
  Future<String> engineId();

  /// Whether the engine has a voice for [language].
  Future<bool> supports(LanguageTag language);
}

/// Asks what this device can do, per language.
///
/// Probes must be **silent by construction**: an implementation mutes the engine
/// before probing and never produces user-perceivable output (B5).
abstract interface class SpeechCapabilityPort {
  /// Whether speech can be recognised in [language].
  Future<Capability> stt(LanguageTag language);

  /// Whether speech can be synthesised in [language]. Silent probe only.
  Future<Capability> tts(LanguageTag language);

  /// Discards cached results so the next call re-probes.
  ///
  /// Called when the app resumes: a device that gains an Urdu voice must be able
  /// to discover it (B9).
  Future<void> invalidate();
}

/// What the platform *recogniser* reports about itself.
///
/// The synthesis twin of this is [VoiceCataloguePort]. They are separate ports
/// because the two engines are separate on every platform: a device can caption
/// Urdu and be unable to speak it, and the user must be told which one is
/// missing rather than a single blurred "speech unavailable".
abstract interface class RecognitionCataloguePort {
  /// Whether a recogniser exists on this device at all.
  Future<bool> isAvailable();

  /// The locales the recogniser has models for, lower-cased. Empty means the
  /// engine could not be asked, which is not the same as having no models.
  Future<Set<String>> availableLocales();

  /// Whether recognition can run without a network connection for [language].
  ///
  /// Answering false is not a failure — it means captions will need the
  /// network, which the user is entitled to know before a lecture starts.
  Future<bool> supportsOffline(LanguageTag language);
}
