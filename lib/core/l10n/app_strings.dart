/// Every user-visible string in the app, in both languages.
///
/// A string added in English is not done (docs/instructions.md §3), so the
/// tables below are checked by `test/core/l10n/app_strings_test.dart`: every
/// [StringKey] must be present and non-empty in both maps.
library;

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';

/// Identifies one piece of user-visible copy.
enum StringKey {
  /// `HumSukhan`
  appName,

  /// `One who speaks with you`
  appTagline,

  /// `OK`
  ok,

  /// `Cancel`
  cancel,

  /// `Save`
  save,

  /// `Delete`
  delete,

  /// `Discard`
  discard,

  /// `Try again`
  retry,

  /// `Close`
  close,

  /// `Back`
  back,

  /// `Next`
  next,

  /// `Done`
  done,

  /// `Continue`
  continueLabel,

  /// `Skip`
  skip,

  /// `Get started`
  getStarted,

  /// `Share`
  share,

  /// `Export`
  export,

  /// `Loading…`
  loading,

  /// `Dismiss`
  dismiss,

  /// `Open system settings`
  openSystemSettings,

  /// `Something went wrong`
  somethingWentWrong,

  /// `Online`
  online,

  /// `Offline`
  offline,

  /// `Remove`
  remove,

  /// `Edit`
  edit,

  /// `Copy`
  copy,

  /// `Copied`
  copied,

  /// `Home`
  navHome,

  /// `Everyday`
  navEveryday,

  /// `Professional`
  navProfessional,

  /// `Alerts`
  navAlerts,

  /// `Settings`
  navSettings,

  /// `Welcome back`
  authSignInTitle,

  /// `Create your account`
  authSignUpTitle,

  /// `Reset your password`
  authForgotTitle,

  /// `Choose a new password`
  authRecoveryTitle,

  /// `Email`
  authEmail,

  /// `Password`
  authPassword,

  /// `New password`
  authNewPassword,

  /// `Your name`
  authName,

  /// `Sign in`
  authSignIn,

  /// `Sign up`
  authSignUp,

  /// `Send reset link`
  authSendResetLink,

  /// `Update password`
  authUpdatePassword,

  /// `No account yet? Sign up`
  authNoAccount,

  /// `Already have an account? Sign in`
  authHaveAccount,

  /// `Forgot your password?`
  authForgotPrompt,

  /// `Check your email for the reset link.`
  authResetSent,

  /// `Your password has been updated.`
  authPasswordUpdated,

  /// `Sign out`
  authSignOut,

  /// `Sign out of HumSukhan?`
  authSignOutConfirm,

  /// `No email verification needed — you can start straight away.`
  authNoVerification,

  /// `Enter your email address.`
  authEmailRequired,

  /// `Enter your password.`
  authPasswordRequired,

  /// `Enter your name.`
  authNameRequired,

  /// `Signed in.`
  authSignedIn,

  /// `Welcome to HumSukhan`
  onboardWelcomeTitle,

  /// `See what people say, reply in your own words, and know about sounds around you.`
  onboardWelcomeBody,

  /// `Everyday conversation`
  onboardEverydayTitle,

  /// `Live captions of the person speaking to you. Reply by typing, or let the app speak for you.`
  onboardEverydayBody,

  /// `Meetings and lectures`
  onboardProfessionalTitle,

  /// `Capture a full transcript, then get a summary with action items you can share.`
  onboardProfessionalBody,

  /// `Sounds you cannot hear`
  onboardEnvironmentTitle,

  /// `A doorbell, a siren, an alarm — HumSukhan taps your phone and shows you what it heard.`
  onboardEnvironmentBody,

  /// `Your audio stays yours`
  onboardPrivacyTitle,

  /// `Sound detection runs entirely on this device. Nothing is uploaded, and captions are kept only as long as you choose.`
  onboardPrivacyBody,

  /// `Hello, {name}`
  homeGreeting,

  /// `Hello`
  homeGreetingAnonymous,

  /// `Recent activity`
  homeRecentActivity,

  /// `Nothing yet. Start a conversation or a session.`
  homeNoActivity,

  /// `Talk to someone`
  homeEverydayCard,

  /// `Live captions and spoken replies`
  homeEverydayCardBody,

  /// `Record a session`
  homeProfessionalCard,

  /// `Full transcript, then a summary`
  homeProfessionalCardBody,

  /// `Listen for sounds`
  homeAlertsCard,

  /// `On-device alerts for important sounds`
  homeAlertsCardBody,

  /// `Everyday`
  everydayTitle,

  /// `Start conversation`
  everydayStart,

  /// `Stop`
  everydayStop,

  /// `Start a conversation, then tap the microphone when the other person begins to speak.`
  everydayIdleHint,

  /// `Speech is sent for recognition only while the microphone is on, and is never stored by the recogniser.`
  everydayPrivacyNotice,

  /// `Start speaker microphone`
  everydayMicStart,

  /// `Stop speaker microphone`
  everydayMicStop,

  /// `Microphone off`
  everydayStatusIdle,

  /// `Starting…`
  everydayStatusStarting,

  /// `Listening`
  everydayStatusListening,

  /// `Pause detected — speak again to continue`
  everydayStatusPaused,

  /// `Connection lost — reconnecting`
  everydayStatusReconnecting,

  /// `Recognition stopped`
  everydayStatusFailed,

  /// `Speaking`
  everydayStatusSpeaking,

  /// `Them`
  everydaySpeakerLabel,

  /// `You`
  everydayYouLabel,

  /// `Type a reply`
  everydayComposerHint,

  /// `Send`
  everydaySend,

  /// `Speak`
  everydaySpeak,

  /// `Speak this caption`
  everydaySpeakThis,

  /// `Stop speaking`
  everydayStopSpeaking,

  /// `Quick replies`
  everydayQuickReplies,

  /// `Pause length`
  everydayPauseThreshold,

  /// `Short · 1.2s`
  pauseShort,

  /// `Natural · 1.7s`
  pauseNatural,

  /// `Patient · 2.5s`
  pausePatient,

  /// `Manual only`
  pauseManual,

  /// `Save this conversation?`
  everydaySaveTitle,

  /// `Saved conversations are kept for as long as your retention setting allows.`
  everydaySaveBody,

  /// `Conversation saved.`
  everydaySaved,

  /// `Conversation deleted.`
  everydayDeleted,

  /// `No captions yet. Tap the microphone when the other person speaks.`
  everydayNoCaptions,

  /// `Turn the microphone off to type or speak.`
  everydayControlsDisabledWhileListening,

  /// `Speaking…`
  everydaySpeaking,

  /// `Yes`
  quickReplyYes,

  /// `No`
  quickReplyNo,

  /// `Thank you`
  quickReplyThanks,

  /// `Could you repeat that?`
  quickReplyRepeat,

  /// `Please speak a little slower`
  quickReplySlower,

  /// `One moment please`
  quickReplyOneMoment,

  /// `Could you write that down?`
  quickReplyWriteItDown,

  /// `Professional`
  proTitle,

  /// `New session`
  proNewSession,

  /// `Session name`
  proSessionName,

  /// `Type`
  proSessionType,

  /// `Meeting`
  proTypeMeeting,

  /// `Lecture`
  proTypeLecture,

  /// `Class`
  proTypeClass,

  /// `Caption language`
  proCaptionLanguage,

  /// `Keep for`
  proRetention,

  /// `Start recording`
  proStartRecording,

  /// `Stop recording`
  proStopRecording,

  /// `Recording`
  proRecording,

  /// `Transcript`
  proTranscript,

  /// `Summary`
  proSummary,

  /// `Actions`
  proActions,

  /// `Overview`
  proOverview,

  /// `Generate summary`
  proGenerateSummary,

  /// `Generating the summary…`
  proSummaryGenerating,

  /// `No summary yet. Generate one from the transcript.`
  proSummaryEmpty,

  /// `No sessions yet. Record a meeting or a lecture.`
  proNoSessions,

  /// `Session saved.`
  proSessionSaved,

  /// `Session discarded.`
  proSessionDiscarded,

  /// `Save this session?`
  proSaveTitle,

  /// `Duration`
  proDuration,

  /// `Expires in {days} days`
  proExpiresInDays,

  /// `Expires tomorrow`
  proExpiresTomorrow,

  /// `Expires today`
  proExpiresToday,

  /// `Expired`
  proExpired,

  /// `Action items`
  proActionItems,

  /// `Deadlines`
  proDeadlines,

  /// `People mentioned`
  proPeople,

  /// `Key points`
  proKeyPoints,

  /// `Nothing was captured in this session.`
  proNoTranscript,

  /// `Only finished sentences are added to the transcript.`
  proInterimHidden,

  /// `Add a note`
  proAddNote,

  /// `{count} words`
  proWordCount,

  /// `{days} days`
  proRetentionDays,

  /// `AI-generated. Check anything important against the transcript.`
  aiDisclaimer,

  /// `Alerts`
  envTitle,

  /// `Sound monitoring`
  envMonitoring,

  /// `Monitoring is off`
  envStateOff,

  /// `Starting monitoring…`
  envStateStarting,

  /// `Listening for important sounds`
  envStateActive,

  /// `Monitoring stopped`
  envStateFailed,

  /// `Sounds HumSukhan listens for`
  envSupportedSounds,

  /// `Recent alerts`
  envHistory,

  /// `No alerts yet.`
  envNoAlerts,

  /// `Audio is classified on this device and is never uploaded.`
  envOnDeviceNotice,

  /// `How you are alerted`
  envAlertChannels,

  /// `Critical`
  envSeverityCritical,

  /// `Important`
  envSeverityHigh,

  /// `Normal`
  envSeverityNormal,

  /// `Siren`
  envSoundSiren,

  /// `Doorbell`
  envSoundDoorbell,

  /// `Alarm`
  envSoundAlarm,

  /// `Baby crying`
  envSoundBabyCry,

  /// `Knock at the door`
  envSoundKnock,

  /// `Breaking glass`
  envSoundGlassBreak,

  /// `Dog barking`
  envSoundDogBark,

  /// `Vehicle horn`
  envSoundVehicleHorn,

  /// `Phone ringing`
  envSoundPhone,

  /// `Sound model ready`
  envModelReady,

  /// `Checking the sound model…`
  envModelChecking,

  /// `Downloading the sound model…`
  envModelDownloading,

  /// `Verifying the sound model…`
  envModelVerifying,

  /// `The sound model is not installed.`
  envModelAbsent,

  /// `Install the sound model`
  envInstallModel,

  /// `Detected at {time}`
  envDetectedAt,

  /// `{percent}% confidence`
  envConfidence,

  /// `Clear alert history`
  envClearHistory,

  /// `Monitoring keeps running while HumSukhan is in the background.`
  envForegroundNotice,

  /// `Settings`
  setTitle,

  /// `Profile`
  setProfile,

  /// `Display name`
  setDisplayName,

  /// `Appearance`
  setAppearance,

  /// `Dark mode`
  setDarkMode,

  /// `High contrast`
  setHighContrast,

  /// `Pure black and white with heavier borders.`
  setHighContrastBody,

  /// `Large text`
  setLargeText,

  /// `Increases text size on top of your system setting.`
  setLargeTextBody,

  /// `Caption size`
  setCaptionSize,

  /// `This is how captions will look.`
  setCaptionPreview,

  /// `Language`
  setLanguage,

  /// `App language`
  setAppLanguage,

  /// `Caption language`
  setCaptionLanguage,

  /// `English`
  setLanguageEnglish,

  /// `Urdu`
  setLanguageUrdu,

  /// `Alerts`
  setAlerts,

  /// `Vibration`
  setHaptic,

  /// `On-screen alert`
  setVisual,

  /// `Camera flash`
  setTorch,

  /// `Screen flash`
  setScreenFlash,

  /// `Keep recordings for`
  setRetention,

  /// `Sessions and conversations are deleted automatically after this many days.`
  setRetentionBody,

  /// `Account`
  setAccount,

  /// `On-device model`
  setOfflineModels,

  /// `About`
  setAbout,

  /// `Version {version}`
  setVersion,

  /// `Saved.`
  setSaved,

  /// `English`
  langEnglish,

  /// `Urdu`
  langUrdu,

  /// `Roman Urdu`
  langRomanUrdu,

  /// `English and Urdu`
  langMixed,

  /// `Not yet detected`
  langUndetermined,

  /// `Loading`
  stateLoadingTitle,

  /// `That did not work`
  stateErrorTitle,

  /// `Nothing here yet`
  stateEmptyTitle,
}

const Map<StringKey, String> _english = <StringKey, String>{
  StringKey.appName: 'HumSukhan',
  StringKey.appTagline: 'One who speaks with you',
  StringKey.ok: 'OK',
  StringKey.cancel: 'Cancel',
  StringKey.save: 'Save',
  StringKey.delete: 'Delete',
  StringKey.discard: 'Discard',
  StringKey.retry: 'Try again',
  StringKey.close: 'Close',
  StringKey.back: 'Back',
  StringKey.next: 'Next',
  StringKey.done: 'Done',
  StringKey.continueLabel: 'Continue',
  StringKey.skip: 'Skip',
  StringKey.getStarted: 'Get started',
  StringKey.share: 'Share',
  StringKey.export: 'Export',
  StringKey.loading: 'Loading…',
  StringKey.dismiss: 'Dismiss',
  StringKey.openSystemSettings: 'Open system settings',
  StringKey.somethingWentWrong: 'Something went wrong',
  StringKey.online: 'Online',
  StringKey.offline: 'Offline',
  StringKey.remove: 'Remove',
  StringKey.edit: 'Edit',
  StringKey.copy: 'Copy',
  StringKey.copied: 'Copied',
  StringKey.navHome: 'Home',
  StringKey.navEveryday: 'Everyday',
  StringKey.navProfessional: 'Professional',
  StringKey.navAlerts: 'Alerts',
  StringKey.navSettings: 'Settings',
  StringKey.authSignInTitle: 'Welcome back',
  StringKey.authSignUpTitle: 'Create your account',
  StringKey.authForgotTitle: 'Reset your password',
  StringKey.authRecoveryTitle: 'Choose a new password',
  StringKey.authEmail: 'Email',
  StringKey.authPassword: 'Password',
  StringKey.authNewPassword: 'New password',
  StringKey.authName: 'Your name',
  StringKey.authSignIn: 'Sign in',
  StringKey.authSignUp: 'Sign up',
  StringKey.authSendResetLink: 'Send reset link',
  StringKey.authUpdatePassword: 'Update password',
  StringKey.authNoAccount: 'No account yet? Sign up',
  StringKey.authHaveAccount: 'Already have an account? Sign in',
  StringKey.authForgotPrompt: 'Forgot your password?',
  StringKey.authResetSent: 'Check your email for the reset link.',
  StringKey.authPasswordUpdated: 'Your password has been updated.',
  StringKey.authSignOut: 'Sign out',
  StringKey.authSignOutConfirm: 'Sign out of HumSukhan?',
  StringKey.authNoVerification:
      'No email verification needed — you can start straight away.',
  StringKey.authEmailRequired: 'Enter your email address.',
  StringKey.authPasswordRequired: 'Enter your password.',
  StringKey.authNameRequired: 'Enter your name.',
  StringKey.authSignedIn: 'Signed in.',
  StringKey.onboardWelcomeTitle: 'Welcome to HumSukhan',
  StringKey.onboardWelcomeBody: 'See what people say, reply in your own words, and know about sounds around you.',
  StringKey.onboardEverydayTitle: 'Everyday conversation',
  StringKey.onboardEverydayBody: 'Live captions of the person speaking to you. Reply by typing, or let the app speak for you.',
  StringKey.onboardProfessionalTitle: 'Meetings and lectures',
  StringKey.onboardProfessionalBody: 'Capture a full transcript, then get a summary with action items you can share.',
  StringKey.onboardEnvironmentTitle: 'Sounds you cannot hear',
  StringKey.onboardEnvironmentBody: 'A doorbell, a siren, an alarm — HumSukhan taps your phone and shows you what it heard.',
  StringKey.onboardPrivacyTitle: 'Your audio stays yours',
  StringKey.onboardPrivacyBody: 'Sound detection runs entirely on this device. Nothing is uploaded, and captions are kept only as long as you choose.',
  StringKey.homeGreeting: 'Hello, {name}',
  StringKey.homeGreetingAnonymous: 'Hello',
  StringKey.homeRecentActivity: 'Recent activity',
  StringKey.homeNoActivity: 'Nothing yet. Start a conversation or a session.',
  StringKey.homeEverydayCard: 'Talk to someone',
  StringKey.homeEverydayCardBody: 'Live captions and spoken replies',
  StringKey.homeProfessionalCard: 'Record a session',
  StringKey.homeProfessionalCardBody: 'Full transcript, then a summary',
  StringKey.homeAlertsCard: 'Listen for sounds',
  StringKey.homeAlertsCardBody: 'On-device alerts for important sounds',
  StringKey.everydayTitle: 'Everyday',
  StringKey.everydayStart: 'Start conversation',
  StringKey.everydayStop: 'Stop',
  StringKey.everydayIdleHint: 'Start a conversation, then tap the microphone when the other person begins to speak.',
  StringKey.everydayPrivacyNotice: 'Speech is sent for recognition only while the microphone is on, and is never stored by the recogniser.',
  StringKey.everydayMicStart: 'Start speaker microphone',
  StringKey.everydayMicStop: 'Stop speaker microphone',
  StringKey.everydayStatusIdle: 'Microphone off',
  StringKey.everydayStatusStarting: 'Starting…',
  StringKey.everydayStatusListening: 'Listening',
  StringKey.everydayStatusPaused: 'Pause detected — speak again to continue',
  StringKey.everydayStatusReconnecting: 'Connection lost — reconnecting',
  StringKey.everydayStatusFailed: 'Recognition stopped',
  StringKey.everydayStatusSpeaking: 'Speaking',
  StringKey.everydaySpeakerLabel: 'Them',
  StringKey.everydayYouLabel: 'You',
  StringKey.everydayComposerHint: 'Type a reply',
  StringKey.everydaySend: 'Send',
  StringKey.everydaySpeak: 'Speak',
  StringKey.everydaySpeakThis: 'Speak this caption',
  StringKey.everydayStopSpeaking: 'Stop speaking',
  StringKey.everydayQuickReplies: 'Quick replies',
  StringKey.everydayPauseThreshold: 'Pause length',
  StringKey.pauseShort: 'Short · 1.2s',
  StringKey.pauseNatural: 'Natural · 1.7s',
  StringKey.pausePatient: 'Patient · 2.5s',
  StringKey.pauseManual: 'Manual only',
  StringKey.everydaySaveTitle: 'Save this conversation?',
  StringKey.everydaySaveBody: 'Saved conversations are kept for as long as your retention setting allows.',
  StringKey.everydaySaved: 'Conversation saved.',
  StringKey.everydayDeleted: 'Conversation deleted.',
  StringKey.everydayNoCaptions:
      'No captions yet. Tap the microphone when the other person speaks.',
  StringKey.everydayControlsDisabledWhileListening:
      'Turn the microphone off to type or speak.',
  StringKey.everydaySpeaking: 'Speaking…',
  StringKey.quickReplyYes: 'Yes',
  StringKey.quickReplyNo: 'No',
  StringKey.quickReplyThanks: 'Thank you',
  StringKey.quickReplyRepeat: 'Could you repeat that?',
  StringKey.quickReplySlower: 'Please speak a little slower',
  StringKey.quickReplyOneMoment: 'One moment please',
  StringKey.quickReplyWriteItDown: 'Could you write that down?',
  StringKey.proTitle: 'Professional',
  StringKey.proNewSession: 'New session',
  StringKey.proSessionName: 'Session name',
  StringKey.proSessionType: 'Type',
  StringKey.proTypeMeeting: 'Meeting',
  StringKey.proTypeLecture: 'Lecture',
  StringKey.proTypeClass: 'Class',
  StringKey.proCaptionLanguage: 'Caption language',
  StringKey.proRetention: 'Keep for',
  StringKey.proStartRecording: 'Start recording',
  StringKey.proStopRecording: 'Stop recording',
  StringKey.proRecording: 'Recording',
  StringKey.proTranscript: 'Transcript',
  StringKey.proSummary: 'Summary',
  StringKey.proActions: 'Actions',
  StringKey.proOverview: 'Overview',
  StringKey.proGenerateSummary: 'Generate summary',
  StringKey.proSummaryGenerating: 'Generating the summary…',
  StringKey.proSummaryEmpty:
      'No summary yet. Generate one from the transcript.',
  StringKey.proNoSessions: 'No sessions yet. Record a meeting or a lecture.',
  StringKey.proSessionSaved: 'Session saved.',
  StringKey.proSessionDiscarded: 'Session discarded.',
  StringKey.proSaveTitle: 'Save this session?',
  StringKey.proDuration: 'Duration',
  StringKey.proExpiresInDays: 'Expires in {days} days',
  StringKey.proExpiresTomorrow: 'Expires tomorrow',
  StringKey.proExpiresToday: 'Expires today',
  StringKey.proExpired: 'Expired',
  StringKey.proActionItems: 'Action items',
  StringKey.proDeadlines: 'Deadlines',
  StringKey.proPeople: 'People mentioned',
  StringKey.proKeyPoints: 'Key points',
  StringKey.proNoTranscript: 'Nothing was captured in this session.',
  StringKey.proInterimHidden:
      'Only finished sentences are added to the transcript.',
  StringKey.proAddNote: 'Add a note',
  StringKey.proWordCount: '{count} words',
  StringKey.proRetentionDays: '{days} days',
  StringKey.aiDisclaimer:
      'AI-generated. Check anything important against the transcript.',
  StringKey.envTitle: 'Alerts',
  StringKey.envMonitoring: 'Sound monitoring',
  StringKey.envStateOff: 'Monitoring is off',
  StringKey.envStateStarting: 'Starting monitoring…',
  StringKey.envStateActive: 'Listening for important sounds',
  StringKey.envStateFailed: 'Monitoring stopped',
  StringKey.envSupportedSounds: 'Sounds HumSukhan listens for',
  StringKey.envHistory: 'Recent alerts',
  StringKey.envNoAlerts: 'No alerts yet.',
  StringKey.envOnDeviceNotice:
      'Audio is classified on this device and is never uploaded.',
  StringKey.envAlertChannels: 'How you are alerted',
  StringKey.envSeverityCritical: 'Critical',
  StringKey.envSeverityHigh: 'Important',
  StringKey.envSeverityNormal: 'Normal',
  StringKey.envSoundSiren: 'Siren',
  StringKey.envSoundDoorbell: 'Doorbell',
  StringKey.envSoundAlarm: 'Alarm',
  StringKey.envSoundBabyCry: 'Baby crying',
  StringKey.envSoundKnock: 'Knock at the door',
  StringKey.envSoundGlassBreak: 'Breaking glass',
  StringKey.envSoundDogBark: 'Dog barking',
  StringKey.envSoundVehicleHorn: 'Vehicle horn',
  StringKey.envSoundPhone: 'Phone ringing',
  StringKey.envModelReady: 'Sound model ready',
  StringKey.envModelChecking: 'Checking the sound model…',
  StringKey.envModelDownloading: 'Downloading the sound model…',
  StringKey.envModelVerifying: 'Verifying the sound model…',
  StringKey.envModelAbsent: 'The sound model is not installed.',
  StringKey.envInstallModel: 'Install the sound model',
  StringKey.envDetectedAt: 'Detected at {time}',
  StringKey.envConfidence: '{percent}% confidence',
  StringKey.envClearHistory: 'Clear alert history',
  StringKey.envForegroundNotice:
      'Monitoring keeps running while HumSukhan is in the background.',
  StringKey.setTitle: 'Settings',
  StringKey.setProfile: 'Profile',
  StringKey.setDisplayName: 'Display name',
  StringKey.setAppearance: 'Appearance',
  StringKey.setDarkMode: 'Dark mode',
  StringKey.setHighContrast: 'High contrast',
  StringKey.setHighContrastBody: 'Pure black and white with heavier borders.',
  StringKey.setLargeText: 'Large text',
  StringKey.setLargeTextBody:
      'Increases text size on top of your system setting.',
  StringKey.setCaptionSize: 'Caption size',
  StringKey.setCaptionPreview: 'This is how captions will look.',
  StringKey.setLanguage: 'Language',
  StringKey.setAppLanguage: 'App language',
  StringKey.setCaptionLanguage: 'Caption language',
  StringKey.setLanguageEnglish: 'English',
  StringKey.setLanguageUrdu: 'Urdu',
  StringKey.setAlerts: 'Alerts',
  StringKey.setHaptic: 'Vibration',
  StringKey.setVisual: 'On-screen alert',
  StringKey.setTorch: 'Camera flash',
  StringKey.setScreenFlash: 'Screen flash',
  StringKey.setRetention: 'Keep recordings for',
  StringKey.setRetentionBody: 'Sessions and conversations are deleted automatically after this many days.',
  StringKey.setAccount: 'Account',
  StringKey.setOfflineModels: 'On-device model',
  StringKey.setAbout: 'About',
  StringKey.setVersion: 'Version {version}',
  StringKey.setSaved: 'Saved.',
  StringKey.langEnglish: 'English',
  StringKey.langUrdu: 'Urdu',
  StringKey.langRomanUrdu: 'Roman Urdu',
  StringKey.langMixed: 'English and Urdu',
  StringKey.langUndetermined: 'Not yet detected',
  StringKey.stateLoadingTitle: 'Loading',
  StringKey.stateErrorTitle: 'That did not work',
  StringKey.stateEmptyTitle: 'Nothing here yet',
};

const Map<StringKey, String> _urdu = <StringKey, String>{
  StringKey.appName: 'ہم سخن',
  StringKey.appTagline: 'جو آپ کے ساتھ بولے',
  StringKey.ok: 'ٹھیک ہے',
  StringKey.cancel: 'منسوخ کریں',
  StringKey.save: 'محفوظ کریں',
  StringKey.delete: 'حذف کریں',
  StringKey.discard: 'ضائع کریں',
  StringKey.retry: 'دوبارہ کوشش کریں',
  StringKey.close: 'بند کریں',
  StringKey.back: 'واپس',
  StringKey.next: 'آگے',
  StringKey.done: 'مکمل',
  StringKey.continueLabel: 'جاری رکھیں',
  StringKey.skip: 'چھوڑ دیں',
  StringKey.getStarted: 'شروع کریں',
  StringKey.share: 'شیئر کریں',
  StringKey.export: 'برآمد کریں',
  StringKey.loading: 'لوڈ ہو رہا ہے…',
  StringKey.dismiss: 'ہٹا دیں',
  StringKey.openSystemSettings: 'سسٹم کی ترتیبات کھولیں',
  StringKey.somethingWentWrong: 'کچھ غلط ہو گیا',
  StringKey.online: 'آن لائن',
  StringKey.offline: 'آف لائن',
  StringKey.remove: 'ہٹائیں',
  StringKey.edit: 'ترمیم کریں',
  StringKey.copy: 'نقل کریں',
  StringKey.copied: 'نقل ہو گیا',
  StringKey.navHome: 'ہوم',
  StringKey.navEveryday: 'روزمرہ',
  StringKey.navProfessional: 'پیشہ ورانہ',
  StringKey.navAlerts: 'اطلاعات',
  StringKey.navSettings: 'ترتیبات',
  StringKey.authSignInTitle: 'خوش آمدید',
  StringKey.authSignUpTitle: 'اپنا اکاؤنٹ بنائیں',
  StringKey.authForgotTitle: 'پاس ورڈ دوبارہ ترتیب دیں',
  StringKey.authRecoveryTitle: 'نیا پاس ورڈ منتخب کریں',
  StringKey.authEmail: 'ای میل',
  StringKey.authPassword: 'پاس ورڈ',
  StringKey.authNewPassword: 'نیا پاس ورڈ',
  StringKey.authName: 'آپ کا نام',
  StringKey.authSignIn: 'سائن اِن',
  StringKey.authSignUp: 'اکاؤنٹ بنائیں',
  StringKey.authSendResetLink: 'ری سیٹ لنک بھیجیں',
  StringKey.authUpdatePassword: 'پاس ورڈ بدلیں',
  StringKey.authNoAccount: 'اکاؤنٹ نہیں ہے؟ بنائیں',
  StringKey.authHaveAccount: 'پہلے سے اکاؤنٹ ہے؟ سائن اِن کریں',
  StringKey.authForgotPrompt: 'پاس ورڈ بھول گئے؟',
  StringKey.authResetSent: 'ری سیٹ لنک کے لیے اپنی ای میل دیکھیں۔',
  StringKey.authPasswordUpdated: 'آپ کا پاس ورڈ بدل دیا گیا ہے۔',
  StringKey.authSignOut: 'سائن آؤٹ',
  StringKey.authSignOutConfirm: 'ہم سخن سے سائن آؤٹ کریں؟',
  StringKey.authNoVerification:
      'ای میل کی تصدیق ضروری نہیں — آپ فوراً شروع کر سکتے ہیں۔',
  StringKey.authEmailRequired: 'اپنا ای میل پتہ درج کریں۔',
  StringKey.authPasswordRequired: 'اپنا پاس ورڈ درج کریں۔',
  StringKey.authNameRequired: 'اپنا نام درج کریں۔',
  StringKey.authSignedIn: 'سائن اِن ہو گئے۔',
  StringKey.onboardWelcomeTitle: 'ہم سخن میں خوش آمدید',
  StringKey.onboardWelcomeBody: 'دیکھیں لوگ کیا کہہ رہے ہیں، اپنے الفاظ میں جواب دیں، اور اردگرد کی آوازوں سے باخبر رہیں۔',
  StringKey.onboardEverydayTitle: 'روزمرہ گفتگو',
  StringKey.onboardEverydayBody: 'آپ سے بات کرنے والے کی گفتگو براہِ راست تحریر میں۔ لکھ کر جواب دیں، یا ایپ سے بلوائیں۔',
  StringKey.onboardProfessionalTitle: 'اجلاس اور لیکچر',
  StringKey.onboardProfessionalBody:
      'مکمل تحریر محفوظ کریں، پھر خلاصہ اور قابلِ عمل نکات حاصل کریں۔',
  StringKey.onboardEnvironmentTitle: 'وہ آوازیں جو آپ نہیں سن سکتے',
  StringKey.onboardEnvironmentBody: 'دروازے کی گھنٹی، سائرن، الارم — ہم سخن آپ کے فون کو ارتعاش دے کر بتاتا ہے کہ کیا سنا۔',
  StringKey.onboardPrivacyTitle: 'آپ کی آواز آپ کی رہتی ہے',
  StringKey.onboardPrivacyBody: 'آوازوں کی شناخت مکمل طور پر اسی ڈیوائس پر ہوتی ہے۔ کچھ اپ لوڈ نہیں ہوتا، اور تحریریں صرف اتنی دیر رہتی ہیں جتنا آپ چاہیں۔',
  StringKey.homeGreeting: 'السلام علیکم، {name}',
  StringKey.homeGreetingAnonymous: 'السلام علیکم',
  StringKey.homeRecentActivity: 'حالیہ سرگرمی',
  StringKey.homeNoActivity: 'ابھی کچھ نہیں۔ گفتگو یا سیشن شروع کریں۔',
  StringKey.homeEverydayCard: 'کسی سے بات کریں',
  StringKey.homeEverydayCardBody: 'براہِ راست تحریر اور بولے گئے جواب',
  StringKey.homeProfessionalCard: 'سیشن ریکارڈ کریں',
  StringKey.homeProfessionalCardBody: 'مکمل تحریر، پھر خلاصہ',
  StringKey.homeAlertsCard: 'آوازوں پر نظر',
  StringKey.homeAlertsCardBody: 'اہم آوازوں کے لیے ڈیوائس پر اطلاع',
  StringKey.everydayTitle: 'روزمرہ',
  StringKey.everydayStart: 'گفتگو شروع کریں',
  StringKey.everydayStop: 'روکیں',
  StringKey.everydayIdleHint:
      'گفتگو شروع کریں، پھر جب دوسرا شخص بولنے لگے تو مائیکروفون دبائیں۔',
  StringKey.everydayPrivacyNotice: 'آواز صرف اُس وقت شناخت کے لیے بھیجی جاتی ہے جب مائیکروفون آن ہو، اور شناخت کرنے والا اسے محفوظ نہیں کرتا۔',
  StringKey.everydayMicStart: 'مائیکروفون آن کریں',
  StringKey.everydayMicStop: 'مائیکروفون بند کریں',
  StringKey.everydayStatusIdle: 'مائیکروفون بند ہے',
  StringKey.everydayStatusStarting: 'شروع ہو رہا ہے…',
  StringKey.everydayStatusListening: 'سن رہا ہے',
  StringKey.everydayStatusPaused: 'وقفہ محسوس ہوا — بولنا جاری رکھیں',
  StringKey.everydayStatusReconnecting: 'رابطہ منقطع — دوبارہ جوڑا جا رہا ہے',
  StringKey.everydayStatusFailed: 'شناخت رک گئی',
  StringKey.everydayStatusSpeaking: 'بول رہا ہے',
  StringKey.everydaySpeakerLabel: 'وہ',
  StringKey.everydayYouLabel: 'آپ',
  StringKey.everydayComposerHint: 'جواب لکھیں',
  StringKey.everydaySend: 'بھیجیں',
  StringKey.everydaySpeak: 'بولیں',
  StringKey.everydaySpeakThis: 'یہ جملہ بولیں',
  StringKey.everydayStopSpeaking: 'بولنا روکیں',
  StringKey.everydayQuickReplies: 'فوری جواب',
  StringKey.everydayPauseThreshold: 'وقفے کی لمبائی',
  StringKey.pauseShort: 'مختصر · ۱.۲ سیکنڈ',
  StringKey.pauseNatural: 'معمول · ۱.۷ سیکنڈ',
  StringKey.pausePatient: 'تحمل · ۲.۵ سیکنڈ',
  StringKey.pauseManual: 'صرف دستی',
  StringKey.everydaySaveTitle: 'یہ گفتگو محفوظ کریں؟',
  StringKey.everydaySaveBody: 'محفوظ گفتگو آپ کی مقررہ مدت تک رہتی ہے۔',
  StringKey.everydaySaved: 'گفتگو محفوظ ہو گئی۔',
  StringKey.everydayDeleted: 'گفتگو حذف ہو گئی۔',
  StringKey.everydayNoCaptions:
      'ابھی کوئی تحریر نہیں۔ جب دوسرا شخص بولے تو مائیکروفون دبائیں۔',
  StringKey.everydayControlsDisabledWhileListening:
      'لکھنے یا بولنے کے لیے مائیکروفون بند کریں۔',
  StringKey.everydaySpeaking: 'بول رہا ہے…',
  StringKey.quickReplyYes: 'جی ہاں',
  StringKey.quickReplyNo: 'جی نہیں',
  StringKey.quickReplyThanks: 'شکریہ',
  StringKey.quickReplyRepeat: 'کیا آپ دوبارہ کہیں گے؟',
  StringKey.quickReplySlower: 'براہِ کرم ذرا آہستہ بولیں',
  StringKey.quickReplyOneMoment: 'ایک لمحہ',
  StringKey.quickReplyWriteItDown: 'کیا آپ یہ لکھ دیں گے؟',
  StringKey.proTitle: 'پیشہ ورانہ',
  StringKey.proNewSession: 'نیا سیشن',
  StringKey.proSessionName: 'سیشن کا نام',
  StringKey.proSessionType: 'قسم',
  StringKey.proTypeMeeting: 'میٹنگ',
  StringKey.proTypeLecture: 'لیکچر',
  StringKey.proTypeClass: 'کلاس',
  StringKey.proCaptionLanguage: 'تحریر کی زبان',
  StringKey.proRetention: 'مدتِ حفاظت',
  StringKey.proStartRecording: 'ریکارڈنگ شروع کریں',
  StringKey.proStopRecording: 'ریکارڈنگ بند کریں',
  StringKey.proRecording: 'ریکارڈ ہو رہا ہے',
  StringKey.proTranscript: 'تحریر',
  StringKey.proSummary: 'خلاصہ',
  StringKey.proActions: 'اقدامات',
  StringKey.proOverview: 'جائزہ',
  StringKey.proGenerateSummary: 'خلاصہ بنائیں',
  StringKey.proSummaryGenerating: 'خلاصہ بنایا جا رہا ہے…',
  StringKey.proSummaryEmpty: 'ابھی خلاصہ نہیں۔ تحریر سے بنائیں۔',
  StringKey.proNoSessions:
      'ابھی کوئی سیشن نہیں۔ کوئی میٹنگ یا لیکچر ریکارڈ کریں۔',
  StringKey.proSessionSaved: 'سیشن محفوظ ہو گیا۔',
  StringKey.proSessionDiscarded: 'سیشن ضائع کر دیا گیا۔',
  StringKey.proSaveTitle: 'یہ سیشن محفوظ کریں؟',
  StringKey.proDuration: 'دورانیہ',
  StringKey.proExpiresInDays: '{days} دن میں ختم',
  StringKey.proExpiresTomorrow: 'کل ختم ہو جائے گا',
  StringKey.proExpiresToday: 'آج ختم ہو جائے گا',
  StringKey.proExpired: 'مدت ختم',
  StringKey.proActionItems: 'قابلِ عمل نکات',
  StringKey.proDeadlines: 'آخری تاریخیں',
  StringKey.proPeople: 'زیرِ ذکر افراد',
  StringKey.proKeyPoints: 'اہم نکات',
  StringKey.proNoTranscript: 'اس سیشن میں کچھ محفوظ نہیں ہوا۔',
  StringKey.proInterimHidden: 'تحریر میں صرف مکمل جملے شامل ہوتے ہیں۔',
  StringKey.proAddNote: 'نوٹ شامل کریں',
  StringKey.proWordCount: '{count} الفاظ',
  StringKey.proRetentionDays: '{days} دن',
  StringKey.aiDisclaimer: 'اے آئی سے تیار شدہ۔ اہم بات تحریر سے ضرور ملا لیں۔',
  StringKey.envTitle: 'اطلاعات',
  StringKey.envMonitoring: 'آوازوں کی نگرانی',
  StringKey.envStateOff: 'نگرانی بند ہے',
  StringKey.envStateStarting: 'نگرانی شروع ہو رہی ہے…',
  StringKey.envStateActive: 'اہم آوازوں پر نظر ہے',
  StringKey.envStateFailed: 'نگرانی رک گئی',
  StringKey.envSupportedSounds: 'ہم سخن جن آوازوں پر نظر رکھتا ہے',
  StringKey.envHistory: 'حالیہ اطلاعات',
  StringKey.envNoAlerts: 'ابھی کوئی اطلاع نہیں۔',
  StringKey.envOnDeviceNotice:
      'آواز کی شناخت اسی ڈیوائس پر ہوتی ہے، کہیں اپ لوڈ نہیں ہوتی۔',
  StringKey.envAlertChannels: 'اطلاع کیسے دی جائے',
  StringKey.envSeverityCritical: 'انتہائی اہم',
  StringKey.envSeverityHigh: 'اہم',
  StringKey.envSeverityNormal: 'عام',
  StringKey.envSoundSiren: 'سائرن',
  StringKey.envSoundDoorbell: 'دروازے کی گھنٹی',
  StringKey.envSoundAlarm: 'الارم',
  StringKey.envSoundBabyCry: 'بچے کا رونا',
  StringKey.envSoundKnock: 'دروازے پر دستک',
  StringKey.envSoundGlassBreak: 'شیشہ ٹوٹنا',
  StringKey.envSoundDogBark: 'کتے کا بھونکنا',
  StringKey.envSoundVehicleHorn: 'گاڑی کا ہارن',
  StringKey.envSoundPhone: 'فون کی گھنٹی',
  StringKey.envModelReady: 'آواز کا ماڈل تیار ہے',
  StringKey.envModelChecking: 'آواز کا ماڈل جانچا جا رہا ہے…',
  StringKey.envModelDownloading: 'آواز کا ماڈل ڈاؤن لوڈ ہو رہا ہے…',
  StringKey.envModelVerifying: 'آواز کے ماڈل کی تصدیق ہو رہی ہے…',
  StringKey.envModelAbsent: 'آواز کا ماڈل نصب نہیں ہے۔',
  StringKey.envInstallModel: 'آواز کا ماڈل نصب کریں',
  StringKey.envDetectedAt: '{time} پر محسوس ہوئی',
  StringKey.envConfidence: '{percent}٪ یقین',
  StringKey.envClearHistory: 'اطلاعات کی فہرست صاف کریں',
  StringKey.envForegroundNotice:
      'ہم سخن کے پس منظر میں ہونے پر بھی نگرانی جاری رہتی ہے۔',
  StringKey.setTitle: 'ترتیبات',
  StringKey.setProfile: 'پروفائل',
  StringKey.setDisplayName: 'ظاہری نام',
  StringKey.setAppearance: 'ظاہری شکل',
  StringKey.setDarkMode: 'تاریک موڈ',
  StringKey.setHighContrast: 'نمایاں تضاد',
  StringKey.setHighContrastBody: 'خالص سیاہ و سفید اور نمایاں کنارے۔',
  StringKey.setLargeText: 'بڑی تحریر',
  StringKey.setLargeTextBody: 'سسٹم کی ترتیب کے علاوہ تحریر مزید بڑی کرتا ہے۔',
  StringKey.setCaptionSize: 'تحریر کا حجم',
  StringKey.setCaptionPreview: 'تحریریں ایسی دکھائی دیں گی۔',
  StringKey.setLanguage: 'زبان',
  StringKey.setAppLanguage: 'ایپ کی زبان',
  StringKey.setCaptionLanguage: 'تحریر کی زبان',
  StringKey.setLanguageEnglish: 'انگریزی',
  StringKey.setLanguageUrdu: 'اردو',
  StringKey.setAlerts: 'اطلاعات',
  StringKey.setHaptic: 'ارتعاش',
  StringKey.setVisual: 'اسکرین پر اطلاع',
  StringKey.setTorch: 'کیمرہ فلیش',
  StringKey.setScreenFlash: 'اسکرین کی چمک',
  StringKey.setRetention: 'ریکارڈنگ کی مدت',
  StringKey.setRetentionBody:
      'سیشن اور گفتگو اتنے دنوں بعد خود بخود حذف ہو جاتے ہیں۔',
  StringKey.setAccount: 'اکاؤنٹ',
  StringKey.setOfflineModels: 'ڈیوائس کا ماڈل',
  StringKey.setAbout: 'تعارف',
  StringKey.setVersion: 'ورژن {version}',
  StringKey.setSaved: 'محفوظ ہو گیا۔',
  StringKey.langEnglish: 'انگریزی',
  StringKey.langUrdu: 'اردو',
  StringKey.langRomanUrdu: 'رومن اردو',
  StringKey.langMixed: 'انگریزی اور اردو',
  StringKey.langUndetermined: 'ابھی معلوم نہیں',
  StringKey.stateLoadingTitle: 'لوڈ ہو رہا ہے',
  StringKey.stateErrorTitle: 'یہ کام نہیں کر سکا',
  StringKey.stateEmptyTitle: 'ابھی یہاں کچھ نہیں',
};

const Map<FailureCode, String> _urduFailureMessages = <FailureCode, String>{
  FailureCode.unknown: 'کچھ غلط ہو گیا۔',
  FailureCode.offline: 'آپ آف لائن ہیں۔',
  FailureCode.network: 'نیٹ ورک کی درخواست ناکام رہی۔',
  FailureCode.timeout: 'درخواست میں بہت دیر لگ گئی۔',
  FailureCode.microphonePermissionDenied: 'مائیکروفون کی اجازت نہیں دی گئی۔',
  FailureCode.microphonePermissionPermanentlyDenied:
      'اس ایپ کے لیے مائیکروفون بند ہے۔',
  FailureCode.microphoneUnavailable: 'مائیکروفون کھل نہیں سکا۔',
  FailureCode.notificationPermissionDenied: 'اطلاعات بند ہیں۔',
  FailureCode.sttLanguageUnsupported:
      'یہ ڈیوائس منتخب زبان کی شناخت نہیں کر سکتی۔',
  FailureCode.sttStartFailed: 'شناخت شروع نہیں ہو سکی۔',
  FailureCode.sttTransportLost: 'شناخت کرنے والے سے رابطہ منقطع ہو گیا۔',
  FailureCode.sttAuthFailed: 'شناخت کی سروس نے درخواست قبول نہیں کی۔',
  FailureCode.ttsUnavailable: 'اس ڈیوائس پر کوئی بولنے والا انجن موجود نہیں۔',
  FailureCode.ttsVoiceMissing: 'اس زبان کے لیے کوئی آواز نصب نہیں ہے۔',
  FailureCode.ttsFailed: 'بولنے میں ناکامی ہوئی۔',
  FailureCode.authInvalidCredentials:
      'یہ ای میل اور پاس ورڈ آپس میں نہیں ملتے۔',
  FailureCode.authEmailInUse: 'اس ای میل سے پہلے ہی ایک اکاؤنٹ موجود ہے۔',
  FailureCode.authWeakPassword: 'یہ پاس ورڈ بہت مختصر ہے۔',
  FailureCode.authInvalidEmail: 'یہ درست ای میل پتہ نہیں ہے۔',
  FailureCode.authRateLimited: 'بہت زیادہ کوششیں۔ ذرا رکیں۔',
  FailureCode.authNoSession: 'آپ سائن آؤٹ ہیں۔',
  FailureCode.storageReadFailed: 'آپ کا ڈیٹا لوڈ نہیں ہو سکا۔',
  FailureCode.storageWriteFailed: 'آپ کا ڈیٹا محفوظ نہیں ہو سکا۔',
  FailureCode.insightTranscriptEmpty: 'ابھی خلاصے کے لیے کچھ نہیں۔',
  FailureCode.insightGenerationFailed: 'خلاصہ تیار نہیں ہو سکا۔',
  FailureCode.modelAbsent: 'آواز کا ماڈل نصب نہیں ہے۔',
  FailureCode.modelCorrupt: 'آواز کے ماڈل کی فائل خراب ہے۔',
  FailureCode.modelLoadFailed: 'آواز کا ماڈل لوڈ نہیں ہو سکا۔',
  FailureCode.modelDownloadFailed: 'آواز کا ماڈل ڈاؤن لوڈ نہیں ہو سکا۔',
  FailureCode.detectorStartFailed: 'آوازوں کی شناخت شروع نہیں ہو سکی۔',
  FailureCode.serviceStartFailed: 'پس منظر کی نگرانی شروع نہیں ہو سکی۔',
  FailureCode.invalidInput: 'یہ قدر استعمال نہیں ہو سکتی۔',
  FailureCode.cancelled: 'یہ منسوخ کر دیا گیا۔',
};

const Map<FailureCode, String> _urduFailureRemedies = <FailureCode, String>{
  FailureCode.offline:
      'وائی فائی یا موبائل ڈیٹا سے جڑیں، پھر دوبارہ کوشش کریں۔',
  FailureCode.network: 'اپنا رابطہ دیکھیں اور دوبارہ کوشش کریں۔',
  FailureCode.timeout: 'دوبارہ کوشش کریں۔',
  FailureCode.microphonePermissionDenied:
      'جاری رکھنے کے لیے مائیکروفون کی اجازت دیں۔',
  FailureCode.microphonePermissionPermanentlyDenied:
      'سسٹم کی ترتیبات کھول کر ہم سخن کو مائیکروفون کی اجازت دیں۔',
  FailureCode.microphoneUnavailable:
      'مائیکروفون استعمال کرنے والی دوسری ایپس بند کریں، پھر کوشش کریں۔',
  FailureCode.notificationPermissionDenied:
      'نگرانی جاری رکھنے کے لیے اطلاعات کی اجازت دیں۔',
  FailureCode.sttLanguageUnsupported: 'تحریر کی کوئی دوسری زبان منتخب کریں۔',
  FailureCode.sttStartFailed: 'دوبارہ شروع کرنے کی کوشش کریں۔',
  FailureCode.sttTransportLost: 'اپنا رابطہ دیکھیں اور دوبارہ شروع کریں۔',
  FailureCode.sttAuthFailed:
      'سائن آؤٹ کر کے دوبارہ سائن اِن کریں، پھر کوشش کریں۔',
  FailureCode.ttsUnavailable:
      'سسٹم کی ترتیبات میں بولنے والا انجن نصب کریں، پھر کوشش کریں۔',
  FailureCode.ttsVoiceMissing:
      'سسٹم کی تقریری ترتیبات میں یہ زبان نصب کریں، پھر کوشش کریں۔',
  FailureCode.ttsFailed: 'دوبارہ کوشش کریں۔',
  FailureCode.authInvalidCredentials:
      'ای میل اور پاس ورڈ دیکھیں، یا پاس ورڈ دوبارہ ترتیب دیں۔',
  FailureCode.authEmailInUse:
      'اس کے بجائے سائن اِن کریں، یا پاس ورڈ دوبارہ ترتیب دیں۔',
  FailureCode.authWeakPassword: 'کم از کم ۸ حروف استعمال کریں۔',
  FailureCode.authInvalidEmail: 'name@example.com جیسا پتہ درج کریں۔',
  FailureCode.authRateLimited: 'ایک منٹ بعد دوبارہ کوشش کریں۔',
  FailureCode.authNoSession: 'جاری رکھنے کے لیے سائن اِن کریں۔',
  FailureCode.storageReadFailed: 'دوبارہ کوشش کریں۔',
  FailureCode.storageWriteFailed: 'دوبارہ کوشش کریں۔',
  FailureCode.insightTranscriptEmpty: 'پہلے کچھ ریکارڈ کریں۔',
  FailureCode.insightGenerationFailed: 'خلاصہ دوبارہ بنانے کی کوشش کریں۔',
  FailureCode.modelAbsent: 'ترتیبات سے آواز کا ماڈل ڈاؤن لوڈ کریں۔',
  FailureCode.modelCorrupt: 'ترتیبات سے دوبارہ ڈاؤن لوڈ کریں۔',
  FailureCode.modelLoadFailed: 'ترتیبات سے دوبارہ ڈاؤن لوڈ کریں۔',
  FailureCode.modelDownloadFailed: 'اپنا رابطہ دیکھیں اور دوبارہ کوشش کریں۔',
  FailureCode.detectorStartFailed: 'نگرانی بند کر کے دوبارہ آن کریں۔',
  FailureCode.serviceStartFailed: 'اطلاعات کی اجازت دیں، پھر نگرانی آن کریں۔',
};

/// Resolves copy for one [AppLanguage].
///
/// Constructed from the language, never read from a global — a widget is given
/// its strings, it does not reach for them (docs/instructions.md §5.1 B1).
final class AppStrings {
  const AppStrings._(this.language, this._table);

  /// The strings for [language].
  factory AppStrings.of(AppLanguage language) => switch (language) {
    AppLanguage.english => const AppStrings._(AppLanguage.english, _english),
    AppLanguage.urdu => const AppStrings._(AppLanguage.urdu, _urdu),
  };

  /// The language this instance renders.
  final AppLanguage language;

  final Map<StringKey, String> _table;

  /// The copy for [key].
  ///
  /// Falls back to English rather than showing a key name: an untranslated
  /// string is a bug the test suite catches, not something a user should meet.
  String call(StringKey key) => _table[key] ?? _english[key] ?? key.name;

  /// The copy for [key] with `{name}`-style placeholders substituted.
  String format(StringKey key, Map<String, String> values) {
    String result = call(key);
    for (final MapEntry<String, String> entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// Localised description of [code].
  String failureMessage(FailureCode code) => switch (language) {
    AppLanguage.english => const _EnglishFailureText().message(code),
    AppLanguage.urdu =>
      _urduFailureMessages[code] ?? _urduFailureMessages[FailureCode.unknown]!,
  };

  /// Localised remedy for [code], or `null` when the user can do nothing.
  String? failureRemedy(FailureCode code) => switch (language) {
    AppLanguage.english => const _EnglishFailureText().remedy(code),
    AppLanguage.urdu => _urduFailureRemedies[code],
  };

  /// Localised description of [failure], including its remedy when there is one.
  String describe(Failure failure) {
    final String? remedy = failureRemedy(failure.code);
    final String message = failureMessage(failure.code);
    return remedy == null ? message : '$message $remedy';
  }
}

/// English failure copy lives on [Failure] itself so logs and tests read the
/// same words the user does. This adapter keeps that single source.
final class _EnglishFailureText {
  const _EnglishFailureText();

  String message(FailureCode code) => _CodedFailure(code).message;

  String? remedy(FailureCode code) => _CodedFailure(code).remedy;
}

final class _CodedFailure extends Failure {
  const _CodedFailure(FailureCode code) : super(code: code);
}
