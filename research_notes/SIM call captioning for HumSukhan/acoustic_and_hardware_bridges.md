# Acoustic and hardware bridges: getting the remote caller's voice from an ordinary Android SIM call to a captioning engine (as of Oct 2026)

Research environment note (2026-10-25): several primary sites failed DNS resolution in this sandbox (nllapps.com, cubeacr.app, docs.espressif.com, hamiltoncaptel.com, sipfront.com). For those, the claims below come from search-engine snippets of those pages, and the notes say so. Two GitHub READMEs (ESP-IDF `hfp_hf` example, BCR) were downloaded directly via raw.githubusercontent.com and read in full. The Android "Sharing audio input" page was fetched directly.

Each finding is labelled **[Demonstrated]** (a named device, product or shipping software shows it working), **[Documented]** (platform docs or spec state it, but no field report seen) or **[Theoretical]** (inferred, not shown).

## 1. Speakerphone + the same phone's microphone (HumSukhan records the mic during its own SIM call)

### Takeaway
On Android 10+ an ordinary third-party app is very unlikely to get any mic audio during a cellular call. The platform gives the call priority, and the call's capture is privacy-sensitive, so other apps get silence. The one documented exception is an app running as an **accessibility service**, which is how Cube ACR / NLL-style recorders still capture calls (plus speakerphone) on stock phones. Even when capture is allowed, results depend on the device: the phone's echo canceller is designed to remove the far-end voice from the mic signal, and recorder developers report that this works against them. This is the riskiest route, but it is the only zero-hardware one, so it is worth a device-matrix test using the accessibility-service path.

### Cited Findings
- Android 10+ concurrent-capture rules: "A voice call is active if the audio mode returned by `AudioManager.getMode()` is `MODE_IN_CALL` or `MODE_IN_COMMUNICATION`." During a call: "The call always receives audio." "The app can capture audio if it is an accessibility service." "The app can capture the voice call if it is a privileged (pre-installed) app with permission `CAPTURE_AUDIO_OUTPUT`." [Documented] — [Android Developers: Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- The same page says "Two ordinary apps can never capture audio at the same time". `VOICE_COMMUNICATION` and `CAMCORDER` are "privacy-sensitive" sources. "If one of the apps is privacy-sensitive, it receives audio and the other app gets silence even if it has a UI on top." The page does not literally say "ordinary apps get silence during a call", but that follows from the rules above. [Documented] — [Android Developers: Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- Accessibility-service capture: "If the service's UI is on top, both the service and the app receive audio input. If the service is not on top, this case is treated like the ordinary two-app case." So an accessibility service with a visible overlay, such as a caption overlay, is the documented way to share the mic with the call. [Documented] — [Android Developers: Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- Android 11 added `setPrivacySensitive()`: "When `setPrivacySensitive()` is `true`, the capture use case is private and even a privileged Assistant cannot capture concurrently... `VOICE_COMMUNICATION` is private by default." HumSukhan should check at runtime whether it is being silenced, using `AudioManager.AudioRecordingCallback` and `AudioRecordingConfiguration.isClientSilenced()`. [Documented] — [Android Developers: Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- An AOSP audio-policy commit says that when the audio mode is IN_COMMUNICATION, only the app that owns the audio mode may capture. [Documented, AOSP fork mirror] — [OmniROM gerrit mirror of frameworks/av "audio policy: more concurrent capture fixes"](https://gerrit.omnirom.org/plugins/gitiles/android_frameworks_av/+/c21d5699004beed1b406178beff2da7e7fd5aaa7)
- The AOSP HAL guidance (via search snippet) says that during a call, device selection and pre-processing priority must favour the voice call over app input streams. [Documented] — [source.android.com concurrent capture (pt-BR)](https://source.android.com/devices/audio/concurrent?hl=pt-br)
- NLL (ACR developer), via search snippet only because the site failed to load: Android 10 "completely blocks call recording. Even on loud speaker!" The ACR Phone release notes say recordings "will be silent on Android 10+" without its helper app (APH, ACR Phone Helper, required since May 2022). [Demonstrated, developer statement, unspecified devices] — [NLL: Android 9/10 page](https://nllapps.com/apps/acr/android9.htm), [NLL: VoIP recording](https://nllapps.com/apps/cb/voip-call-recording.htm), [NLL: Future of ACR](https://nllapps.com/apps/acr/future)
- NLL on echo cancellation (snippet): the MIC audio source with gain raised to 10–14 "may help capturing other party's voice on some phones such as Huawei and Pixel where echo cancellation algorithm is not aggressive", and "turning loud speaker on while in a call would work on most phones." This is the developer naming AEC as the thing that removes the remote voice from mic captures. [Demonstrated, developer statement, vendor names only] — [NLL Android 9 page](https://nllapps.com/apps/acr/android9.htm)
- Cube ACR FAQ and Play listing (snippets; site failed to load): recording depends on the "Cube ACR App Connector" accessibility service being on. For Android 10–14 it recommends the audio source "voice recognition (software)" with "force in-communication mode", or "voice call (software)" as a fallback. "If ... you hear only yourself on playback, try changing the recording source ... or use auto-on speaker mode." [Demonstrated, developer statement] — [Cube ACR FAQ](https://cubeacr.app/faq.html), [APKMirror Cube ACR listing](https://www.apkmirror.com/apk/cube-systems/call-recorder-cube-acr/)
- A 2025 Yahoo Tech hands-on found Cube ACR "was unable to record calls on any Android device out of the box due to a known issue" until the reviewer installed the **Cube ACR Helper** app. After that, "I was able to record phone calls on Android 14 and 15 devices." No device models were named in the snippet. [Demonstrated, Android 14/15, unnamed devices] — [Yahoo Tech](https://tech.yahoo.com/articles/google-makes-difficult-record-calls-155834200.html)
- BCR, the best-known open-source recorder, refuses to support unrooted stock firmware. It lists "Workarounds for devices that don't support the VOICE_CALL audio source (eg. using microphone + speakerphone)" as a non-feature, and it needs `CAPTURE_AUDIO_OUTPUT` (a system permission) to read `VOICE_CALL`/`VOICE_DOWNLINK`/`VOICE_UPLINK`. [Documented] — [BCR README](https://github.com/chenxiaolong/BCR/blob/master/README.md)
- Google Play policy (effective 11 May 2022) forbids using the Accessibility API for remote call recording. Only apps "built to directly support people with disabilities" may declare `isAccessibilityTool`. Default/pre-loaded dialers are exempt. Reporting at the time was unclear on how strictly it would be enforced. — [Engadget](https://www.engadget.com/google-is-banning-third-party-call-recording-apps-from-the-play-store-093201443.html), [MobileSyrup](https://mobilesyrup.com/2022/04/22/google-introduces-new-play-store-policy-banning-third-party-call-recording-apps/), [Thurrott](https://www.thurrott.com/mobile/266029/google-play-policy-update-targets-third-party-call-recording-apps)
- Google's own Live Transcribe cannot run on the same phone during a cellular call. Users report it says the microphone is in use by another app, even on speakerphone. A HearingTracker user claims Live Transcribe worked on a Pixel during calls "using BT or speaker". That is anecdotal and contradicts the first report. — [SlashGear](https://www.slashgear.com/1479092/how-to-use-live-transcribe-android/), [HearingTracker forum](https://forum.hearingtracker.com/t/phonak-hearing-aids-pixel-phones-and-captioning-during-bt-phone-calls/103263)
- `VOICE_COMMUNICATION` is "similar to MIC but adds acoustic echo cancellation", and the processing is device-specific (Vuzix audio docs). — [Vuzix audio subsystem doc](https://support.vuzix.com/docs/audio-subsystem-2)

### Inferences
- [Theoretical] HumSukhan is genuinely an accessibility tool for Deaf/HoH users, so it is one of the few apps that could legitimately declare `isAccessibilityTool` and capture through an accessibility service with its caption overlay on top. That is the documented path that shares the mic during a call. Play policy still bans using it to *record* calls, so the app should caption live, store nothing (or only transcripts with consent), and disclose clearly. Whether Play review accepts this is a policy question to verify.
- [Theoretical, physics/AEC] Even when capture is allowed, what HumSukhan receives depends on where Android taps the signal. If the app receives the raw/`UNPROCESSED`/`VOICE_RECOGNITION` mic path, the speakerphone's far-end voice is acoustically present and loud, so transcription is possible. If it shares the call's AEC-processed `VOICE_COMMUNICATION` path, the far-end voice is deliberately cancelled. NLL's and Cube's advice ("MIC/voice recognition source, high gain, speaker on") fits this. Expect per-OEM variability: Samsung, Xiaomi/Redmi, Oppo/Vivo/Realme and Infinix/Tecno are the dominant Android brands in Pakistan and are untested here.
- [Theoretical] Speakerphone audio is decoded AMR-NB/AMR-WB/EVS played through a small loudspeaker and re-captured, so ASR accuracy will be below a clean digital feed. Urdu ASR is already harder.
- The "helper app" pattern used by NLL and Cube (a separate APK, often sideloaded, possibly targeting an old SDK to keep legacy behaviour) suggests that from Android 14/15 the main Play-distributed APK cannot do this alone. This is unverified; see Gaps.

### Gaps
- Could not load the NLL and Cube ACR pages directly, so there is no per-device list (model + Android version) of where speaker+mic capture gets the far-end voice.
- What exactly the Cube ACR Helper / ACR Phone Helper do technically (e.g. targetSdk downgrade, accessibility, Shizuku) was not confirmed.
- No Android 15/16/17 documentation was found that changes the concurrent-capture rules. The developer page above shows no 2025–2026 changes. Not confirmed for Android 16/17 specifically.
- No academic measurement of how much far-end speech survives in shared mic captures on Android was found.

## 2. Second device acoustic capture (speakerphone on phone A, HumSukhan on phone/tablet B)

### Takeaway
This route works on every phone today and needs no hacks. It is the established Deaf/HoH workaround with Google Live Transcribe, so HumSukhan already supports it in its existing conversational/live-caption mode. The costs are that it needs a second device, a speakerphone in a quiet room (no privacy), and quality limited by the speaker loudness and room acoustics.

### Cited Findings
- SlashGear describes this workaround: take the call on one phone on speakerphone and run Live Transcribe on a second Android device, because Live Transcribe cannot use the mic on the phone that is in the call. [Demonstrated, generic] — [SlashGear: How to use Live Transcribe](https://www.slashgear.com/1479092/how-to-use-live-transcribe-android/)
- A Mayo Clinic Connect thread on "voice to text on cell phone" points users to a relay caption service (Innocaption) rather than acoustic capture. That service is US-only. — [Mayo Clinic Connect](https://connect.mayoclinic.org/comment/831038)
- Built-in OS options: Live Caption on Pixel and Samsung can caption phone calls directly. It is a system component, so it is not bound by the third-party restrictions. One XDA report says it announces to the other participants that the call is being captioned. — [Samsung support](https://www.samsung.com/us/support/answer/ANS10003704/), [Technipages](https://www.technipages.com/how-to-use-live-caption-to-transcribe-phone-calls/), [XDA](https://www.xda-developers.com/google-live-caption-phone-call/)

### Inferences
- [Theoretical, but low risk] Latency equals HumSukhan's normal streaming ASR latency plus about 0 ms for acoustics (speaker to mic is negligible). Quality should match HumSukhan's in-person mode at 20–50 cm from a phone speaker at maximum volume.
- No AEC problem arises on device B, because B is not in a call. B should use the `VOICE_RECOGNITION` or `UNPROCESSED` source and turn off noise suppression that might treat narrowband phone speech as noise.
- Practical in Pakistan: many households have an older spare Android phone, so the hardware cost can be zero. The downsides are a public speakerphone, background noise (traffic, fans, generators), and the user juggling two devices.
- Product idea [Theoretical]: a HumSukhan "Phone call (speaker) mode" on device B, tuned for 300–3400 Hz / 50–7000 Hz phone-band audio with an optional bandpass and a gain boost. Use language-ID tuned for Urdu/English code-switching.

### Gaps
- No published measurement of ASR word error rate on speakerphone-replayed cellular audio, and none for Urdu.
- No first-person account of Deaf users in Pakistan doing this was found. US/UK evidence is anecdotal or how-to articles.

## 3. Bluetooth: a second device acting as the phone's HFP hands-free unit (receives the call downlink digitally over SCO)

### Takeaway
Technically this is the cleanest route without root. The phone treats the device like any Bluetooth headset or car kit, so the stock dialer is untouched. The device gets the remote voice as digital PCM (CVSD 8 kHz narrowband, or mSBC 16 kHz wideband) with no echo cancellation applied against it. ESP32 (ESP-IDF `hfp_hf` example) and Linux (BlueZ + oFono / BlueALSA / PipeWire) both implement the HF role in open source. A stock second Android phone generally cannot do this, because `BluetoothHeadsetClient` is a hidden/System API. The catch: once call audio is on the Bluetooth device, the phone's own mic and earpiece are bypassed. The dongle must also supply the uplink (a mic, or HumSukhan TTS injected into the call) and must send the PCM somewhere for ASR.

### Cited Findings
- Role model: phones are the Audio Gateway (AG), and a headset/car kit is the Hands-Free (HF) unit. A connection needs one of each. PulseAudio "supports HFP only in the hands-free unit role" and needs oFono for HFP, meaning a Linux box can connect to a phone as its hands-free. [Documented, old: 2012–2016 era docs] — [TDE Bluez handsfree doc](https://git.trinitydesktop.org/cgit/tdebluez/plain/doc/en/handsfree.docbook), [BlueALSA wiki: HFP and HSP devices](https://github.com/arkq/bluez-alsa/wiki/Using-BlueALSA-with-HFP-and-HSP-Devices)
- Known Linux pitfalls: a 2016 oFono HF-role thread reports SCO being rejected ("Agent not registered") when no audio agent is registered. A 2022 PipeWire issue shows HFP HF via oFono working but the stream tagged "Multimedia" instead of "Communication". Another PipeWire issue reports "100% static" when a phone was connected to a desktop as headset. — [lore.kernel.org HFP HF reject SCO](https://lore.kernel.org/all/5745BD55.3030108@gmail.com/T/), [PipeWire #2531](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/2531), [PipeWire #1841](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/1841)
- Sipfront (a test-automation company) published "Automating calls on real mobile devices with Bluetooth HFP on a Raspberry Pi" in March 2025. The Pi acts as HF to real mobile phones to place and receive calls and handle audio. I could not load the page (DNS failure), so I know only the title/snippet, not the stack, codec or phone models. [Demonstrated per title; details unverified] — [Sipfront blog](https://sipfront.com/blog/2025/03/automating-calls-on-real-mobile-devices-with-bluetooth-hfp-on-a-raspberry-pi/)
- ESP-IDF `hfp_hf` example (read directly): supported targets are **ESP32** (classic) and **ESP32-S31**. It is "designed to run on commonly available ESP32 ... development boards, e.g. ESP32-DevKitC", connected "to an AG running on a smartphone". The HF can answer/reject incoming calls and control volume. [Documented + official example] — [ESP-IDF hfp_hf README](https://github.com/espressif/esp-idf/blob/master/examples/bluetooth/bluedroid/classic_bt/hfp_hf/README.md)
- ESP-IDF audio data paths: "PCM" sends SCO audio from the controller to GPIO pins for an I2S codec, bypassing the host (CVSD only, hardware codec). "vHCI" routes audio "through the Bluedroid to the Application layer", and with Wideband Speech on, "codec job is done in the Bluedroid and mSBC is being used." The codec (CVSD vs mSBC) is negotiated with the AG during service-level connection. ESP32-S31 supports only HCI. For HumSukhan, vHCI + mSBC is the configuration that gives the app 16 kHz PCM it can forward. [Documented] — [ESP-IDF hfp_hf README](https://github.com/espressif/esp-idf/blob/master/examples/bluetooth/bluedroid/classic_bt/hfp_hf/README.md)
- ESP-IDF API exposes `esp_hf_client_connect_audio(remote_bda)` and an audio-state enum including `ESP_HF_AUDIO_STATE_CONNECTED_MSBC`. — [ESP-IDF v4.4 HFP Client API](https://docs.espressif.com/projects/esp-idf/en/v4.4.8/esp32/api-reference/bluetooth/esp_hf_client.html), [SourceVu esp_hf_audio_state_t](https://sourcevu.sysprogs.com/espressif/esp-idf/symbols/esp_hf_audio_state_t/ESP_HF_AUDIO_STATE_CONNECTED_MSBC)
- Community ESP32 component "a2dpSinkHfpClient" advertises an HFP client with mSBC wideband. [Documented, third-party] — [Espressif component registry: walinsky/a2dpsinkhfpclient](https://components.espressif.com/components/walinsky/a2dpsinkhfpclient/versions/0.2.2/examples/hfp)
- Android as HF: `android.bluetooth.BluetoothHeadsetClient` is the "API to control Hands Free Profile (HFP role only)". It is `@hide` in Android 9 and a System API in newer sources, so ordinary Play apps cannot use it. The native HF-client stack exists in AOSP (`btif_hf_client.cc`), mainly for Android Automotive. — [Android 9 source (yawk.at)](https://code.yawk.at/android/android-9.0.0_r35/android/bluetooth/BluetoothHeadsetClient.java), [AICP mirror, modules/Bluetooth](https://git.aicp-rom.com/packages_modules_Bluetooth.git/plain/framework/java/android/bluetooth/BluetoothHeadsetClient.java), [AOSP btif_hf_client.cc](https://android.googlesource.com/platform/system/bt/+/e8bbf5b0889790cf8616f4004867f0ff656f0551/btif/src/btif_hf_client.cc)
- Codec quality: Android docs say LE Audio's LC3 replaces mSBC for HFP voice and allows up to 32 kHz in/out. Classic Bluetooth "reduces audio quality when Bluetooth microphones are used". — [Android Developers: BLE Audio overview (de)](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/overview?hl=de)
- Commercial precedent: Bluetooth "recording headsets" and dongles pair as HF and record both sides of mobile calls. Bluewire (2015, crowdfunded) recorded "both sides of a conversation" even while the call was on a different headset or car system. KJB D1450 "uses Bluetooth and handsfree technology to automatically record your mobile phone calls" (about USD 137). [Demonstrated, consumer products, availability uncertain] — [TechCrunch: Bluewire](https://techcrunch.com/2015/01/27/the-bluewire-is-a-bluetooth-headset-that-can-record-your-calls/amp/), [123SecurityProducts KJB D1450](https://www.123securityproducts.com/audio/recording-devices/audio-standard/d1450.html), [Harvey Norman Vimel hidden recorder](https://www.harveynorman.com.au/vimel-mobile-phone-calls-hidden-recorder.html)

### Inferences
- [Theoretical, high confidence] The phone's dialer UI stays fully usable, as with any car kit. The user dials and answers normally, and audio routes to the HF device. Android lets the user switch audio back to earpiece/speaker from the in-call screen.
- [Theoretical] Getting PCM from the HF device to the captioning engine has three options:
  - (a) Linux/Raspberry Pi runs ASR locally (e.g. Whisper small/Vosk Urdu) or sends to cloud, then sends text to the phone over Wi-Fi/LAN/BLE.
  - (b) ESP32 streams 16 kHz PCM (about 256 kbit/s raw) to HumSukhan on the same phone over Wi-Fi or BLE. ESP32 BT-Classic eSCO plus Wi-Fi coexistence shares one 2.4 GHz radio and is a known stress case (unverified here). An ESP32 with USB/UART to a second phone or PC is the simpler variant.
  - (c) The dongle does cloud ASR over Wi-Fi itself, and HumSukhan polls the text.
- [Theoretical] Uplink matters for the user. When audio goes to the HF, the phone's mic is not used. The dongle needs a MEMS mic (INMP441-class I2S, very cheap) for Deaf users who speak. Alternatively, HumSukhan could send its TTS audio to the dongle and inject it into the SCO uplink. That would give "type-to-speak in a real SIM call" without root, a significant extra feature this route uniquely enables.
- [Theoretical] Raw downlink audio is clean: no room noise and no AEC against it. mSBC (16 kHz) is only available if both phone and HF negotiate WBS, and the network leg is often AMR-NB 8 kHz anyway (VoLTE AMR-WB/EVS gives wideband). ASR quality should be clearly better than acoustic routes.
- [Theoretical] A second stock Android phone cannot be the HF without root or custom ROM, since `BluetoothHeadsetClient` is System API. Some Android TV/automotive builds enable the HF client, but that is not a consumer path.

### Gaps
- No confirmed 2025–2026 report of a specific Android phone model + ESP32 `hfp_hf` with mSBC delivering downlink PCM to app code end-to-end. The Espressif docs page failed to load, so the exact incoming-data callback name (I expect `esp_hf_client_register_data_callback`, not verified) is unconfirmed.
- Current PipeWire (1.x) native-backend support for HFP **HF** role, without oFono, is unconfirmed.
- Sipfront's stack and phone models are unverified (page did not load).
- ESP32 Wi-Fi + eSCO coexistence latency/dropout data was not found.

## 4. Wired: 3.5 mm splitters, USB-C audio adapters, tapping the headset output

### Takeaway
This works for phones that route call audio to a wired headset, which is standard Android behaviour, and purpose-built taps exist (JK Audio CellTap: caller on one channel). The tapped analog signal goes into a second device's mic input, or a USB audio interface feeding a PC or second phone. Most new phones have no jack, so a USB-C-to-3.5 mm DAC dongle is needed. It is clunky, needs a second capturing device, and the user cannot hear the call through the same path unless a splitter is used. That last point matters little for Deaf users.

### Cited Findings
- JK Audio CellTap 4C: "stereo recording output with mic signal on left channel and caller on right channel". It is passive (no power) and lets users "maintain a live conversation while simultaneously routing the audio to a recording system". About USD 113. [Demonstrated, commercial product] — [SCMS listing: JK Audio CellTap 4C](https://www.scmsinc.com/jk-audio-celltap4c-celltap-4c-wireless-phone-audio-tap-adapter.html)
- Generic TRRS splitters and the Joby Wavo splitter are sold for recording smartphone audio while listening on headphones. [Demonstrated, generic products] — [Joby Wavo splitter](https://joby.com/us-en/wavo-3-5mm-cable-splitter-jb01736-0ww/), [Sescom iPhone TRRS-to-mic cable (B&H)](https://www.bhphotovideo.com/c/product/813376-REG/sescom_iphone_ln2mic_1_trrs_to.html/specs)
- Forum reports of phone-to-PC tap attempts giving "only a buzz or silence" are attributed to level mismatch (mic-in too sensitive; use line-in). — [Tom's Guide forum](https://forums.tomsguide.com/threads/how-could-i-record-audio-from-a-3-5mm-audio-output-into-a-3-5mm-audio-mic-input.380848/)

### Inferences
- [Theoretical] A headset-out tap contains the downlink plus sidetone (a little of the user's own voice), with no AEC applied to the downlink, so quality is close to the Bluetooth route.
- [Theoretical] Second-device practicality: feeding a TRRS mic input on phone B requires attenuation (headphone level to mic level) and a TRRS adapter. Phone B captures it as an ordinary wired mic, so HumSukhan on B works unchanged. Costs in Pakistan would be a few hundred PKR for cables, plus a USB-C DAC dongle if phone A has no jack (prices not sourced).
- [Theoretical] Android USB audio routing: when a USB audio class headset is attached, telephony audio normally routes to it. A USB "audio interface" dongle that loops output to another host is not a common consumer product.
- The CellTap-style passive tap is the most proven off-the-shelf wired solution. Its availability in Pakistan is unknown.

### Gaps
- No Android-specific report was found confirming which current phones (Samsung, Xiaomi, etc.) route cellular call audio to USB-C DAC dongles and which to built-in only. It is generally expected to work, but not sourced here.
- Pakistan prices for CellTap or USB-C DACs were not found.

## 5. Hearing aid streaming: ASHA and LE Audio (HAP/LC3), emulating a hearing aid

### Takeaway
Android streams phone calls to ASHA and LE Audio hearing aids. A device that emulated an ASHA hearing aid (open spec over BLE L2CAP CoC) or an LE Audio unicast sink would receive call audio digitally. However, no open-source receiver implementation was found, and LE Audio sink development needs specific silicon (e.g. Nordic nRF5340-class) and a lot of work. For HumSukhan this is a research curiosity, not a near-term path. Classic HFP (section 3) gives the same result more simply.

### Cited Findings
- ASHA was published by Google (with GN Hearing) in 2018: "Audio Streaming for Hearing Aids (ASHA) on Bluetooth Low Energy Connection-Oriented Channels". The spec covers pairing, topology, architecture and requirements. — [Android Developers Blog, Aug 2018](https://android-developers.googleblog.com/2018/08/streaming-support-spec-for-hearing-aids_16.html)
- ASHA is described as an open specification (Google, GN Hearing, Cochlear). It first shipped on Pixel 3/3a with Android 10. — [Android Central](https://www.androidcentral.com/android-10-supports-direct-streaming-hearing-aids)
- Android LE Audio: the Hearing Access Profile "lets users use their hearing aids for phone calls and VoIP applications", and LC3 replaces mSBC for HFP voice. — [Android Developers: BLE Audio overview](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/overview?hl=de)
- LE Audio speakers can take calls as hands-free speakerphones. LC3 was released by the Bluetooth SIG on 15 Sep 2020. — [TechHive](https://www.techhive.com/article/2084225/what-is-bluetooth-le-audio-a-minor-wireless-audio-improvement.html), [Feasycom](https://www.feasycom.com/le-audio-development-history/)

### Inferences
- [Theoretical] An ASHA emulator would need to look like a hearing aid to Android's pairing flow, which is a filtered device type. Bluetooth SIG qualification is needed for any commercial product. LE Audio phone support in Pakistan's mid/low-range phones is uneven.
- [Theoretical] Auracast/broadcast does not carry phone calls.

### Gaps
- No open-source ASHA receiver or LE Audio telephony sink project was found. The codec (G.722 at 16 kHz is my recollection for ASHA) is unconfirmed here.
- No info found on whether Android requires hearing-aid vendor allow-listing for ASHA.

## 6. Smartwatch, companion and car approaches

### Takeaway
Nothing specific was found. These are variations of section 3 (Bluetooth HF) or system-privileged companions. A Wear OS watch taking calls acts like a Bluetooth HF device, and third-party watch apps do not get the call audio stream. Car kits / Android Auto are HFP HF devices (section 3).

### Cited Findings
- BCR notes that `CONTROL_INCALL_EXPERIENCE` lets the telephony service bind an `InCallService` "without BCR being a wearable companion app, a car UI, or the default dialer". This confirms wearable/car companions have privileged call *control* hooks, but audio capture still needs `CAPTURE_AUDIO_OUTPUT`. — [BCR README](https://github.com/chenxiaolong/BCR/blob/master/README.md)

### Inferences
- [Theoretical] A cheap Bluetooth car kit or speakerphone could be the acoustic source for the second-device route (2), but adds nothing over the phone's own speaker.

### Gaps
- No Wear OS call-audio capture documentation was searched in depth (tool budget).

## 7. Existing commercial captioned-phone hardware (CapTel, CaptionCall, ClearCaptions) and pairing with mobiles

### Takeaway
US captioned-phone hardware is landline/IP-based, FCC-funded IP CTS. Captions are US-only, English (plus Spanish on some), and limited to registered users. No evidence was found that CapTel or ClearCaptions phones pair with a cell phone over Bluetooth to caption SIM calls; at least one retailer says the CapTel 2400iBT cannot. These are not usable in Pakistan. Their mobile apps use a separate number/relay model.

### Cited Findings
- CapTel 2400iBT: a retailer listing says it cannot pair with a cell phone. Bluetooth is for headsets, neckloops, hearing aids and cochlear implants. Captions are only available for calls within the US. — [Diglo: CapTel 2400iBT](https://diglo.com/captel-2400ibt-captioned-phone;sku=UTI-2400I;s=222;p=UTI-2400I)
- 2400iBT spec: Bluetooth, 3.5 mm headset jack, Ethernet/Wi-Fi, RJ11 line. Voice goes over the phone line and captions over the internet. — [HomeControls 2400iBT setup guide](https://www.homecontrols.com/blogs/product-manuals-documentation/hamilton-captel-2400ibt-captioned-telephone-setup-guide), [AskJAN CapTel 2400i](https://AskJAN.org/products/CapTel-2400i-Captioned-Telephone.cfm), [Utah Relay CapTel](https://relay.utah.gov/captioned-telephone-captel)
- ClearCaptions Blue is a home phone that "can use a landline phone connection, internet, or smartphone" (mechanism unspecified). The ClearCaptions Mobile app captions calls via its own service. Use with captions on is restricted by US federal law to registered users with hearing loss, and service is English-only. — [HearingTracker ClearCaptions review](https://www.hearingtracker.com/captioned-telephones/clearcaptions-review), [ClearCaptions 2019 press release](https://clearcaptions.com/wp-content/uploads/2019/05/J2222-Press-Release-PSTN-Blue-Release_FINAL.pdf), [ClearCaptions Mobile (App Store)](https://apps.apple.com/app/id1389230518)
- Innocaption (US) is recommended by users for captioned cellular calls via a relay number. — [Mayo Clinic Connect](https://connect.mayoclinic.org/comment/831038)

### Inferences
- The relay model of US products (route the call through a captioning service number) is a different architecture, covered by other researchers. US products show the market answer is relay or system integration, not Bluetooth taps.

### Gaps
- Could not load hamiltoncaptel.com to confirm whether any current CapTel model supports a "mobile phone Bluetooth link". Unconfirmed.
- CaptionCall pairing details were not researched (tool budget).

## 8. Cost and availability of hardware in Pakistan

### Takeaway
Thin data. Raspberry Pi 4 boards are sold in Pakistan at roughly PKR 20,000–27,000 (one retailer, inconsistent listings). ESP32 dev boards are widely sold by Pakistani electronics shops but were not priced in this research. A spare old Android phone (route 2) is the cheapest option.

### Cited Findings
- W11Stop lists the Raspberry Pi 4 Model B at Rs 23,000 (updated July 2026) and a 2026 range of PKR 20,000–27,000 on its overview page, with another listing at Rs 70,000 (Sept 2026). The listings are inconsistent. A Pi 4 Starter Kit is Rs 35,000. — [W11Stop Raspberry Pi 4](https://w11stop.com/raspberry-pi-boards/raspberry-pi-4-price-in-pakistan), [W11Stop Raspberry Pi overview](https://w11stop.com/embedded-boards/embedded-board/raspberry-pi), [W11Stop Starter Kit](https://w11stop.com/raspberry-pi/raspberry-pi-4-b-starter-kit-price-in-pakistan)
- US reference prices: JK Audio CellTap 4C about USD 113, KJB D1450 BT call-recording headset about USD 137. — [SCMS](https://www.scmsinc.com/jk-audio-celltap4c-celltap-4c-wireless-phone-audio-tap-adapter.html), [123SecurityProducts](https://www.123securityproducts.com/audio/recording-devices/audio-standard/d1450.html)

### Inferences
- [Theoretical] An ESP32 classic-BT board (ESP32-WROOM DevKitC, not S2/S3/C3, which lack BR/EDR), an I2S MEMS mic and an enclosure would make a very low-cost BOM. The classic ESP32 is required: the README lists only ESP32 and ESP32-S31 as supported targets. Import duties and customs for niche items (CellTap, LE Audio dev kits) make them impractical in Pakistan.

### Gaps
- No sourced ESP32 / Daraz price. The search returned no listings.
- Availability of CellTap or similar in Pakistan is unknown.

## Overall ranking (synthesis of the above; inferences)
1. **Second-device acoustic (route 2)**: works today on any phone, no hacks, and HumSukhan already supports it. Lowest risk, moderate quality, poor privacy.
2. **Same-phone accessibility-service + speakerphone (route 1)**: no extra hardware, but heavily dependent on the device and on Play policy. AEC may remove the far-end voice. It needs a device-matrix test on popular Pakistani phones (Samsung A-series, Redmi, Infinix, Tecno, Vivo, Oppo) on Android 13–16, checking `isClientSilenced()` and the audio sources (`VOICE_RECOGNITION`, `MIC`, `UNPROCESSED`, `CAMCORDER`).
3. **ESP32/RPi Bluetooth HFP hands-free bridge (route 3)**: best audio quality, the dialer stays normal, and it can also inject TTS into the call. It requires building and supporting hardware and solving PCM transport to ASR. The ESP32 HF role is officially supported; end-to-end, it has not been shown with a phone app.
4. **Wired tap (route 4)**: proven commercially (CellTap), but awkward on jackless phones and needs a second capture device.
5. **ASHA/LE Audio emulation, smartwatch, US captioned phones**: not practical for HumSukhan in Pakistan.
