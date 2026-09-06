/// Identifies a failure independently of the language it is shown in.
///
/// Failure text has to exist in English *and* Urdu (docs/instructions.md §3),
/// so a failure carries a code and the presentation layer resolves the copy.
/// The English strings on [Failure] are the log/test rendering and the last
/// resort if a code is ever shown before localisation is available.
enum FailureCode {
  /// Cause could not be classified. Always carries a [Failure.detail].
  unknown,

  // Connectivity.
  /// The device has no usable network connection.
  offline,

  /// A network call failed in transit.
  network,

  /// A network call exceeded its deadline.
  timeout,

  /// The app cannot reach its own server at all.
  backendUnavailable,

  // Permissions and hardware.
  /// The user declined the microphone permission.
  microphonePermissionDenied,

  /// The microphone permission was permanently denied; only Settings can grant.
  microphonePermissionPermanentlyDenied,

  /// The microphone could not be opened (in use, or no input device).
  microphoneUnavailable,

  /// Notification permission is required for the monitoring service.
  notificationPermissionDenied,

  // Speech to text.
  /// No recogniser supports the requested language on this device.
  sttLanguageUnsupported,

  /// The recogniser could not be started.
  sttStartFailed,

  /// The recogniser transport dropped and could not be re-established.
  sttTransportLost,

  /// The server refused to mint a recognition token.
  sttAuthFailed,

  // Text to speech.
  /// No speech engine is available at all.
  ttsUnavailable,

  /// The engine exists but has no voice for the requested language.
  ttsVoiceMissing,

  /// Synthesis started and then failed.
  ttsFailed,

  // Account.
  /// Email or password did not match.
  authInvalidCredentials,

  /// The email is already registered.
  authEmailInUse,

  /// The password does not meet the minimum policy.
  authWeakPassword,

  /// The email address is not a valid address.
  authInvalidEmail,

  /// Too many attempts in a short window.
  authRateLimited,

  /// The operation needs a signed-in user and there is none.
  authNoSession,

  // Storage.
  /// Reading local or remote data failed.
  storageReadFailed,

  /// Writing local or remote data failed.
  storageWriteFailed,

  // Insights.
  /// There is no transcript to summarise.
  insightTranscriptEmpty,

  /// The summariser returned an error or unusable output.
  insightGenerationFailed,

  // On-device model.
  /// The model is not installed.
  modelAbsent,

  /// The downloaded artefact failed size or checksum verification.
  modelCorrupt,

  /// The artefact exists but the tagger refused to load it.
  modelLoadFailed,

  /// The model download itself failed.
  modelDownloadFailed,

  // Environmental monitoring.
  /// The detector could not be started.
  detectorStartFailed,

  /// The foreground service could not be started.
  serviceStartFailed,

  // Input.
  /// The caller supplied something the domain rejects.
  invalidInput,

  /// The operation was superseded or cancelled by the user.
  cancelled,
}

/// English copy for every [FailureCode]. Urdu lives in the l10n layer; this map
/// is the developer-facing rendering and the ultimate fallback.
const Map<FailureCode, String> _messages = <FailureCode, String>{
  FailureCode.unknown: 'Something went wrong.',
  FailureCode.offline: 'You are offline.',
  FailureCode.network: 'The network request failed.',
  FailureCode.timeout: 'The request took too long.',
  FailureCode.backendUnavailable: 'HumSukhan cannot reach its server.',
  FailureCode.microphonePermissionDenied: 'Microphone access was declined.',
  FailureCode.microphonePermissionPermanentlyDenied:
      'Microphone access is blocked for this app.',
  FailureCode.microphoneUnavailable: 'The microphone could not be opened.',
  FailureCode.notificationPermissionDenied: 'Notifications are turned off.',
  FailureCode.sttLanguageUnsupported:
      'This device cannot recognise the selected language.',
  FailureCode.sttStartFailed: 'Recognition could not start.',
  FailureCode.sttTransportLost: 'The connection to the recogniser was lost.',
  FailureCode.sttAuthFailed: 'The recognition service refused the request.',
  FailureCode.ttsUnavailable: 'No speech engine is available on this device.',
  FailureCode.ttsVoiceMissing: 'No voice is installed for this language.',
  FailureCode.ttsFailed: 'Speaking failed.',
  FailureCode.authInvalidCredentials: 'That email and password do not match.',
  FailureCode.authEmailInUse: 'An account already uses that email.',
  FailureCode.authWeakPassword: 'That password is too short.',
  FailureCode.authInvalidEmail: 'That is not a valid email address.',
  FailureCode.authRateLimited: 'Too many attempts. Wait a moment.',
  FailureCode.authNoSession: 'You are signed out.',
  FailureCode.storageReadFailed: 'Your data could not be loaded.',
  FailureCode.storageWriteFailed: 'Your data could not be saved.',
  FailureCode.insightTranscriptEmpty: 'There is nothing to summarise yet.',
  FailureCode.insightGenerationFailed: 'The summary could not be generated.',
  FailureCode.modelAbsent: 'The sound model is not installed.',
  FailureCode.modelCorrupt: 'The sound model file is damaged.',
  FailureCode.modelLoadFailed: 'The sound model could not be loaded.',
  FailureCode.modelDownloadFailed: 'The sound model could not be downloaded.',
  FailureCode.detectorStartFailed: 'Sound detection could not start.',
  FailureCode.serviceStartFailed: 'Background monitoring could not start.',
  FailureCode.invalidInput: 'That value cannot be used.',
  FailureCode.cancelled: 'That was cancelled.',
};

/// English remedies. A failure without a remedy is a failure the user can do
/// nothing about — say so by omission rather than by inventing advice.
const Map<FailureCode, String> _remedies = <FailureCode, String>{
  FailureCode.offline: 'Reconnect to Wi-Fi or mobile data, then try again.',
  FailureCode.network: 'Check your connection and try again.',
  FailureCode.timeout: 'Try again.',
  FailureCode.backendUnavailable:
      'Check your connection and try again. If this keeps happening, '
      'reinstall the app.',
  FailureCode.microphonePermissionDenied:
      'Allow microphone access to continue.',
  FailureCode.microphonePermissionPermanentlyDenied:
      'Open system settings and allow the microphone for HumSukhan.',
  FailureCode.microphoneUnavailable:
      'Close other apps that may be using the microphone, then try again.',
  FailureCode.notificationPermissionDenied:
      'Allow notifications so monitoring can keep running.',
  // No "open settings and find the language list". HumSukhan offers the
  // download itself; the remedy only has to say that a tap is coming.
  FailureCode.sttLanguageUnsupported:
      'HumSukhan can download this language for you.',
  FailureCode.sttStartFailed: 'Try starting again.',
  FailureCode.sttTransportLost: 'Check your connection and start again.',
  FailureCode.sttAuthFailed: 'Sign out and sign in again, then retry.',
  FailureCode.ttsUnavailable:
      'This phone has no voice to speak with. Captions still work.',
  FailureCode.ttsVoiceMissing: 'HumSukhan can download this voice for you.',
  FailureCode.ttsFailed: 'Try again.',
  FailureCode.authInvalidCredentials:
      'Check the email and password, or reset it.',
  FailureCode.authEmailInUse: 'Sign in instead, or reset the password.',
  FailureCode.authWeakPassword: 'Use at least 8 characters.',
  FailureCode.authInvalidEmail: 'Enter an address like name@example.com.',
  FailureCode.authRateLimited: 'Wait a minute, then try again.',
  FailureCode.authNoSession: 'Sign in to continue.',
  FailureCode.storageWriteFailed: 'Try again.',
  FailureCode.storageReadFailed: 'Try again.',
  FailureCode.insightTranscriptEmpty: 'Record something first.',
  FailureCode.insightGenerationFailed: 'Try generating the summary again.',
  FailureCode.modelAbsent: 'Download the sound model in Settings.',
  FailureCode.modelCorrupt: 'Download it again from Settings.',
  FailureCode.modelLoadFailed: 'Download it again from Settings.',
  FailureCode.modelDownloadFailed: 'Check your connection and try again.',
  FailureCode.detectorStartFailed: 'Turn monitoring off and on again.',
  FailureCode.serviceStartFailed:
      'Allow notifications, then turn monitoring on.',
};

/// Base of every failure in the app.
///
/// A failure always says what happened ([message]), what the user can do about
/// it ([remedy], when there is anything), and whether retrying is meaningful
/// ([isRecoverable]).
abstract base class Failure {
  /// Creates a failure for [code].
  const Failure({required this.code, this.detail, this.isRecoverable = true});

  /// What kind of failure this is. Drives localisation.
  final FailureCode code;

  /// Developer-facing context: an exception string, a status code, a locale.
  /// Never rendered as the whole message — it is not localised.
  final String? detail;

  /// Whether the same operation could plausibly succeed on a retry.
  final bool isRecoverable;

  /// English description of what happened.
  String get message => _messages[code] ?? _messages[FailureCode.unknown]!;

  /// English description of what the user can do, when there is something.
  String? get remedy => _remedies[code];

  @override
  bool operator ==(Object other) =>
      other is Failure &&
      other.runtimeType == runtimeType &&
      other.code == code &&
      other.detail == detail &&
      other.isRecoverable == isRecoverable;

  @override
  int get hashCode => Object.hash(runtimeType, code, detail, isRecoverable);

  @override
  String toString() =>
      '$runtimeType(${code.name}${detail == null ? '' : ', $detail'})';
}
