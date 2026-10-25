# Built-in OEM and Google system features that caption or transcribe ordinary SIM calls, and their integration paths (as of Oct 2026)

Research date: 2026-10-25. **Method note:** In this environment, direct fetches of support.google.com, source.android.com, samsung.com, news.samsung.com, sammobile.com and pakera.pk all failed (the egress proxy returned 403 or DNS failed). Every finding below comes from search-engine snippets or summaries of the cited pages, not from reading the full pages. Treat exact language lists as "per search snippet of the cited page" and re-check them on a device or in a browser before relying on them. Each claim carries the date or version context the snippet gave.

---

## 1. Google Live Caption (including Live Caption for calls, Expressive Captions, type-to-reply)

### Takeaway
Live Caption runs on-device and can caption ordinary phone calls on "Pixel and selected Android phones". Its language list (about 15 languages on Pixel 6+ and selected Android 14+ phones) includes Hindi but **not Urdu**. No source showed any official API, intent or export that lets another app read Live Caption text. Reading its overlay through an accessibility service is undocumented and risky under Play policy.

### Cited Findings
- Google's Live Caption help page lists these languages for "Pixel 6+ and selected Android phones in Android U+" (Android 14+): English, French, German, Italian, Japanese, Hindi, Spanish, Traditional Chinese, Simplified Chinese, Turkish, Polish, Portuguese, Korean, Russian, Vietnamese. **Urdu is not listed.** — [Google Accessibility Help, Live Caption (snippet)](https://support.google.com/accessibility/answer/9350862?hl=EN-GB&ref_topic=9114916); the same list is repeated by [Android Police](https://www.androidpolice.com/how-to-use-android-live-caption/)
- The same page gives a shorter list for Pixel 4/5 and selected phones: English, French, German, Italian, Japanese, Hindi, Spanish. — [Google Android Accessibility Help (en-IN) (snippet)](https://support.google.com/accessibility/android/answer/9350862?hl=en-IN)
- "You can get captions with calls on Pixel and selected Android phones." Captions are processed on-device. — [Google Android Accessibility Help (snippet)](https://support.google.com/accessibility/android/answer/9350862?hl=en)
- Call captioning "doesn't translate and only allows you to converse in your current language". The user can type replies, which are read aloud to the caller (the type-to-speak / call reply feature). — [Google Help (en-IN) (snippet)](https://support.google.com/accessibility/android/answer/9350862?hl=en-IN)
- Translating captions requires Live Translate, which is only available on Pixel 6+. — [Google Accessibility Help (snippet)](https://support.google.com/accessibility/answer/9350862?hl=EN-GB&ref_topic=9114916)
- Expressive Captions (tone and non-speech sounds) are available in English (US) on Android 14+ devices with Live Caption on. English (Australia, Canada, UK) needs Android 15+. They are on by default. — [Google Accessibility Help (snippet)](https://support.google.com/accessibility/answer/9350862?hl=EN-GB&ref_topic=9114916); [Google Android Accessibility Help (snippet)](https://support.google.com/accessibility/android/answer/9350862?hl=en)
- History: in March 2022, call captions were Pixel-only in English, French, Italian, German and Spanish, with Japanese in beta. — [Forbes, 2022-03-09](https://www.forbes.com/sites/stevenaquino/2022/03/09/a-look-inside-googles-new-live-captions-for-calls-accessibility-feature-for-pixel/)
- In May 2023, Google said Live Caption for Calls "will expand to more Android devices including select Samsung Galaxy phones with future updates". — [SammyFans, 2023-05-19](https://www.sammyfans.com/2023/05/19/android-live-caption-for-calls-samsung/)
- Samsung users report the call caption option under Settings > Accessibility > Hearing enhancements > Live caption ("captions during calls"), appearing after an update. — [Samsung US Community thread](https://us.community.samsung.com/t5/Samsung-Apps-and-Services/Adding-live-caption-during-call/td-p/2564197)
- A March 2026 secondary guide says that "most non-Pixel Android phones do not reliably support Live Caption for phone calls", and that many Samsung, OnePlus and Motorola devices do not expose call audio in a way Live Caption can access. This is a secondary source and unverified. — [MacMyths](https://macmyths.com/how-to-use-live-caption-to-transcribe-phone-calls/)
- Chrome's Live Captions listing names 52 spoken languages (Arabic, Persian, Hindi and Bengali among them). Urdu does not appear. This is a different product from Android Live Caption but likely shares Google's on-device speech-model family. — [Chrome Web Store, Live Captions](https://chromewebstore.google.com/detail/live-captions/ckpgjpenbhnkhcalechemlifbcinneen)
- **Accessibility read-out:** Android docs say a service with `canRetrieveWindowContent=true` gets the UI as AccessibilityWindowInfo/AccessibilityNodeInfo trees. — [Android Developers, Create an accessibility service](https://developer.android.com/guide/topics/ui/accessibility/service)
- A 2026 security blog says FLAG_SECURE blocks `takeScreenshot()` and MediaProjection but does **not** block reading the accessibility tree. This is secondary and not confirmed in official docs. — [Chocapikk blog, 2026](https://chocapikk.com/posts/2026/android-a11y-god-mode/)
- No source found documents a developer API, broadcast, content provider or file export for Live Caption text. Google describes it only as a user-facing feature. — [Google Android Accessibility Help](https://support.google.com/accessibility/android/answer/9350862?hl=en) (searches for an API returned nothing)
- **Play policy:** only services "designed to help people with disabilities" may declare `isAccessibilityTool`. Those are exempt from the prominent-disclosure requirement; all other apps need in-app disclosure and affirmative consent. — [Google Play Console Help, Accessibility API policy](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en)
- A Play policy update announced 2025-10-30 (effective 2026-01-28) prohibits using the Accessibility API to autonomously initiate, plan and execute actions. Verified accessibility tools are exempt when the use serves their core disability purpose. — [Google Play Console Help (snippet)](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en); [policy update log](https://support.google.com/googleplay/android-developer/answer/12253906?hl=en-GB)
- Google's 2022 policy says the Accessibility API "is not designed and cannot be requested for remote call audio recording". — [Engadget, 2022](https://www.engadget.com/google-is-banning-third-party-call-recording-apps-from-the-play-store-093201443.html); [MobileSyrup, 2022-04-22](https://mobilesyrup.com/2022/04/22/google-introduces-new-play-store-policy-banning-third-party-call-recording-apps/)

### Inferences
- For HumSukhan's users (Urdu and code-switched speech), Live Caption for calls can at best give Hindi or English captions. Spoken Urdu and Hindi are largely mutually intelligible, so the Hindi model may partly transcribe colloquial Urdu. The output would be in Devanagari script, not Nastaliq, which is a practical problem for Urdu readers. This is untested and an inference only.
- Reading Live Caption's overlay text through HumSukhan's own accessibility service is technically plausible if the caption window is exposed to the accessibility tree. That has not been verified; a device test with `uiautomator dump` or an a11y node dump during a call is needed. Even if it works, it depends on undocumented UI that Google can change. It also scrapes another app's content, which a reviewer may see as outside the "accessibility tool" core purpose unless it is clearly framed as assistive. Using it for recording or transcription storage would conflict with the 2022 call-recording language.
- Live Caption already covers English and Hindi calls on-device. HumSukhan's differentiator is Urdu and code-switching, which Google does not cover.

### Gaps
- Could not load the live help page, so the exact 2026 language list and device list ("selected Android phones") are unconfirmed. Snippets may be stale.
- No source gave Live Caption latency figures.
- Unknown whether the Live Caption window is `FLAG_SECURE`, `importantForAccessibility=no`, or excluded from the accessibility tree. This needs an empirical test.
- No information on whether Live Caption for calls works on Transsion, Xiaomi, vivo or OPPO devices sold in Pakistan.

---

## 2. Google Live Transcribe & Sound Notifications

### Takeaway
Live Transcribe is a microphone-based app with 70 to 80+ languages. No source confirmed Urdu or support for capturing phone-call audio. It listens through the microphone, so it would only hear a call on speakerphone.

### Cited Findings
- Live Transcribe covers "over 70 languages" per one guide; Wikipedia says "over 80 languages" with varying accuracy. Neither names Urdu. — [Notta guide](https://www.notta.ai/en/blog/google-live-transcribe); [Wikipedia, Live Transcribe](https://en.wikipedia.org/wiki/Live_Transcribe)
- A subset of languages can be downloaded for offline use, depending on Android version. — [Android Police guide](https://www.androidpolice.com/google-live-transcribe-guide/)
- Google Translate's live translate and Google Meet's translated captions do list Urdu, so Google has Urdu ASR in the cloud. — [Google Translate Help](https://support.google.com/translate/answer/6142474?hl=en&co=GENIE.Platform%3DAndroid); [Google Meet Help](https://support.google.com/meet/answer/10964115?hl=en&co=GENIE.Platform%3DDesktop)

### Inferences
- Live Transcribe is not a SIM-call solution. Through the microphone it is the same as HumSukhan's existing speakerphone approach, so HumSukhan already matches it.

### Gaps
- Official Live Transcribe language list (Urdu yes or no) not retrieved; support.google.com was blocked. Check in-app under Settings > More settings > Primary language.

---

## 3. Pixel Call Screen, Call Notes, Pixel Phone app call recording, and Google Phone app on non-Pixel

### Takeaway
Call Notes (on-device call transcription and summary) is limited to Pixel 9+ in a handful of countries: US, UK, Canada, Australia, Ireland, Japan, and India on Pixel 10. Pakistan is not among them, and Urdu is not supported. Pixel call recording is broadly available on Pixel 6+. Google Phone app recording on non-Pixel phones is region and carrier gated, and Pakistan availability is unconfirmed.

### Cited Findings
- Call Notes: Pixel 9 and later in Australia, Canada, Ireland, UK and US (English) and Japan (Japanese). Pixel 10 series in India (Hindi and English). Call summaries are English-only. A SIM from that country or region is required. — [Google Phone app Help, Use Call Notes](https://support.google.com/phoneapp/answer/15257579?hl=en)
- Pixel 10 (Aug 2025): Call Screen expanded to Australia, Canada and Ireland. India got a beta of Manual Call Screen in English and Hindi. — [Google blog, Pixel 10 calling updates](https://blog.google/products-and-platforms/devices/pixel/calling-updates-pixel-10/)
- Basic Call Recording is rolling out to "all countries where Pixel is supported" on Pixel 6 and newer (Sept 2025). — [9to5Google, 2025-09-29](https://9to5google.com/2025/09/29/pixel-phone-app-updates/); [GSMArena](https://m.gsmarena.com/newscomm-70296.php)
- Google Phone app call recording on non-Pixel phones is "widely available, but not in all countries or regions". It depends on device and carrier, needs Android 9+, and both parties hear an announcement that the call is being recorded. — [MakeUseOf](https://www.makeuseof.com/how-record-calls-google-phone-android/); [Android Infotech, Oct 2026](https://www.androidinfotech.com/enable-native-call-recording-google-phone-app/)
- A Pakistan-focused guide could not confirm Google Phone app recording availability in Pakistan and found no Pakistani law settling the legality of call recording. — [Pakera.pk (search snippet)](https://pakera.pk/how-to-record-phone-calls-android-iphone-legal-pakistan/)

### Inferences
- Pakistan is not a Pixel launch market and is absent from all Call Notes and Call Screen lists, so these Pixel AI call features are effectively unavailable to HumSukhan's users.
- Recorded files (Pixel recorder or Google Phone app recorder) are post-call only. Whether another app can read them depends on where they are stored. Google's recorder historically keeps recordings inside the Phone app, not in shared storage. That is unverified here, so at most it is a weak non-real-time fallback.

### Gaps
- Whether Google Phone app recording is enabled for Pakistani SIMs (Jazz, Zong, Telenor/Ufone) is unknown. A device test is needed.
- Call Screen and Call Notes latency figures were not found.

---

## 4. Samsung Galaxy AI (Live Translate for calls, Transcript Assist / call transcripts, Call Captions, Bixby Text Call)

### Takeaway
Samsung's Galaxy AI language set grew to 24 languages in Oct 2026. It includes Hindi and Gujarati but **not Urdu**. Live Translate gives real-time subtitles on ordinary calls in the Samsung dialer. One UI 7+ adds recording with transcripts, with an on-device-only option. One UI 8 tested a separate "Call Captions" feature. No Samsung SDK or partner route granting call audio to third parties was found.

### Cited Findings
- On 2026-10-14 Samsung added Hungarian and Malay, bringing Galaxy AI / Live Translate to 24 languages: Arabic, Chinese (mainland, HK, Taiwan), Dutch, English (AU, IN, UK, US), Filipino, French (CA, FR), German, Gujarati, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Malay, Polish, Portuguese (BR, EU), Romanian, Russian, Spanish (MX, ES, US), Swedish, Thai, Turkish, Vietnamese. **No Urdu, and no English (Pakistan).** Rollout is "over the following weeks". — [Samsung Global Newsroom (snippet)](https://news.samsung.com/global/samsung-expands-language-support-across-ai-experiences-on-galaxy); earlier 22-language list: [Samsung India Newsroom](https://news.samsung.com/in/galaxy-ai-expands-support-to-22-languages)
- Samsung Pakistan has a "Galaxy AI languages & usage guide" page, so Galaxy AI is marketed in Pakistan. A Pakistani outlet (Oct 2026) says none of Samsung's Galaxy AI language lists includes Urdu and that Live Translate will not translate an Urdu call. This is secondary and its full text was not loaded. — [Samsung Pakistan support page](https://www.samsung.com/pk/support/mobile-devices/galaxy-ai-languages-usage-guide/); [Pakera.pk](https://pakera.pk/galaxy-ai-free-features-pakistan/)
- One UI 8: Live Translate lets you "view live subtitles and/or listen to the spoken translation during a call", enabled under Galaxy AI settings. — [Samsung US Newsroom, One UI 8 Galaxy AI guide](https://news.samsung.com/us/how-to-use-the-latest-samsung-galaxy-ai-features-on-one-ui-8/); [Samsung SA support, Live Translate for calls](https://www.samsung.com/sa_en/support/mobile-devices/how-to-use-live-translate-for-phone-calls-on-the-galaxy-s24/)
- Call recording with transcripts and summaries is in the Samsung Phone app on One UI 7.0+ and requires a Samsung account. Settings path: Record calls > Transcript assist, with a "Process data only on the device" switch. Not available on Galaxy A56, A36, A26 or A17 5G. — [Samsung India support, Call Transcript](https://www.samsung.com/in/support/mobile-devices/how-to-use-call-transcript-feature-in-galaxy-devices/); [Samsung US, record calls](https://www.samsung.com/us/support/answer/ANS10004613)
- Transcript Assist "requires a network connection and Samsung Account login". This conflicts with the on-device switch above, so the processing split probably varies by language and device. — [Samsung US Newsroom, One UI 8](https://news.samsung.com/us/how-to-use-the-latest-samsung-galaxy-ai-features-on-one-ui-8/)
- One UI 8 beta (Galaxy S25) surfaced a Samsung "Call Captions" feature, reachable only via a Phone app suggestion. It did not work in that beta. — [SamMobile (snippet)](https://www.sammobile.com/news/one-ui-8-brings-call-captions-live-caption-for-calls/)
- Samsung call screening exists in the US. — [Samsung US support, Call screening](https://www.samsung.com/us/support/answer/ANS10010345/)
- Galaxy AI overview — [Wikipedia, Galaxy AI](https://en.wikipedia.org/wiki/Galaxy_AI)

### Inferences
- In Pakistan, Galaxy Live Translate or Call Captions could caption a remote caller speaking English (via English (India/UK/US) models) or Hindi. It cannot produce Urdu-script captions, and accuracy on code-switched Urdu-English speech is unknown.
- Samsung holds about 10 to 16% of Pakistan's market (see section 6), and the AI features are flagship and upper-mid only, so they reach a small share of HumSukhan's users.
- No public Samsung SDK exposes call audio. Knox SDK is an enterprise device-management API; no source tied it to call audio, and none of the searches found a Samsung partner program for caption apps.

### Gaps
- Live Translate latency figures not found.
- Whether Pakistani-region firmware enables call recording and Transcript Assist (call recording is region-restricted on Samsung) was not confirmed.
- No information on whether Samsung's call subtitles are exposed to accessibility services.

---

## 5. Other OEMs: Xiaomi HyperOS, OPPO/OnePlus ColorOS, vivo, Honor, Huawei, Transsion (Tecno/Infinix/itel), realme

### Takeaway
Call translation and captioning features exist (Honor on-device AI call translation, OPPO AI Call Translator, Infinix Folax, Xiaomi AI interpreter). No source found lists Urdu for any OEM call-caption or call-translation feature. Where language lists exist, they are short (Honor: 6 languages; Infinix auto-answer: English only).

### Cited Findings
- Honor AI call translation supports Chinese, English, French, German, Italian and Spanish, on-device (Magic V5, 2025). — [Honor official help simulator](https://iknow-dl.service.hihonor.com/ctkbfm/applet/simulator/en-us15883303/index.html); [GSMArena, Magic V5](https://www.gsmarena.com/honor_magic_v5_has_ondevice_ai_realtime_call_translation-news-69193.php); [Gizchina](https://www.gizchina.com/honor-2/honor-magic-v5-brings-real-time-ai-call-translation-to-europe)
- OPPO (2025) announced an AI Call Translator for real-time call translation "via a future update", plus call summarization, in closer collaboration with Google. — [Rappler, 2025](https://www.rappler.com/technology/gadgets/oppo-enhanced-ai-strategy-2025-translate-call-summary/)
- ColorOS 16 adds context-aware real-time translation with summaries and an on-device translation model. Whether it covers calls and which languages is not stated. A ProPakistani piece (2026-04-17) covers the Find X9 Ultra launch with ColorOS 16 AI features in Pakistan. — [Tecnoandroid.it](https://www.tecnoandroid.it/news/oppo-find-x9-laggiornamento-coloros-16-1-cambia-tutto-ecco-cosa-arriva-1898132/); [ProPakistani, 2026-04-17](https://propakistani.pk/2026/04/17/find-x9-ultra-to-launch-with-new-ai-features-to-coloros-16/amp/); [TechRadar, ColorOS 16](https://www.techradar.com/phones/oppo-phones/coloros-16-is-rolling-out-to-oppo-phones-heres-the-8-features-to-try-first)
- Infinix Folax (XOS 15, Aug 2025) is an assistant that "handles calls, translations… auto-subtitles" and works offline for many functions. — [Techweez, 2025-08-29](https://techweez.com/2025/08/29/folax-ai-infinix-personal-assistant/); [Techweez on X](https://x.com/techweez/status/1961424600429887643)
- In 91mobiles' review, Infinix AI Auto-Answer "currently only supports English" and failed to follow a Hindi call. — [91mobiles review](https://www.91mobiles.com/reviews/infinix-ai-features-reviewed-pros-cons/)
- Infinix AI Buds claim translation in 162 languages (CogLabs engine). This is an earbud feature, not a call feature, and Urdu is not named. — [Tomorrow's World Today](https://www.tomorrowsworldtoday.com/artificial-intelligence/infinix-launches-ai-buds-with-real-time-translation-in-162-languages/)
- Xiaomi "Mi AI Translate" is a system app described as doing subtitles for video and apps and "interpret calls". The source is an unofficial APK listing with no language list. — [Uptodown](https://mi-ai-translate.en.uptodown.com/android)
- An anecdotal comment (Sept 2025) says Xiaomi's HyperOS subtitle translation only translates into Chinese in some cases. — [GSMArena comments](https://m.gsmarena.com/newscomm-69607p7.php)
- An anecdotal comment (Apr 2025) says vivo FunTouch OS 15 lacked AI call translation and transcripts. — [GSMArena comments](https://www.gsmarena.com/newscomm-67549.php)

### Inferences
- No mass-market OEM in Pakistan (Transsion, Xiaomi, vivo, OPPO) has a documented Urdu call-caption feature. There is a real market gap, which HumSukhan could fill only with OEM cooperation (section 7).
- Transsion is the largest vendor in Pakistan and already ships call AI (Folax) and a call recorder. It is the most strategically relevant OEM partner, but there is no documented partner route.

### Gaps
- No official language lists for Xiaomi HyperOS 3, ColorOS 16, OriginOS/FuntouchOS, Huawei HarmonyOS or realme call features. The official pages were not found or reachable.
- Huawei and realme were not covered by any result.
- Tecno "Ella" call features were not found.

---

## 6. Pakistan smartphone market share (brand relevance)

### Takeaway
Transsion (Infinix, Tecno, itel) dominates Pakistan by units. Xiaomi, vivo, Samsung and OPPO follow. Pixel is negligible. Sources disagree on exact shares.

### Cited Findings
- Q2 2025 unit share: Transsion 44%, Xiaomi 18%, vivo 17%, Samsung 10%, OPPO 6%. The article does not name its data source. — [Profit / Pakistan Today, 2025-10-20](https://profit.pakistantoday.com.pk/2025/10/20/xiaomi-eyes-pakistans-expanding-smartphone-market-as-local-assembly-and-smart-tv-production-gain-pace/)
- StatCounter-based figures (2024): Infinix 16.53%, Samsung 15.66%, vivo 13.46%, OPPO 11.16%, Tecno 10.57%, Xiaomi 9.24%. These measure web-traffic share, not sales. — [ProPakistani, 2025-01-15](https://propakistani.pk/2025/01/15/shocking-smartphone-market-trends-in-pakistan-who-was-leading-in-2024/amp/)
- Xiaomi's Pakistan shipments fell 41% in 2025; about 95% of sales go through independent retailers. — [Profit / Pakistan Today, 2025-10-20](https://profit.pakistantoday.com.pk/2025/10/20/xiaomi-eyes-pakistans-expanding-smartphone-market-as-local-assembly-and-smart-tv-production-gain-pace/)
- PTA 2025 local assembly: locally assembled phones were 93% of consumption. By units assembled: Infinix 3.65M, VGO Tel 3.57M, vivo 2.80M, itel 2.34M, Samsung 1.85M, Tecno 1.84M, Xiaomi 1.38M. — [MEA Tech Watch, 2026-01-22 (PTA data)](https://meatechwatch.com/2026/01/22/local-mobile-phone-manufacturing-dipped-in-december-2025-pta/)

### Inferences
- Combining Transsion units (Infinix, Tecno, itel) with VGO Tel (feature phones and budget devices), most HumSukhan users likely carry budget Transsion or vivo/Xiaomi phones without Galaxy AI or Pixel features.

### Gaps
- No Counterpoint Pakistan report found, and no StatCounter 2025–2026 table retrieved.

---

## 7. OEM privileged integration routes (CAPTURE_AUDIO_OUTPUT, CALL_AUDIO_INTERCEPTION, preloads, partnerships)

### Takeaway
Real-time access to call downlink audio is technically gated to privileged, pre-installed apps. An app must be signed by the platform or placed in `/system/priv-app` and allowlisted by the OEM, and holding `CAPTURE_AUDIO_OUTPUT` lets it record `VOICE_DOWNLINK`. That makes an OEM preload deal (Transsion, Xiaomi, vivo, Samsung) the only sanctioned real-time route for a SIM call. No public partner program, price, or precedent of a caption app being preloaded for this was found.

### Cited Findings
- Android docs: an app "can capture the voice call if it is a privileged (pre-installed) app with permission CAPTURE_AUDIO_OUTPUT", choosing `VOICE_UPLINK`, `VOICE_DOWNLINK` or `TELEPHONY` sources (TX, RX or both). — [Android Developers, Sharing audio input](https://developer.android.com/media/platform/sharing-audio-input)
- Third-party apps cannot hold `CAPTURE_AUDIO_OUTPUT`; it is a signature or privileged permission available only to apps from Google or the device vendor. — [MITRE ATT&CK T1429](https://attack.mitre.org/techniques/T1429/)
- An AOSP / e-OS audio-policy commit blocks capture during a call unless the client holds `CAPTURE_AUDIO_OUTPUT`. — [e Foundation android_frameworks_av commit](https://gitlab.e.foundation/e/os/android_frameworks_av/-/commit/1ff16a772159dbc7ebe851e474bb155a2c8e74ab)
- OEM call recorders are such privileged system apps, e.g., MediaTek's call recorder package and Nothing's sound recorder. — [Bayton sysapps, com.mediatek.callrecorder](https://sysapps.bayton.org/packages/com.mediatek.callrecorder); [Bayton sysapps, com.nothing.soundrecorder](https://sysapps.bayton.org/packages/com.nothing.soundrecorder)
- `CALL_AUDIO_INTERCEPTION` was added in Android 13 alongside cross-device calling APIs. An Android 14 role bundles `CALL_AUDIO_INTERCEPTION` and `RECORD_AUDIO` for streaming call audio. AOSP AudioService checks this permission. — [Mishaal Rahman on X](https://twitter.com/MishaalRahman/status/1643673617081745409); [AOSP AudioService.java](https://android.googlesource.com/platform/frameworks/base/+/master/services/core/java/com/android/server/audio/AudioService.java); [AOSP ServiceUtilities.cpp](https://android.googlesource.com/platform/frameworks/av/+/master/media/utils/ServiceUtilities.cpp)
- Rogervoice (a third-party call-caption app) declares `MANAGE_OWN_CALLS` and `FOREGROUND_SERVICE_PHONE_CALL` but not `CALL_AUDIO_INTERCEPTION`. This suggests it captions calls it places itself (VoIP/relay) rather than intercepting SIM dialer calls. — [AppBrain, Rogervoice](https://www.appbrain.com/app/rogervoice-phone-call-captions/com.rogervoice.app)

### Inferences
- Integration path: an OEM would ship HumSukhan (or a thin "call-audio bridge" service) as a privileged system app. The OEM grants `CAPTURE_AUDIO_OUTPUT` through its privapp-permissions allowlist XML (standard AOSP mechanism; the source.android.com page could not be loaded to quote) and signs it or places it in `/system/priv-app`. The bridge would read `VOICE_DOWNLINK` and pass PCM to HumSukhan's ASR. Play-distributed updates of a preloaded privileged app are possible, but the privilege only applies to the system-partition copy's package and signature.
- Because the Pakistani market runs through independent retail rather than carriers, a carrier-preload route (as in the US) is less relevant. The OEMs that assemble locally (Infinix, Tecno, itel, vivo, Samsung, Xiaomi) are the realistic counterparts, possibly through PTA or Ministry of IT accessibility initiatives. No source documents such programs.
- Without OEM cooperation, a non-real-time fallback exists: built-in OEM recorders (Xiaomi, Transsion, Samsung in some regions, Google Phone app) can save call audio, and HumSukhan could transcribe the file after the call if it is in shared storage and the user grants access. This is not live captioning, and some recorders announce the recording to both parties.

### Gaps
- No documented cost, requirements or precedent for OEM preload of a third-party caption app (e.g., Samsung + Nagish, Rogervoice OEM deals). The searches returned nothing.
- Exact privapp-permissions allowlist format and documentation not retrieved (source.android.com blocked).
- Whether Transsion, Xiaomi and Samsung recorders in Pakistan announce recording and store files in shared, readable storage is unconfirmed.
