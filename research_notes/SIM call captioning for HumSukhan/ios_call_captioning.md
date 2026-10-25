# iOS feasibility: captioning the remote caller in an ordinary cellular call (as of Oct 2026)

Research environment note (25 Oct 2026): support.apple.com, www.apple.com (including apple.com/ios/feature-availability), web.archive.org, forums.macrumors.com and several blogs failed to load here (DNS failure or proxy 403). developer.apple.com did load: its documentation JSON endpoints (`developer.apple.com/tutorials/data/documentation/...json`) and forum threads were fetched directly. Facts from Apple support and feature-availability pages therefore come from search-engine snippets of those pages or from secondary press, and are marked that way. The current Apple feature-availability page is titled "iOS and iPadOS 27 - Feature Availability", which means iOS 27 is the shipping release as of this date.

## Q1. CallKit, CXCallObserver, AVAudioSession: can a third-party app record the mic or access call audio during a cellular call? What happens when a call starts?

### Takeaway
No. No public iOS API gives a third-party app the audio of a cellular call, whether that is the downlink (the remote caller) or the uplink. CallKit and CXCallObserver report call *state* only. When a call rings or is answered, the system interrupts the app's AVAudioSession, so its own mic recording stops. Apple's only response to a developer who asked to keep recording was "file an enhancement request" (May 2025).

### Cited Findings
- CXCallObserver is "A programmatic interface for an object that manages a list of active calls and observes call changes." It exposes a `calls` list and a delegate. "any app can create a new CXCallObserver object to be notified of any calls activity on the system." The page has no audio API. — [Apple Developer: CXCallObserver](https://developer.apple.com/documentation/callkit/cxcallobserver) (fetched via the docs JSON endpoint, Oct 2026)
- Apple's "Handling audio interruptions" article says: "System alerts, such as receiving an incoming phone call, interrupt the active audio session." Apps can call `setPrefersNoInterruptionsFromSystemAlerts(_:)` so the *ringing alert* does not interrupt them. A system-initiated deactivation arrives with a context whose `source` is the system. Apple also warns that the system may never deliver an end-of-interruption event, which is why it recommends the newer `resumptionRecommendationNotification`. — [Apple Developer: Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- Developer forum thread (May–Jun 2025): a continuous-recording app's "AVAudioSession is interrupted and recording stops completely during the ringing phase". The developer notes that Apple's own Voice Memos keeps recording during rings and asks whether there is "an approved way to maintain microphone access during call rings". The Apple reply only said "Please use Feedback Assistant to file an enhancement request" (FB18434531). No workaround was given. — [Apple Developer Forums thread 784782](https://developer.apple.com/forums/thread/784782)
- In another forum thread, a VoIP developer reports that after a cellular (GSM) call was answered, the app got the interruption-began event and could not play or record. The interruption-ended event arrived only when the app returned to the foreground. — [Apple Developer Forums thread 79849](https://developer.apple.com/forums/thread/79849) (search snippet)
- Secondary sources (vendors, 2025–2026) agree: "iOS strictly blocks all third-party apps from recording audio while the phone dialer is in use", and third-party apps "cannot record cellular calls on iPhone" because iOS does not give them call audio. Third-party "call recorder" apps work around this with a three-way merge to the vendor's service number. — [Recordd guide](https://recordd.co/guides/record-phone-calls-on-iphone); [Kiolo](https://kiolo.com/en/blog/can-you-record-telephone-calls-on-iphone/); [Trinity Solutions: CallKit can/cannot](https://trinitysolutionsinc.com/apple-callkit-what-it-can-and-cannot-do/) (vendor blogs, lower reliability)
- CallKit's purpose is integrating the app's *own VoIP* calls with the native call UI. It does not expose cellular call audio. — [Trinity Solutions](https://trinitysolutionsinc.com/apple-callkit-what-it-can-and-cannot-do/) (secondary)

### Inferences
- An app cannot even capture room audio by putting the call on speaker and recording the mic, because the active call interrupts its audio session. A second device (for example an Android phone or iPad listening to the iPhone speaker) avoids that limit, but it is not a single-iPhone solution.
- `setPrefersNoInterruptionsFromSystemAlerts` covers only the ringing alert. Nothing in the docs suggests it allows recording once the call is answered.

### Gaps
- I found no Apple DTS forum post stating word-for-word "third-party apps cannot access cellular call audio". The conclusion rests on the absence of any such API in CallKit, CXCallObserver and LiveCommunicationKit docs, on the documented interruption behavior, and on consistent secondary sources.
- I did not test whether a mic-only session with `.mixWithOthers` behaves differently during an answered call on iOS 26/27. The forum reports say recording stops.

## Q2. iOS Live Captions: does it caption Phone app cellular calls? Languages and regions (Urdu?)? Any API?

### Takeaway
Live Captions (Settings > Accessibility > Live Captions, launched as a beta in iOS 16, 2022) is Apple's system-level, on-device captioner. Sources disagree on whether it captions ordinary Phone app calls. The languages are a small set of major ones (English variants, Mandarin, Japanese, Korean and a few others). I found no evidence of Urdu, and Pakistan is not shown as a supported region. No public API exposes Live Captions text to third-party apps.

### Cited Findings
- Announced around Global Accessibility Awareness Day (May 2022) as a beta "in English for those in the US and Canada". Captions are generated on-device. In FaceTime they are attributed to individual speakers. — [TechCrunch, 17 May 2022](https://techcrunch.com/2022/05/17/apple-adds-live-captions-to-iphone-and-mac-plus-more-accessibility-upgrades-to-come); [Engadget](https://www.engadget.com/apple-accessibility-updates-live-captions-magnifier-door-detection-assistive-touch-120056407.html); [Six Colors](https://sixcolors.com/link/2022/05/apple-details-live-captions-other-accessibility-features-coming-later-this-year/)
- Apple's iOS 16 iPhone User Guide (search snippet) says Live Captions is available on iPhone 11 and later with the primary language set to English (U.S.) or English (Canada). It says: "By default, Live Captions are shown across all apps. To get live captions only for certain apps such as FaceTime or RTT, turn them on below In-App Live Captions." Accuracy "may vary" and the feature should not be relied on "in high-risk or emergency situations". — [Apple iPhone User Guide (iOS 16)](https://support.apple.com/en-kz/guide/iphone/iphe0990f7bb/16.0/ios) (snippet only; page did not load)
- Whether ordinary calls are covered is disputed. TechRepublic and XDA guides describe captions appearing as each person on a call speaks. A Gadget Hacks guide says "only FaceTime and Real-Time Text (RTT) for the Phone app are currently supported" for in-app captions. One summary says the general Live Captions overlay listens through the mic, so users put the call on speaker. — [TechRepublic](https://www.techrepublic.com/article/how-to-use-live-captions-audio-video-conversations-iphone-ipad/); [XDA](https://www.xda-developers.com/how-to-use-live-captions-on-iphone/); [Gadget Hacks](https://ios.gadgethacks.com/how-to/use-live-captions-your-iphone-for-real-time-transcriptions-any-audio-calls-videos-podcasts-and-more-0385134/) (conflicting secondary sources; I could not verify against current Apple docs)
- The current Apple feature-availability page (iOS and iPadOS 27) has a Live Captions section. Its visible snippet includes "Mandarin Chinese (China mainland and Taiwan)". A secondary summary of that page lists 18 regional variants of 8 languages, including Japanese, Korean and Mandarin. — [Apple iOS 27 Feature Availability](https://www.apple.com/ios/feature-availability/) (snippet only); summary via search of [freelivecaption.com](https://freelivecaption.com/en/posts/live-captions-every-device) (secondary; page did not load)
- watchOS 26 / iOS 26 (Sept 2025): Live Captions generated on the iPhone (for example during Live Listen) can be viewed on Apple Watch. Apple notes Live Captions "isn't available in all languages, countries, or regions". — [Apple Support: Control Live Listen from Apple Watch](https://support.apple.com/en-au/guide/watch/apd4f5b634f3) (snippet); [iPhone Life, Sept 2025](https://iphonelife.com/content/how-to-use-live-listen-apple-watch)
- I found no Apple developer API that returns Live Captions text. Live Captions does not appear as a framework in Apple developer documentation (absence-based; see Gaps).

### Inferences
- Even where Live Captions works on calls, it would not help Urdu or code-switched Urdu–English speech in Pakistan. Urdu is not among the reported Live Captions languages.
- Live Captions is a first-party, closed feature. HumSukhan cannot read, extend or relay its output.

### Gaps
- I could not load Apple's current (iOS 26/27) Live Captions support page or the full feature-availability list. The exact language list, and whether Pakistan appears as a region, are not verified first-hand. Absence of Urdu is based on the snippet and secondary summary.
- I could not settle from a current Apple source whether Live Captions captions the downlink of an ordinary cellular Phone call directly, or only FaceTime, RTT and speaker audio picked up by the mic.

## Q3. iOS 18 call recording and transcription in the Phone app (and Apple Intelligence summaries)

### Takeaway
Since iOS 18.1 (Oct 2024), the Phone app can record calls. The other party hears a spoken notice. Transcription happens *after the call* and is stored in Notes, in a handful of languages. Summaries need Apple Intelligence hardware. It is not real-time captioning, offers no Urdu, has no third-party API, and the audible announcement breaks the "other caller changes nothing / is unaware" assumption.

### Cited Findings
- Recording starts from a record button in Phone or FaceTime. The recording and transcript are saved to Notes with the call's date, time and length. Any iOS 18.1 iPhone gets transcripts. Summaries require an Apple Intelligence-capable device. — [Macworld](https://www.macworld.com/article/2536876/how-to-record-and-transcribe-voice-calls-on-your-iphone.html); [Sonix guide](https://sonix.ai/resources/transcribe-iphone-phone-calls/); [Gadget Hacks](https://ios.gadgethacks.com/how-to/easily-record-phone-calls-your-iphone-and-get-automatic-transcripts-and-summaries-0385641)
- Both parties hear a notice when recording starts, and it repeats periodically. Recording is reportedly not available in some regions, including the EU and Russia (as described in the secondary source). — [Sonix guide](https://sonix.ai/resources/transcribe-iphone-phone-calls/) (secondary)
- Transcription languages reported (iOS 18-era): Cantonese (Hong Kong), English (U.S., Australia), Korean, Mandarin Chinese (mainland), Spanish (U.S., Mexico). Other guides defer to Apple's Feature Availability page. — [Sonix guide](https://sonix.ai/resources/transcribe-iphone-phone-calls/) (single secondary source; may be outdated for iOS 26/27)
- Apple publishes no accuracy figures, and transcripts take time to process after the call. — [Sonix guide](https://sonix.ai/resources/transcribe-iphone-phone-calls/)

### Inferences
- Because it is post-call, it does not meet the real-time-caption goal, and it does not cover Urdu. The audio notice also alerts the other caller.

### Gaps
- I could not see the current iOS 26/27 call-transcription language list on Apple's feature-availability page, or confirm whether Pakistan is a supported region for call recording.
- I found no API giving third-party apps access to these recordings beyond the user's Notes data. No developer documentation was found.

## Q4. iOS 26 (2025) Live Translation in Phone, Call Screening, and other call-caption updates; iOS 27 (2026)

### Takeaway
iOS 26 (Sept 2025) added Live Translation in the Phone app. It speaks translated audio aloud during one-to-one calls and needs Apple Intelligence on iPhone 15 Pro or later. Launch languages were English, French, German, Portuguese and Spanish, with Italian, Japanese, Korean and Mandarin added by end of 2025. iOS 26 also added Call Screening, which shows a live transcript of an *unknown* caller's stated reason before the call is answered. Neither supports Urdu, and neither exposes text to apps. iOS 27 (2026) coverage mostly concerns the Translate app. I found no confirmed Urdu for any Phone-app feature.

### Cited Findings
- WWDC25 (June 2025): Live Translation is integrated into Messages, FaceTime and Phone. In Phone, translation is spoken aloud to the other party. In FaceTime, translated *captions* are shown, with Live Captions enabled. Phone and FaceTime launch languages: English (U.S., UK), French, German, Portuguese, Spanish. Messages has more. — [AppleInsider, 11 Jun 2025](https://appleinsider.com/articles/25/06/11/new-ios-26-translation-tool-works-inside-calls-chats-video); [AppleInsider FaceTime guide](https://appleinsider.com/inside/facetime/tips/inside-live-translation-on-facetime-on-ios-26); [Macworld](https://www.macworld.com/article/2816543/everyone-will-want-to-try-apples-live-translation-this-fall-heres-where-to-find-it.html)
- Requirements: iPhone 15 Pro or later on iOS 26 with Apple Intelligence enabled, with Siri and device language set to a supported language. Language packs must be downloaded. One-on-one calls only. — [AppleInsider](https://appleinsider.com/articles/25/06/11/new-ios-26-translation-tool-works-inside-calls-chats-video); [iThinkDiff](https://www.ithinkdiff.com/ios-26-live-translation-calls-messages-offline/); [iGeeksBlog](https://www.igeeksblog.com/how-to-use-live-translation-in-ios-26-on-iphone/)
- Apple Newsroom (Sept 2025): Live Translation for Phone, FaceTime and AirPods would add Italian, Japanese, Korean, Chinese (Mandarin, simplified) and Chinese (Mandarin, traditional) by end of 2025. — [Apple Newsroom, Sept 2025](https://www.apple.com/newsroom/2025/09/new-apple-intelligence-features-are-available-today/) (snippet); [Yahoo Tech](https://tech.yahoo.com/ai/apple-intelligence/articles/apples-live-translation-adds-4-160200369.html)
- iOS 26.1 (Oct 2025) brought AirPods Live Translation to 11 language options. That is the AirPods feature, not the Phone app. — [9to5Mac, 20 Oct 2025](https://9to5mac.com/2025/10/20/ios-26-1-makes-airpods-pros-latest-feature-even-better-heres-whats-new/)
- Call Screening (iOS 26): for unknown numbers, the iPhone asks the caller's name and reason, and the user sees "a live transcription of their response in real time" before choosing to answer. It is off by default (Settings > Apps > Phone > Screen Unknown Callers > Ask Reason for Calling). Reported languages: Cantonese, English, French, German, Japanese, Korean, Mandarin Chinese, Portuguese, Spanish. One late-2026 source says the iOS 27.2 beta adds Italian. — [Tom's Guide](https://www.tomsguide.com/phones/iphones/ive-been-running-ios-26-since-the-summer-and-one-feature-alone-makes-the-upgrade-worth-it); [TechRadar](https://www.techradar.com/phones/iphone/call-screening-in-ios-26-has-finally-ended-my-spam-call-nightmare-heres-how-to-set-it-up); [pasqualepillitteri.it](https://pasqualepillitteri.it/en/news/16737/iphone-call-screening-unknown-callers) (the language lists conflict on Cantonese and Korean; the iOS 27.2 claim comes from a single source I could not load)
- iOS 27 (betas from June to July 2026): the Translate app added 9 languages, reaching 30. Outlets disagree on which nine. Heise names Danish, Swedish, Norwegian, Cantonese, Hebrew and Malay among them. Cult of Mac lists others and warns the list may change before release. Neither list includes Urdu. No confirmed iOS 27 expansion of Phone-app Live Translation languages was found. A Hawkdive claim of "38 languages" for Phone is inconsistent with the others. — [Heise](https://www.heise.de/en/news/iOS-27-Apple-expands-languages-in-Translate-app-11359469.html); [Cult of Mac](https://www.cultofmac.com/news/apple-translate-ios-27-9-new-language-support); [MacTrast, Jul 2026](https://www.mactrast.com/2026/07/ios-27-adds-new-languages-and-accents-to-apple-translate/); [Hawkdive](https://www.hawkdive.com/ios-27-live-translate-iphone-guide/) (unreliable)

### Inferences
- Phone-app Live Translation speaks translated audio rather than showing captions for the remote party. For a Deaf user, FaceTime's translated captions do display text, but FaceTime is not a SIM call.
- Call Screening transcribes only the pre-answer screening exchange with unknown callers, not the conversation.

### Gaps
- I could not verify the authoritative iOS 27 Phone-app Live Translation and Call Screening language lists on apple.com, because the page did not load.
- I found no report of a "Live Captions in Phone calls" upgrade specifically in iOS 26 or iOS 27.

## Q5. RTT/TTY on iPhone, carrier support in Pakistan, and Live Listen

### Takeaway
iPhone has built-in software RTT/TTY in the Phone app, but it depends on the carrier and requires the *other* party to type, so it is not automatic captioning. I found no evidence that Pakistani carriers (Jazz, Zong, Telenor, Ufone) support RTT. Live Listen streams the iPhone mic to AirPods or hearing aids, and since iOS/watchOS 26 it can show Live Captions on Apple Watch. It is a room-audio tool, not call-audio access.

### Cited Findings
- "iPhone provides built-in Software RTT and TTY from the Phone app—it requires no additional devices." RTT/TTY "aren't supported by all carriers or in all regions." — [Apple iPhone User Guide: TTY and RTT](https://support.apple.com/en-kg/guide/iphone/tty-and-rtt-iph3e2e47fe/12.0) (snippet)
- In Apple's FaceTime/Mac guide, RTT is a way to type text during a phone call so recipients read it immediately. — [Apple: Real-Time Text (RTT)](https://support.apple.com/guide/facetime/aside/glosf936e92a/mac) (snippet)
- Live Speech (type-to-speak): on a FaceTime call the synthesized speech goes to the other participant. Otherwise it plays from the iPhone speaker. US carrier AT&T documents using Live Speech to type during calls. — [Apple Support: Live Speech](https://support.apple.com/en-ae/guide/iphone/iphcf92d2d9b) (snippet); [AT&T device support](https://www.att.com/device-support/article/132423/apple/iphone-xs/)
- Pakistan: searches returned only 5G news, such as Jazz announcing iPhone 5G compatibility in May 2026 for supported iPhones on the latest iOS. Nothing on RTT. — [Jazz media center, May 2026](https://jazz.com.pk/media-center/detail/iphones-now-compatible-with-jazz-5g-as-pakistanwide-rollout-progresses); [ProPakistani, 12 May 2026](https://propakistani.pk/2026/05/12/iphones-now-compatible-with-jazz-5g-as-pakistan-wide-rollout-progresses/amp/)
- Live Listen sends audio captured by the iPhone mic to AirPods, Beats or compatible hearing aids. With iOS 26 and watchOS 26, Live Listen can be started from Apple Watch, and Live Captions of the conversation can be viewed on the watch. — [iPhone Life, Sept 2025](https://iphonelife.com/content/how-to-use-live-listen-apple-watch); [Apple Support (Watch)](https://support.apple.com/en-au/guide/watch/apd4f5b634f3) (snippet)

### Inferences
- If no Pakistani carrier exposes the RTT toggle, which is unverified, RTT is unavailable. Even where it works, the hearing caller would have to type, which violates "the other caller changes nothing".

### Gaps
- I could not confirm RTT availability for any Pakistani carrier. Checking means looking at Settings > Accessibility > RTT/TTY on an iPhone with a Jazz, Zong, Telenor or Ufone SIM, or the carrier settings bundle.

## Q6. Frameworks and entitlements (Speech, SpeechAnalyzer, LiveCommunicationKit, default dialer), Urdu support, and how Nagish, InnoCaption, Rogervoice and Ava work on iOS

### Takeaway
Apple's speech APIs (SFSpeechRecognizer and, in iOS 26, SpeechAnalyzer/SpeechTranscriber) can transcribe audio the app *itself* has, such as its own mic, files or its own VoIP stream. They do not give access to cellular call audio. Urdu support in Apple speech APIs is unconfirmed: one Oct 2026 macOS 26 probe saw `ur_IN` listed but not downloaded, with no `ur_PK`. LiveCommunicationKit (iOS 17.4) and the iOS 26 default-dialer entitlement let an app *place* cellular calls (EU only) but document no call-audio access. Every iOS captioning app found uses a route that avoids the iPhone's cellular audio path: carrier call forwarding to the vendor's service (VoIP), a conference/merge with a captioning bridge, or the vendor's own VoIP number.

### Cited Findings
**Speech frameworks**
- SpeechTranscriber (part of SpeechAnalyzer) is available from iOS/iPadOS/macOS 26.0. It is "A speech-to-text transcription module that's appropriate for normal conversation and general purposes." `supportedLocales` includes "locales that may not be installed but are downloadable". `installedLocales` lists installed ones. `isAvailable` depends on device hardware, with fallback to `DictationTranscriber` ("compatible with older devices"). The doc page's metadata lists de-DE, en-US, es-419, fr-FR, it-IT, ja-JP, ko-KR, pt-BR and zh-CN. — [Apple Developer: SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- WWDC25-era write-ups listed about 10 SpeechTranscriber languages, with no Urdu. — [Anton Gubarenko, iOS 26 SpeechAnalyzer guide](https://antongubarenko.substack.com/p/ios-26-speechanalyzer-guide); [addpipe blog](https://blog.addpipe.com/apple-speechanalyzer-api/); [Appcircle WWDC25](https://appcircle.io/blog/wwdc25-bring-advanced-speech-to-text-capabilities-to-your-app-with-speechanalyzer)
- A developer probe on 9 Oct 2026 found that SpeechTranscriber on macOS 26 "lists 45 locales on this Mac, including `ur_IN`, `hi_IN` and `mul_IN`", but "the `ur_IN` model is not downloaded here". "No public Urdu accuracy number exists." `ur_PK` is not mentioned. — [GitHub issue m2moiz/dekho-suno-jaano #282, 9 Oct 2026](https://github.com/m2moiz/dekho-suno-jaano/issues/282) (single non-Apple source; macOS not iOS)
- SFSpeechRecognizer: apps must check `SFSpeechRecognizer.supportedLocales()` at runtime, because unsupported locales return nil. The list comes from the engine at runtime. — [Apple Developer Forums: on-device languages (iOS 13)](https://developer.apple.com/forums/thread/119940); [Andy Ibanez](https://www.andyibanez.com/posts/speech-recognition-sfspeechrecognizer/). I found no source confirming `ur-PK` in SFSpeechRecognizer.

**LiveCommunicationKit and the default dialer (iOS 17.4 / iOS 26)**
- LiveCommunicationKit was introduced in iOS 17.4: "Initiate and handle VoIP and cellular conversations, coordinate them with other communication apps and the system, and get ready to be a default calling or dialer app." Apps can "Forward cellular network conversations to the system". — [Apple Developer: LiveCommunicationKit](https://developer.apple.com/documentation/livecommunicationkit)
- `TelephonyConversationManager` (iOS 26.0) is "An interface for initiating cellular network conversations". It lets "the system route the conversation to the default calling app". — [Apple Developer: TelephonyConversationManager](https://developer.apple.com/documentation/livecommunicationkit/telephonyconversationmanager)
- Default dialer app: it requires the `com.apple.developer.dialing-app` entitlement. "To test your app's behavior as a default dialer app, your Apple Developer account needs to be registered in the European Union (EU), and the test device must be located within the EU." A default dialer "focuses on presenting a dialer interface as the default way for initiating cellular network conversations". It can read recent conversation history (ConversationHistoryManager). The page says nothing about the app getting call audio. — [Apple Developer: Preparing your app to be the default dialer app](https://developer.apple.com/documentation/livecommunicationkit/preparing-your-app-to-be-the-default-dialer-app)
- Press: "iOS 26 Allows Cellular Calls and SMS/RCS in Third-Party Apps in EU". Only EU iPhone users get it, the developer account must be EU-registered, and it is not available on iPad or Mac. — [MacRumors forum/news thread](https://forums.macrumors.com/threads/ios-26-allows-cellular-calls-and-sms-rcs-in-third-party-apps-in-eu.2461213/) (search snippet; page did not load)
- The default calling app is set in iOS 26 under Settings > Apps > Default Apps > Calling. — [iDownloadBlog, 6 Feb 2026](https://www.idownloadblog.com/2026/02/06/fix-default-calling-app-issue-iphone/)

**Third-party captioning apps on iOS**
- Nagish (iOS and Android; US): captions calls on the user's *existing number*. It looks and works like a phone app. Captions are AI-generated. It is funded as FCC IP Captioned Telephone Service for registered users with hearing loss. — [Nagish App Store listing](https://apps.apple.com/app/id1514154600); [HLAA webinar](https://www.hearingloss.org/webinars/hlaa-showcase-webinar-enable-captions-on-your-existing-phone-number-with-the-nagish-mobile-app/)
- InnoCaption (US): "patented One Number System that links your existing number to our service". The user sets up *call forwarding* so calls to their number are captioned in the InnoCaption app. It offers a "cellular calling mode" for outbound calls. Free to eligible users through the FCC TRS Fund. — [InnoCaption features](https://innocaption.com/features); [InnoCaption App Store](https://apps.apple.com/app/id1333988644)
- Ava (incoming calls on iPhone): the user accepts a call *from Ava*, taps "HOLD & ACCEPT" to hold the original call, then taps "merge" to conference the calls, and opens Ava for captions. This is a conference bridge. — [Ava Help: Captioning incoming phone calls](https://help.ava.me/en/articles/5884530-captioning-incoming-phone-calls-with-ava)
- Rogervoice: described as multilingual call captions plus visual voicemail. I found no iOS-specific mechanism documentation. — [Rogervoice blog](https://rogervoice.com/us/blog/7-essential-phone-apps-for-people-with-hearing-loss); [Rylo comparison](https://rylo.com/post/innocaption-vs-rogervoice)

### Inferences
- The only iOS-feasible way to caption an ordinary SIM call without changing the remote caller's behavior is network-side. Either the user's number forwards calls to a HumSukhan VoIP/telephony backend (InnoCaption/Nagish model), or the user merges a HumSukhan bridge number into the call (Ava model). The app then transcribes audio it receives through its own VoIP (CallKit/LiveCommunicationKit) stream or on the server. Either way, it needs telephony infrastructure in Pakistan: local DIDs, carrier forwarding codes, conference-call support on Jazz, Zong, Telenor and Ufone, and per-minute costs. US apps are funded by the FCC TRS Fund, which has no Pakistani equivalent (unverified).
- Because Apple's on-device Urdu speech support is unconfirmed, especially for `ur-PK` and code-switching, a bridge architecture would likely need cloud ASR (such as Google `ur-PK` or another vendor) anyway.
- The iOS 26 default-dialer feature is EU-only and covers *initiating* calls. It does not open call audio, and it is irrelevant to Pakistan.

### Gaps
- I could not verify whether Nagish's iOS app uses forwarding or VoIP under the hood. Its App Store text says only "existing number".
- Current Ava merge steps on iOS 26/27, and whether Pakistani carriers support the 3-way conference merge on iPhone, were not verified.
- SFSpeechRecognizer Urdu (`ur-PK`) support and its on-device flag on iOS 26/27 are not documented in any source I found. This needs a runtime check on a device.

## Q7. EU DMA or other regulation giving third parties call-audio access

### Takeaway
I found no evidence. The DMA-driven change found is the iOS 26 EU-only default-dialer and cellular-calling API, which lets an app start cellular calls and read call history but documents no access to call audio. I found nothing regulatory affecting Pakistan.

### Cited Findings
- iOS 26: third-party apps in the EU can place cellular calls and handle SMS/RCS as defaults. It requires an EU-registered developer account and an EU device location for testing. — [MacRumors](https://forums.macrumors.com/threads/ios-26-allows-cellular-calls-and-sms-rcs-in-third-party-apps-in-eu.2461213/) (snippet); [Apple Developer: default dialer](https://developer.apple.com/documentation/livecommunicationkit/preparing-your-app-to-be-the-default-dialer-app)
- The default-dialer documentation describes dialer UI, call initiation without a confirmation prompt, and conversation-history access. It has no audio-access section. — [Apple Developer: default dialer](https://developer.apple.com/documentation/livecommunicationkit/preparing-your-app-to-be-the-default-dialer-app)

### Inferences
- The absence of any call-audio API even for EU default-dialer apps strongly suggests no regulation has yet forced Apple to expose cellular call audio.

### Gaps
- No source states that the default-dialer feature is DMA-mandated, though it is EU-only. I also did not search EU Commission DMA interoperability decisions (2025–2026) for any audio-related requests. Both remain unverified.
