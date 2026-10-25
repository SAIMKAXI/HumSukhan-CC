# Android platform access to the remote caller's audio in an ordinary cellular (CS/VoLTE) call, as of late 2026

Scope: an ordinary third-party Play Store app on an unrooted phone, using the stock dialer, with the remote party changing nothing. Research date: 2026-10-25.

Source-access notes:
- developer.android.com reference pages were downloaded with curl and their text extracted. "Last updated" dates are the ones printed on each page.
- android.googlesource.com and cs.android.com were blocked (proxy CONNECT 403). AOSP source was read from GitHub mirrors instead:
  - `aosp-mirror/platform_frameworks_base` (main branch). I could not check how current this mirror is.
  - LineageOS `lineage-23.0` branches, which are Android 16 based. `lineage-17.1` (Android 10 based) was used for history.
- support.google.com (Play policy pages), play.google.com and nllapps.com did not resolve (DNS), so for those I used search-result snippets and news coverage.

Evidence labels used below:
- **[DOC]** documented by Google
- **[SRC]** read in AOSP source
- **[ANEC]** anecdotal: developer or user report
- **[INF]** my inference

---

## 1. Audio sources (VOICE_CALL / VOICE_DOWNLINK / VOICE_UPLINK / VOICE_COMMUNICATION / VOICE_RECOGNITION / MIC) during a cellular call: permissions and behaviour for a normal app

### Takeaway
VOICE_CALL, VOICE_DOWNLINK and VOICE_UPLINK need `CAPTURE_AUDIO_OUTPUT` (protection level `signature|privileged|role`). On current AOSP, audioserver also accepts `CALL_AUDIO_INTERCEPTION` (also `signature|privileged|role`). Both are unobtainable by a Play-installed app, so the native permission check fails. The mic sources (MIC, VOICE_RECOGNITION, VOICE_COMMUNICATION) only need `RECORD_AUDIO`. However, AOSP's capture policy (Android 10+) silences an ordinary app's mic capture while the audio mode is MODE_IN_CALL. Even when mic capture is allowed, it only picks up the remote voice acoustically (for example from the loudspeaker), never the downlink signal.

### Cited Findings
- **[DOC] VOICE_CALL.** The reference says: "Voice call uplink + downlink audio source. Capturing from VOICE_CALL source requires the Manifest.permission.CAPTURE_AUDIO_OUTPUT permission. This permission is reserved for use by system components and is not available to third-party applications." VOICE_DOWNLINK ("Voice call downlink (Rx) audio source", added API 4) and VOICE_UPLINK ("Voice call uplink (Tx)", added API 4) carry identical wording. Page last updated 2026-08-03. — [MediaRecorder.AudioSource](https://developer.android.com/reference/android/media/MediaRecorder.AudioSource)
- **[DOC] Mic sources.** VOICE_COMMUNICATION (added API 11) is "Microphone audio source tuned for voice communications such as VoIP… echo cancellation or automatic gain control". VOICE_RECOGNITION is "Microphone audio source tuned for voice recognition". MIC is "Microphone audio source". None of them states a permission beyond RECORD_AUDIO. — [MediaRecorder.AudioSource](https://developer.android.com/reference/android/media/MediaRecorder.AudioSource)
- **[DOC] Permission reference.** `CAPTURE_AUDIO_OUTPUT` was added in API 19: "Allows an application to capture audio output… Not for use by third-party applications." `RECORD_AUDIO` has "Protection level: dangerous". Page last updated 2026-10-09. — [Manifest.permission](https://developer.android.com/reference/android/Manifest.permission)
- **[SRC] Protection levels in the AOSP framework manifest:**
  - `CAPTURE_AUDIO_OUTPUT` is `android:protectionLevel="signature|privileged|role"`.
  - `CAPTURE_MEDIA_OUTPUT` (@SystemApi @hide) is `signature|privileged|role`.
  - `CAPTURE_VOICE_COMMUNICATION_OUTPUT` (@SystemApi @hide, captures other apps' USAGE_VOICE_COMMUNICATION playback) is `signature|privileged|role`.
  - `CALL_AUDIO_INTERCEPTION` ("@SystemApi Allows an application to access the uplink and downlink audio of an ongoing call. Not for use by third-party applications. @hide") is `signature|privileged|role`.
  - `CONTROL_INCALL_EXPERIENCE` is `signature|privileged|role`.
  - New permission, behind feature flag `android.media.audio.concurrent_audio_record_bypass_permission`: `BYPASS_CONCURRENT_RECORD_AUDIO_RESTRICTION` ("@SystemApi Allows an application to bypass concurrency restrictions while recording audio. For example, apps with this permission can continue to record while a voice call is active.") is `signature|privileged`.
  - Source: [AOSP core/res/AndroidManifest.xml (GitHub mirror, main)](https://github.com/aosp-mirror/platform_frameworks_base/blob/main/core/res/AndroidManifest.xml)
- **[SRC] Native enforcement.** In `AudioPolicyService::AudioPolicyClient::checkPermissionForInput`:
  - VOICE_UPLINK, VOICE_DOWNLINK and VOICE_CALL are first checked for `CALL_AUDIO_INTERCEPTION`.
  - If that fails, "legacy output sources" (VOICE_CALL, VOICE_DOWNLINK, VOICE_UPLINK, FM_TUNER) fall back to a `CAPTURE_AUDIO_OUTPUT` check. Any other failure returns false (denied).
  - Source: [AudioPolicyInterfaceImpl.cpp, LineageOS 23.0 / Android 16](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyInterfaceImpl.cpp)
- **[SRC] Mic is silenced during a cellular call for ordinary apps.** In `AudioPolicyService::updateUidStates_l()`:
  - `isInCall = mPhoneState == AUDIO_MODE_IN_CALL`.
  - The lambda `canCaptureIfInCallOrCommunication` returns `!(isInCall && !canCaptureCall)`, where `canCaptureCall = recordClient->canBypassConcurrentPolicy`.
  - `canBypassConcurrentPolicy` is true only for holders of `CAPTURE_AUDIO_OUTPUT`, or of `BYPASS_CONCURRENT_RECORD_AUDIO_RESTRICTION` when that flag is on.
  - The default "Any client" path requires `canCaptureIfInCallOrCommunication`, so an ordinary app's capture is not allowed (it is silenced) while a cellular call is active.
  - The code comment says: "a client can capture calls if it either: has CAPTURE_AUDIO_OUTPUT privileged permission … or has CONCURRENT_AUDIO_RECORD_BYPASS privileged permission."
  - Source: [AudioPolicyService.cpp, LineageOS 23.0 / Android 16](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyService.cpp)
- **[SRC] Same rule in Android 10.** The Android 10 code already had `isInCall = mPhoneState == AUDIO_MODE_IN_CALL` and the condition `&& !(isInCall && !current->canCaptureOutput)`. — [AudioPolicyService.cpp, LineageOS 17.1 / Android 10](https://github.com/LineageOS/android_frameworks_av/blob/lineage-17.1/services/audiopolicy/service/AudioPolicyService.cpp)
- **[SRC] Virtual sources skip the concurrency check.** Virtual sources ("remote submix, call audio TX or RX") are always allowed by the concurrency logic. They are still gated by the permission check above. — [AudioPolicyService.cpp (A16)](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyService.cpp)
- **[DOC] Android 9 background silencing.** "In Android 9: only apps running in the foreground (or a foreground service) could capture the audio input. When an app without a foreground service or foreground UI component started to capture, the app continued running but received silence." — [Sharing audio input (developer.android.com, updated 2026-10-16)](https://developer.android.com/media/platform/sharing-audio-input)
- **[DOC] BCR's statement.** chenxiaolong's root/system call recorder says VOICE_CALL "along with some others, like VOICE_DOWNLINK and VOICE_UPLINK, cannot be accessed without this system permission" (CAPTURE_AUDIO_OUTPUT). — [BCR README](https://github.com/chenxiaolong/BCR/blob/master/README.md)

### Inferences
- [INF] A Play app requesting VOICE_CALL or VOICE_DOWNLINK gets PERMISSION_DENIED from audioserver. At the Java level this typically shows up as an uninitialized AudioRecord or as MediaRecorder prepare/start failing. I did not read the exact Java-side exception path.
- [INF] A Play app recording MIC, VOICE_RECOGNITION or VOICE_COMMUNICATION during a CS/VoLTE call (MODE_IN_CALL) on AOSP-derived builds gets an AudioRecord that runs but delivers silence. `AudioRecordingConfiguration.isClientSilenced()` would return true. OEM forks could differ, and no on-device test was done here.
- [INF] Even where mic capture is allowed, the earpiece downlink is acoustically faint. The modem's echo canceller may also suppress loudspeaker leakage on the uplink path, but that is a separate path from an app's capture. Caption quality would depend on speakerphone use.

### Gaps
- I did not verify which Android version first made the VOICE_CALL permission check effective on stock builds. Reports say Android 9 "put an end" to third-party call recording, but I did not read the primary source.
- I did not read the exact Java exception or `AudioRecord.getState()` result for VOICE_CALL without permission, and did not test on a device.
- I did not survey OEM deviations, such as Samsung or Xiaomi audio policy patches.

---

## 2. Android 10+ concurrent-capture policy: can an app record the mic while a call is active?

### Takeaway
Officially, during a voice call (MODE_IN_CALL or MODE_IN_COMMUNICATION) "the call always receives audio". Only two kinds of app can capture alongside it:
- accessibility services
- privileged (pre-installed) apps holding `CAPTURE_AUDIO_OUTPUT`, which can also capture the call itself

An ordinary app gets silence. The AOSP code is stricter than the docs for accessibility services: during a call, an accessibility service passes only if an accessibility service UID is "on top" (process state TOP through BOUND_FOREGROUND_SERVICE) and it uses VOICE_RECOGNITION or HOTWORD.

### Cited Findings
- **[DOC] App categories.** "Ordinary apps are installed by the user." "Privileged apps come pre-installed on the device. These include the Google Assistant, and all accessibility services." CAMCORDER and VOICE_COMMUNICATION are "privacy-sensitive" sources. — [Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- **[DOC] Voice call plus ordinary app:**
  - "A voice call is active if the audio mode returned by AudioManager.getMode() is MODE_IN_CALL or MODE_IN_COMMUNICATION."
  - "The call always receives audio."
  - "The app can capture audio if it is an accessibility service."
  - "The app can capture the voice call if it is a privileged (pre-installed) app with permission CAPTURE_AUDIO_OUTPUT."
  - "To capture the voice call's uplink (TX), downlink (RX), or both, the app must specify the audio sources MediaRecorder.AudioSource.VOICE_UPLINK or MediaRecorder.AudioSource.VOICE_DOWNLINK, and/or the device AudioDeviceInfo.TYPE_TELEPHONY."
  - Source: [Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input) (last updated 2026-10-16)
- **[DOC] Two ordinary apps.** "Two ordinary apps can never capture audio at the same time." The silenced app receives silence, and `AudioRecordingConfiguration.isClientSilenced()` "Returns true if the audio returned to the client is currently being silenced due to the capture policy." — [Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- **[DOC] Accessibility plus app.** "If the service's UI is on top, both the service and the app receive audio input. This behavior offers functionality like controlling a voice call or video capture with voice commands." — [Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- **[DOC] Android 11 privacy-sensitive flag.** Android 11 added `setPrivacySensitive()` to AudioRecord, MediaRecorder and AAudio: "When setPrivacySensitive() is true, the capture use case is private and even a privileged Assistant cannot capture concurrently." The page documents no Android 12+ changes to these rules. — [Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- **[SRC] Accessibility branch in code (Android 16):**
  - For `mUidPolicy->isA11yUid(currentUid)`, capture is allowed if `!isAssistantOnTop && allowSensitiveCapture && canCaptureIfInCallOrCommunication` (false during MODE_IN_CALL without bypass).
  - It is also allowed `if (isA11yOnTop) { if (source == AUDIO_SOURCE_VOICE_RECOGNITION || source == AUDIO_SOURCE_HOTWORD) allowCapture = true; }`.
  - `isA11yOnTop()` returns true when any accessibility-service UID has a process state between `PROCESS_STATE_TOP` and `PROCESS_STATE_BOUND_FOREGROUND_SERVICE`.
  - Source: [AudioPolicyService.cpp (A16)](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyService.cpp)
- **[SRC] RTT exception.** The current InputMethodService may capture with VOICE_RECOGNITION when an RTT call is active, and assistants get extra allowances when `rttCallActive`. — [AudioPolicyService.cpp (A16)](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyService.cpp)

### Inferences
- [INF] Because an enabled accessibility service is bound by the system (usually BOUND_FOREGROUND_SERVICE importance or higher), "a11y on top" is probably true for most of the time the service runs. That would be why accessibility-based recorders could capture the mic during calls with VOICE_RECOGNITION on Android 10+. This is technically the only non-privileged mic path during a CS call.
- [INF] It is still mic-only. It captures the remote voice only as sound leaving the earpiece or speaker, not the downlink PCM.
- [INF] Using it for call audio is constrained by Play policy (section 5).

### Gaps
- I did not confirm on a device that an accessibility service in a Play app on Android 14–16 still receives non-silent mic audio during a CS call.
- I did not check whether Android 17 (in release notes as of 2026) changed `updateUidStates_l`. The A16 LineageOS branch was the newest source I read.

---

## 3. AudioPlaybackCapture API (Android 10+): which usages it can capture, and whether call audio is excluded

### Takeaway
Through MediaProjection, a normal app can capture only other apps' playback with usage USAGE_MEDIA, USAGE_GAME or USAGE_UNKNOWN, and only when the capture policy allows it. Voice communication playback needs the hidden `CAPTURE_VOICE_COMMUNICATION_OUTPUT` (`signature|privileged|role`). Cellular call downlink is not app playback at all, so this API cannot reach it.

### Cited Findings
- **[DOC] Usage rule.** "…the usage value MUST be AudioAttributes.USAGE_UNKNOWN or AudioAttributes.USAGE_GAME or AudioAttributes.USAGE_MEDIA. All other usages CAN NOT be captured." It also requires:
  - capture policy `ALLOW_CAPTURE_BY_ALL`
  - the `allowAudioPlaybackCapture` manifest attribute true, or unset with targetSdk at least Q
  - the same user profile
  - Source: [AudioPlaybackCaptureConfiguration](https://developer.android.com/reference/android/media/AudioPlaybackCaptureConfiguration) (last updated 2026-08-03)
- **[SRC] Hidden voice-communication permission.** `CAPTURE_VOICE_COMMUNICATION_OUTPUT`: "Allows an application to capture the audio played by other apps with the USAGE_VOICE_COMMUNICATION usage… Not for use by third-party applications. @hide", protection level `signature|privileged|role`. `CAPTURE_MEDIA_OUTPUT` covers privileged capture of other media. — [AOSP AndroidManifest.xml](https://github.com/aosp-mirror/platform_frameworks_base/blob/main/core/res/AndroidManifest.xml)
- **[SRC] Roles that hold these permissions (Android 16-based PermissionController):**
  - `SYSTEM_AMBIENT_AUDIO_INTELLIGENCE` and `SYSTEM_AUDIO_INTELLIGENCE` (both `systemOnly="true"`, `visible="false"`, `static="true"`) hold CAPTURE_AUDIO_OUTPUT, CAPTURE_MEDIA_OUTPUT and CAPTURE_VOICE_COMMUNICATION_OUTPUT. SYSTEM_AUDIO_INTELLIGENCE also holds CONTROL_INCALL_EXPERIENCE and MODIFY_PHONE_STATE.
  - Neither role can be held by a user-installed app.
  - Source: [roles.xml, LineageOS 23.0](https://github.com/LineageOS/android_packages_modules_Permission/blob/lineage-23.0/PermissionController/res/xml/roles.xml)

### Inferences
- [INF] CS calls and modem-handled VoLTE calls run in the modem/DSP audio path (TYPE_TELEPHONY devices), with no app-level AudioTrack. MediaProjection playback capture therefore has nothing to capture. It could only capture VoIP apps' playback, and only if those apps used USAGE_MEDIA, which they normally do not (they use VOICE_COMMUNICATION).
- [INF] The "role" protection flag on these permissions is satisfied only by the hidden system roles above, not by any user-grantable role.

### Gaps
- I did not find a primary doc stating explicitly that "cellular call audio cannot be captured via MediaProjection". This is an inference from the usage rules and the audio architecture.

---

## 4. Telecom: InCallService, ROLE_DIALER, ConnectionService, CallScreeningService, CallRedirectionService, and the call-audio-interception APIs

### Takeaway
None of the public Telecom APIs or user-grantable roles exposes cellular call audio:
- Becoming the default dialer (ROLE_DIALER) gives phone, contacts, SMS, microphone, camera and notifications permission sets plus SYSTEM_ALERT_WINDOW. It does not give CAPTURE_AUDIO_OUTPUT or CALL_AUDIO_INTERCEPTION.
- The call-audio-interception APIs added in API 33 are `@SystemApi` and require `CALL_AUDIO_INTERCEPTION` (`signature|privileged|role`). That permission is granted only to the hidden, system-only `SYSTEM_CALL_STREAMING` role (API 34+).
- The audio-processing call-screening APIs are `@SystemApi` and need CAPTURE_AUDIO_OUTPUT.

### Cited Findings
- **[SRC] ROLE_DIALER grants.** The role definition (`exclusive="true"`, `exclusivity="user"`, requires an InCallService with `BIND_INCALL_SERVICE`) grants `<permission-set name="phone"/>`, `contacts`, `sms`, `microphone`, `camera`, `notifications`, and the app-op `SYSTEM_ALERT_WINDOW`. It contains no CAPTURE_AUDIO_OUTPUT or CALL_AUDIO_INTERCEPTION. — [roles.xml, LineageOS 23.0](https://github.com/LineageOS/android_packages_modules_Permission/blob/lineage-23.0/PermissionController/res/xml/roles.xml)
- **[SRC] Call streaming role.** "A role for the package that streams calls to other devices": `android.app.role.SYSTEM_CALL_STREAMING`, with `minSdkVersion="34"`, `systemOnly="true"`, `static="true"`, `visible="false"`, `defaultHolders="config_systemCallStreaming"`. It grants `CALL_AUDIO_INTERCEPTION` and `RECORD_AUDIO`. — [roles.xml, LineageOS 23.0](https://github.com/LineageOS/android_packages_modules_Permission/blob/lineage-23.0/PermissionController/res/xml/roles.xml)
- **[SRC] Interception APIs in AudioManager:**
  - `isPstnCallAudioInterceptable()` ("Indicates if the platform allows accessing the uplink and downlink audio of an ongoing PSTN call… getCallDownlinkExtractionAudioRecord(AudioFormat) can be used to obtain an AudioRecord for call downlink audio extraction") is `@hide @SystemApi @RequiresPermission(Manifest.permission.CALL_AUDIO_INTERCEPTION)`.
  - `getCallUplinkInjectionAudioTrack(AudioFormat)` is "reserved to system apps with privileged permission", `@SystemApi @RequiresPermission(CALL_AUDIO_INTERCEPTION)`. It throws SecurityException without the permission and needs mode MODE_IN_CALL, IN_COMMUNICATION, CALL_SCREENING, CALL_REDIRECT or COMMUNICATION_REDIRECT.
  - Neither `getCallDownlinkExtractionAudioRecord` nor the interception methods appear on the public AudioManager reference page.
  - Sources: [AudioManager.java (AOSP mirror, main)](https://github.com/aosp-mirror/platform_frameworks_base/blob/main/media/java/android/media/AudioManager.java); [AudioManager reference, updated 2026-08-28](https://developer.android.com/reference/android/media/AudioManager)
- **[DOC] Public audio modes.** `MODE_CALL_SCREENING` (API 30: "Call is connected and audio is accessible to call screening applications…") and `MODE_CALL_REDIRECT` (API 33: "A telephony call is established and its audio is being redirected to another device") are public constants. The capture APIs that go with them are not public. — [AudioManager reference](https://developer.android.com/reference/android/media/AudioManager)
- **[SRC] Native enforcement of call redirection.** audioserver checks CALL_AUDIO_INTERCEPTION for call-redirection outputs ("permission denied: call redirection not allowed") and for VOICE_* input sources. — [AudioPolicyInterfaceImpl.cpp (A16)](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyInterfaceImpl.cpp)
- **[SRC] Audio-processing call screening APIs:**
  - `Call.enterBackgroundAudioProcessing()` lets an app "capture and play audio on the call stream". It is `@hide @SystemApi` and "can only be called by the default dialer app". — [Call.java (A16)](https://github.com/LineageOS/android_frameworks_base/blob/lineage-23.0/telecomm/java/android/telecom/Call.java)
  - `CallScreeningService.CallResponse.Builder.setShouldScreenCallViaAudioProcessing()` is `@hide @SystemApi @RequiresPermission(Manifest.permission.CAPTURE_AUDIO_OUTPUT)`, "only honored if the CallScreeningService shares the same uid as the system dialer app". — [CallScreeningService.java (A16)](https://github.com/LineageOS/android_frameworks_base/blob/lineage-23.0/telecomm/java/android/telecom/CallScreeningService.java)
- **[DOC] Phone-call foreground service type.** `phoneCall` (FOREGROUND_SERVICE_PHONE_CALL) requires MANAGE_OWN_CALLS or ROLE_DIALER, and is for "Continue an ongoing call using the ConnectionService APIs". — [FGS types (updated 2026-10-23)](https://developer.android.com/develop/background-work/services/fgs/service-types)
- **[ANEC/DOC] BCR's approach.** BCR uses `CONTROL_INCALL_EXPERIENCE` so telephony binds its InCallService "without BCR being a wearable companion app, a car UI, or the default dialer". This lets it "access the audio stream without hitting Android 12+'s background microphone access limitations". CAPTURE_AUDIO_OUTPUT then gives it VOICE_CALL. Both are "automatically granted by system app permissions". BCR is "for rooted devices or devices running custom firmware", installed as a system app via Magisk/KernelSU module. Its non-features include "Support for stock, unrooted firmware" and mic+speakerphone workarounds. — [BCR README](https://github.com/chenxiaolong/BCR/blob/master/README.md)

### Inferences
- [INF] A third-party default dialer can control calls and UI, and can use RECORD_AUDIO with a microphone FGS. It still cannot get the downlink, and per section 1 its own mic capture is subject to the same in-call silencing unless it holds a bypass permission.
- [INF] ConnectionService (self-managed) gives audio only for calls the app itself carries (VoIP). It cannot attach to a SIM call placed by the stock dialer.
- [INF] Pixel Call Screen and Google's dialer recording rely on these SystemApis as privileged system apps, which is consistent with Google's 2022 statement that pre-loaded dialers do not need accessibility.

### Gaps
- I did not read the AOSP doc for CallRedirectionService. My understanding, not source-verified, is that it only rewrites a number or handle before placement and has no audio.
- I did not confirm on device whether a third-party default dialer's VOICE_RECOGNITION capture is silenced during its own calls.

---

## 5. AccessibilityService, isAccessibilityTool, and Google Play policy, including the May 2022 call-recording rule

### Takeaway
An accessibility service is the only non-privileged component the audio policy lets keep mic capture during a cellular call. It still has no downlink access. Since 11 May 2022, Play's Accessibility API policy says the API "is not designed and cannot be requested for remote call audio recording". Google described "remote" as recording where the other party is unaware. `isAccessibilityTool` relaxes only disclosure requirements. I found no audio exemption.

### Cited Findings
- **[DOC] The rule and its date.** Google's policy text: "The Accessibility API is not designed and cannot be requested for remote call audio recording." Enforced from 11 May 2022 (announced April 2022). — [Engadget, Apr 2022](https://www.engadget.com/google-is-banning-third-party-call-recording-apps-from-the-play-store-093201443.html); [The Register, 2022-04-22](https://www.theregister.com/2022/04/22/google_banning_thirdparty_callrecording_apps/); [Thurrott](https://www.thurrott.com/mobile/266029/google-play-policy-update-targets-third-party-call-recording-apps)
- **[DOC, secondary] Google's clarifications** as reported by press:
  - "remote in this context refers to call audio recording where the person on the other end is unaware of the recording is taking place."
  - Pre-loaded default dialers are unaffected because "accessibility capability is not required to get access to the incoming audio stream".
  - Source: search snippets summarising [Engadget](https://www.engadget.com/google-is-banning-third-party-call-recording-apps-from-the-play-store-093201443.html) / [Tom's Guide](https://www.tomsguide.com/news/google-killing-call-recording-apps-may-11)
- **[DOC, secondary] isAccessibilityTool.** Only apps whose core function directly supports people with disabilities may set isAccessibilityTool. Other apps must meet prominent disclosure and consent requirements. — Play Accessibility API policy (support.google.com/googleplay/android-developer/answer/10964491; unreachable, DNS failure; content from search snippet)
- **[ANEC] NLL (ACR Phone).** The Play version of ACR Phone no longer uses the Accessibility API for recording. NLL distributes a sideloaded "ACR Phone Helper (APH)", "only required for Android 10 and above" (an APKMirror build dated 2024-06-28). NLL says ACR Phone "can record fine on some phones but may require turning on the loud speaker on others". — [nllapps.com ACR future](https://nllapps.com/apps/acr/future) (snippet; DNS-blocked); [APKMirror APH](https://www.apkmirror.com/apk/nll-apps/acr-phone-helper-aph)
- **[ANEC] GrapheneOS user report.** A user on a GrapheneOS phone recorded only their own voice, and got both sides only on speakerphone. — [GrapheneOS discussion](https://discuss.grapheneos.org/d/2594-call-recording/29)

### Inferences
- [INF] HumSukhan's use is live captioning for a Deaf or hard-of-hearing user, not recording. It could plausibly qualify as an accessibility tool. However, a reviewer may see an accessibility service that captures call audio of a party who has not been told as falling under the "remote call audio recording" prohibition, whether or not audio is stored. It is a high-risk policy area, and the remote party is "unaware" by design.
- [INF] Technically, the audio would still be mic-only (acoustic), so quality depends on speakerphone. Pixel and many OEMs also apply in-call noise suppression and echo cancellation that may attenuate loudspeaker pickup.

### Gaps
- The full current Play Accessibility API policy text and its revision date could not be fetched because support.google.com would not resolve. I could not verify whether 2025–2026 revisions changed the call-recording language.
- I found no Google statement on whether live, non-stored captioning counts as "recording" under the policy.

---

## 6. Other Google Play policies: phone/call-log permissions, foreground service types, Data safety, sensitive permissions

### Takeaway
- Mic capture in the background requires a `microphone`-type FGS with FOREGROUND_SERVICE_MICROPHONE plus RECORD_AUDIO.
- That FGS must be started while the app is visible, or under a while-in-use exemption.
- Starting it from BOOT_COMPLETED is blocked.
- `phoneCall` FGS is limited to ROLE_DIALER or MANAGE_OWN_CALLS apps.
- Play requires an FGS type declaration for these types. I could not fetch the declaration page.

### Cited Findings
- **[DOC] Microphone FGS.** Type `microphone`, permission `FOREGROUND_SERVICE_MICROPHONE`, constant `FOREGROUND_SERVICE_TYPE_MICROPHONE`. Prerequisite: RECORD_AUDIO granted. "The RECORD_AUDIO runtime permission is subject to while-in-use restrictions… you cannot create a microphone foreground service while your app is in the background and you cannot launch a microphone foreground service from a BOOT_COMPLETED receiver, with a few exceptions." — [Foreground service types (updated 2026-10-23)](https://developer.android.com/develop/background-work/services/fgs/service-types)
- **[DOC] phoneCall FGS.** Requires MANAGE_OWN_CALLS or ROLE_DIALER. "Apps that target Android 15 or higher are not allowed to launch a phone call foreground service from a BOOT_COMPLETED broadcast receiver." — [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- **[DOC] While-in-use rule.** If an app starting a microphone FGS is in the background, "the system sees that your app doesn't currently have the required permissions, and it throws a SecurityException". Exemptions include:
  - "A system component starts the service."
  - "The service starts by interacting with a notification."
  - a PendingIntent "sent from a different, visible app", among others
  - Source: [Restrictions on starting FGS from background (updated 2026-10-23)](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)

### Inferences
- [INF] Practical consequence: HumSukhan must start its mic FGS from a visible activity, or from a notification or quick-settings tap, before or when the call starts. A PHONE_STATE broadcast received in the background cannot launch it.
- [INF] Once a mic FGS is running, it can keep capturing while the dialer is in the foreground. Per section 1, though, audio policy silences it during MODE_IN_CALL anyway, unless it is an accessibility service using VOICE_RECOGNITION.

### Gaps
- I could not fetch the Play Console FGS declaration policy (answer/13392821), the Permissions and APIs that Access Sensitive Information policy (answer/9888170), or the Call Log/SMS policy (support.google.com DNS failure). Their 2025/2026 revision text and dates are unverified.
- I did not research Data safety form specifics.

---

## 7. Android 14 / 15 / 16 (and 17) changes affecting call audio and in-call mic

### Takeaway
I found no change in Android 14–16 that opens call audio to third parties. The direction is the reverse:
- Android 14 adds the system-only SYSTEM_CALL_STREAMING role with CALL_AUDIO_INTERCEPTION.
- Hidden system "audio intelligence" roles hold all the capture permissions.
- A new privileged-only `BYPASS_CONCURRENT_RECORD_AUDIO_RESTRICTION` permission is behind a feature flag.
- The FGS rules (typed FGS required on Android 14; BOOT_COMPLETED limits on Android 15) tightened background mic.

### Cited Findings
- **[SRC]** SYSTEM_CALL_STREAMING role: minSdkVersion 34, system-only. — [roles.xml (A16)](https://github.com/LineageOS/android_packages_modules_Permission/blob/lineage-23.0/PermissionController/res/xml/roles.xml)
- **[SRC]** BYPASS_CONCURRENT_RECORD_AUDIO_RESTRICTION is `signature|privileged` and feature-flagged ("can continue to record while a voice call is active"). — [AOSP AndroidManifest.xml](https://github.com/aosp-mirror/platform_frameworks_base/blob/main/core/res/AndroidManifest.xml); flag used in [AudioPolicyInterfaceImpl.cpp](https://github.com/LineageOS/android_frameworks_av/blob/lineage-23.0/services/audiopolicy/service/AudioPolicyInterfaceImpl.cpp)
- **[DOC]** Android 15+ targets cannot start phoneCall/microphone FGS from BOOT_COMPLETED. — [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- **[DOC] BCR on Android 12+.** BCR notes "Android 12+'s background microphone access limitations", which it avoids only through the system-bound InCallService. — [BCR README](https://github.com/chenxiaolong/BCR/blob/master/README.md)

### Inferences
- [INF] Google keeps adding call-audio capability only behind system-only roles, presumably for Pixel Call Screen and recording, OEM call streaming, and on-device AI. There is no signal of a third-party path.

### Gaps
- I did not read the Android 16 and Android 17 behaviour-changes pages in full. The A16 page was downloaded but not mined for audio items, so call-audio-specific changes in those releases are unverified.

---

## 8. Developer evidence from call recorders (Cube ACR, ACR Phone/NLL, BCR, Google Dialer)

### Takeaway
- After Android 10, unrooted third-party recorders captured the remote side only through accessibility-service mic capture, usually needing speakerphone. Play banned that use in May 2022, after which NLL moved it to a sideloaded helper.
- Clean downlink capture is available only to root/system-installed apps (BCR via CAPTURE_AUDIO_OUTPUT and VOICE_CALL) or to OEM and Google pre-installed dialers.

### Cited Findings
- **[DOC/ANEC] BCR:**
  - Supports Android 9+ and "stereo recording (separate uplink and downlink channels)", which is "only known to work on Pixel devices".
  - Requires root (Magisk/KernelSU module) or custom firmware.
  - Gets CAPTURE_AUDIO_OUTPUT and CONTROL_INCALL_EXPERIENCE as system-app permissions.
  - Source: [BCR README](https://github.com/chenxiaolong/BCR/blob/master/README.md)
- **[ANEC] NLL.** NLL's sideloaded APH is needed for Android 10+, and speakerphone may be required on some phones. — [nllapps.com](https://nllapps.com/apps/acr/future) (snippet); [APKMirror](https://www.apkmirror.com/apk/nll-apps/acr-phone-helper-aph)
- **[DOC, secondary]** Pre-loaded dialers do not need accessibility to access the incoming audio stream (Google, 2022). — [Engadget](https://www.engadget.com/google-is-banning-third-party-call-recording-apps-from-the-play-store-093201443.html)
- **[ANEC]** One user got only their own voice unless on speakerphone. — [GrapheneOS forum](https://discuss.grapheneos.org/d/2594-call-recording/29)

### Inferences
- [INF] Cube ACR is widely reported to rely on an accessibility "connector" and the mic (possibly through a sideloaded helper, like NLL). I did not verify this from a primary source here.

### Gaps
- I found no primary-source statement from Cube ACR, and no measured downlink quality (for example word error rate) from mic-based capture.

---

## 9. Official or new APIs (2024–2026) giving third-party captioning apps call audio or call transcripts

### Takeaway
I found no public API, as of Oct 2026, that gives a third-party app call audio or system-generated call transcripts. Call captioning exists only as system features:
- Google Live Caption for calls, on Pixel and some devices
- OEM features
- system-only roles

US captioning apps (Rylo/Nagish, InnoCaption, CaptionCall, CaptionMate) work by routing calls through their own telephony service (FCC-funded IP CTS) rather than through an Android API.

### Cited Findings
- **[DOC, snippet]** Google's Live Caption help page says Live Caption can caption "phone calls, video calls, and audio messages", processed on-device. Urdu did not appear in the excerpted language list (Hindi did). — [Live Caption help](https://support.google.com/accessibility/android/answer/9350862) (snippet only; DNS-blocked)
- **[ANEC, 2020]** Android 11-era code had call captions announce to the other party: "Hi, the person you are about to speak with has call captions turned on." — [XDA](https://www.xda-developers.com/google-live-caption-phone-call/)
- **[SRC]** The audio "intelligence" roles (`SYSTEM_AUDIO_INTELLIGENCE`, `SYSTEM_AMBIENT_AUDIO_INTELLIGENCE`) are `systemOnly`, hidden, and static. They are the platform's channel for on-device AI over audio, including call audio, and are not available to Play apps. — [roles.xml (A16)](https://github.com/LineageOS/android_packages_modules_Permission/blob/lineage-23.0/PermissionController/res/xml/roles.xml)
- **[DOC, secondary]** Rylo (formerly Nagish) captions calls with ASR and lets users keep their existing number. "The person on the other end doesn't need the app installed." InnoCaption uses "one-number call forwarding". These services are reimbursed through a US federal fund. — [Rylo blog](https://rylo.com/post/innocaption-vs-captioncall); [Rylo caption call apps](https://rylo.com/post/caption-call-apps)

### Inferences
- [INF] The only Play-compliant, no-root architectures that caption the remote party with no change on their side are:
  - (a) network-side: route or forward the call through a server or SIP/IP-CTS-style service, possibly via a conference merge or carrier forwarding
  - (b) acoustic: speakerphone plus mic, which on AOSP is silenced during MODE_IN_CALL for ordinary apps, so in practice it needs a second device or an accessibility-service approach that carries policy risk
  - (c) prompting the user to turn on the system Live Caption where supported, though Urdu support was not shown

### Gaps
- I did not reach the Android 16/17 release notes for new accessibility or telephony transcript APIs. Search returned nothing indicating such an API, which is weak negative evidence.
- I did not confirm Urdu support or availability in Pakistan for Live Caption or Samsung call captions (Samsung "Live Translate"/"Transcript Assist").
