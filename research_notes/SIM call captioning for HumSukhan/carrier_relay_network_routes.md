# Carrier, relay and network routes for getting ordinary-call audio to a captioning service (Pakistan focus, as of Oct 2026)

Research notes, compiled 2026-10-25. Scope: how commercial captioned-call products get call audio, and which network mechanisms (conference/merge, call forwarding, cloud numbers, SIP/IMS, carrier partnership) could feed the remote caller's audio to a cloud ASR for HumSukhan in Pakistan.

Method note: WebFetch failed with DNS errors (getaddrinfo ENOTFOUND) for www.docomo.ne.jp, www.twilio.com and telnyx.com, so the findings for those sites come from search-result snippets and summaries, not full page reads. Treat specific numbers from those sources (prices, defaults) as needing a check against the live page. Most Pakistani operator pages also came through as snippets only.

## Q1. How do existing captioned-telephone and relay products get call audio, and what funds them?

### Takeaway
The products fall into four groups, and none of them captions a normal cellular call without either special hardware, a provider phone number with call forwarding, the provider placing the call itself (an app dialer over data, or a relay prefix), or on-device OS-level capture:
1. **Hardware phones** (CapTel, CaptionCall). One phone line plus internet. The phone sends the far-end audio to a captioning centre.
2. **App plus a provider number plus forwarding** (ClearCaptions, InnoCaption). The user forwards their cell number to the provider's number and answers in the app.
3. **App dialer that keeps the user's number** (Nagish). Uses IP relay/IP CTS under FCC rules.
4. **On-device capture by the OS vendor** (Google Pixel Live Caption).

In every case the remote party installs nothing. What makes these services possible is regulation: the US TRS Fund pays about $0.95 per minute for ASR-only IP CTS in 2026-27, and France has required operators to provide accessible telephony since 2018.

### Cited Findings
**United States: IP CTS model and funding**
- The FCC describes IP CTS as a combination of CTS and IP Relay. In the classic setup a communications assistant (CA) re-voices the other party's speech, voice recognition transcribes the CA's voice, and captions travel over the internet. Smartphone and PC versions exist. — [FCC IP CTS consumer guide (PDF)](https://Fcc.gov/sites/default/files/ip_captioned_telephone_service.pdf)
- The FCC has certified ASR-only IP CTS. MachineGenius/Olelo got conditional certification in May 2020 for IP CTS with no CAs, delivered through an app on smartphones or tablets. InnoCaption's ASR mode was certified in December 2020, and ClearCaptions' ASR option in April 2021. — [FCC: MachineGenius certified](https://www.fcc.gov/machinegenius-certified-provide-ip-cts-using-automatic-speech-recognition); [FCC: InnoCaption certified](https://www.fcc.gov/innocaption-certified-provide-ip-cts-using-automatic-speech-recognition); [FCC: ClearCaptions certified](https://www.fcc.gov/clearcaptions-certified-provide-ip-cts-using-automatic-speech-recognition-0)
- Providers are reimbursed from the interstate TRS Fund. Users must register and self-certify eligibility. — [FCC IP CTS guide](https://Fcc.gov/sites/default/files/ip_captioned_telephone_service.pdf)
- **Compensation rates:**
  - Fund Year 2025-26: $1.05/min for ASR-only IP CTS, $1.40/min for CA-assisted, plus a $0.22 supplemental rate. Analog CTS: $3.1893/min. — [FCC DA 25-571](https://docs.fcc.gov/public/attachments/DA-25-571A1.pdf)
  - Fund Year 2026-27: $0.95/min ASR-only, $1.45 CA-assisted, $0.23 supplemental. — [FCC DA 26-516](https://docs.fcc.gov/public/attachments/DA-26-516A1.pdf) (figures from the search summary; confirm in the order text)
  - Secondary summary of the 2025-26 order — [Rolka Loube](https://rolkaloube.com/programs/federal-itrs/news/fcc-releases-2025-26-trs-fund-compensation-rates-order)

**Hardware captioned phones**
- Hamilton CapTel 2400i needs one telephone line (analog, digital, DSL, VoIP or FiOS) plus high-speed internet. Pressing the Captions button "transparently" connects the call to a captioning service, where a Captioning Assistant uses voice recognition to caption the other party. Voice goes to the earpiece and text to the screen. The service is free and runs 24/7. — [Hamilton CapTel 2400i](https://hamiltoncaptel.com/captel-phone-features.html); [Hamilton Relay: How CapTel works](https://hamiltonrelay.com/how-it-works/captel-captioned-telephone/); [Hamilton 2400i support](https://hamiltoncaptel.com/support/captioned-telephone-support-2400i/)

**App plus provider number plus call forwarding (the user stays on their own number for callers)**
- ClearCaptions Mobile: users "forward your existing mobile number to your personal ClearCaptions number" so incoming calls are captioned in the app. Once forwarding is on, the carrier's voicemail no longer answers; captioned voicemail goes to the app. The Quick Start Guide sets forwarding from the phone's own call-forwarding settings, and a carrier tip sheet lists supported carriers. — [ClearCaptions FAQ: forwarding](https://clearcaptions.com/blog/faq-items/how-do-i-forward-my-mobile-number-to-my-clearcaptions-number); [ClearCaptions Quick Start Guide (PDF)](https://clearcaptions.com/wp-content/uploads/2020/04/2092_Quick_Start_Guide_202003_V1.pdf); [ClearCaptions mobile FAQ](https://clearcaptions.com/support/faq/mobile-app/)
- InnoCaption markets "seamless call forwarding through our patented One Number system". A user community post says the app only captions calls to the InnoCaption number, so to caption calls to your regular cell number you set up carrier call forwarding. InnoCaption is funded by the FCC TRS Fund, requires identity verification, and offers CA-only, CA-priority and ASR-only modes; 911 calls always go to a CA. — [InnoCaption support](https://innocaption.com/support); [InnoCaption caption modes](https://help.innocaption.com/en/articles/9236784-what-are-the-different-caption-modes-and-how-do-i-switch-between-them); [Mayo Clinic Connect user thread](https://connect.mayoclinic.org/comment/245294/replies) (user post, low authority)
- CaptionCall Mobile also supports routing calls to an existing mobile number through call forwarding (third-party comparison). — [HearingTracker comparison](https://www.hearingtracker.com/captioned-telephones/captioncall-vs-clearcaptions)

**App dialer that keeps the user's own number**
- Nagish: free iOS/Android app that can replace the default dialer and lets users "keep your existing phone number to place and receive captioned calls". It is AI-only (vendor claim: end-to-end encrypted, no human). Per-minute costs are paid by a federally administered fund. Nagish is an FCC-certified IP Relay provider. — [HLAA webinar on Nagish with existing number](https://www.hearingloss.org/webinars/hlaa-showcase-webinar-enable-captions-on-your-existing-phone-number-with-the-nagish-mobile-app/); [Nagish App Store](https://apple.co/2G2dIBI); [DailyMoth: Nagish FCC certification](https://dailymoth.com/blog/nagish-gets-fcc-certification-as-ip-relay-provider)

**France: Rogervoice**
- Article 105 of the Loi pour une République numérique (7 Oct 2016) has required electronic communications operators to provide accessible telephony since 8 Oct 2018. — [service-public.fr](https://service-public.fr/particuliers/actualites/A12949?lang=en)
- The Fédération Française des Télécoms chose Rogervoice. Subscribers of Bouygues Telecom, Orange, SFR and EuroInformation Telecom got one free hour of calls a month at the 2018 launch. — [Siècle Digital, 2018](https://siecledigital.fr/2018/10/09/grace-a-rogervoice-les-sourds-et-malentendants-peuvent-passer-des-appels/); [Universfreebox](https://www.universfreebox.com/?p=46600)
- ARCEP's 2023 opinion (no. 2023-1767) covers a draft ordinance on a "universal telephone accessibility solution" that would succeed the Article 105 regime. — [ARCEP avis 23-1767 (PDF)](https://www.arcep.fr/uploads/tx_gsavis/23-1767.pdf)
- Rogervoice says it is AI-only, with "zero human listeners on the line". The service-public.fr description of the operator-funded service focuses on LSF/LPC interpreters, so the two framings differ. Rogervoice reports availability in 52 countries and nearly 10 million calls (2026 press release). — [Rogervoice about](https://rogervoice.com/en-int/about-us/); [Rogervoice 2026 press release (PDF)](https://rogervoice.com/wp-content/uploads/2026/05/V2_Rogervoice_CP_SEEPH_Journee_internationale_personnes_situation_handicap.pdf)

**United Kingdom: Relay UK (BT)**
- Text users dial the 18001 prefix (18000 for emergencies) in front of the number; the Relay UK app adds it automatically. A relay assistant joins the call and types what the hearing person says. — [BT SIN 359 (PDF)](https://www.bt.com/bt-plc/assets/documents/sinet/sins/downloads/359v1p11v2.pdf); [Ofcom text relay statement annex 5](https://www.ofcom.org.uk/siteassets/resources/documents/consultations/7996-text-relay-service/statement/summary/annex_5.pdf)
- Ofcom's General Conditions require providers to give customers access to a relay service, and BT runs it. This is per a consumer guide; the exact GC wording was not retrieved. — [kaeltripton.com guide](https://www.kaeltripton.com/telecoms/relay-uk-deaf-users/)

**Germany: Tess**
- Tess relay (TeScript text, TeSign video) began as a joint Deutsche Telekom and DG project in 2005. In Feb 2025 the Bundesnetzagentur secured the service for four more years, financed by telecom providers. In text mode a human interpreter places the call. — [Bundesnetzagentur](https://www.bundesnetzagentur.de/1052216); [Tess info (archive)](https://www.archiv.taubenschlag.de/cms_pics/TessInfoTestnutzer.pdf)

**Japan: NTT Docomo "Mieru Denwa" (みえる電話), a carrier network-side precedent**
- Launched officially in Feb 2019. The remote party's speech appeared as real-time text on the Docomo user's phone, and typed text could be turned into synthesized speech. Speech recognition ran in Docomo's network, so the other party needed no app. It was free and required the dedicated app and a Docomo contract. — [Appllio, Feb 2019](https://appllio.com/20190221-10962-docomo-mieru-call); [Docomo press release 2019-02-21](https://www.docomo.ne.jp/info/news_release/2019/02/21_01.html) (not fetchable, DNS failure; snippet only); [k-tai Watch](https://k-tai.watch.impress.co.jp/docs/news/1172467.html)
- Docomo announced the closure in Sept 2023 and **ended Mieru Denwa on 29 March 2024**. It pointed users to Google Pixel auto-captions, ISEC Japan's 字幕電話, and the Nippon Foundation telephone relay service (電話リレーサービス). — [Docomo news release 2023-09-25](https://www.docomo.ne.jp/info/news_release/2023/09/25_00.html) (snippet only); [iPhone Mania](https://iphone-mania.jp/news-240007/amp/)

**On-device: Google Pixel Live Caption for calls**
- Live Caption on calls runs fully on-device; Google says audio and captions never leave the phone. The other party hears an audio signal when captions are enabled. It is not meant for calls with more than one other person. Third-party calling apps can opt out of sharing audio with the OS. Initially English only. — [Android Authority](https://androidauthority.com/google-live-caption-phone-calls-1151269); [Neowin](https://www.neowin.net/news/googles-live-caption-feature-now-works-with-calls/); [Technipages](https://www.technipages.com/how-to-use-live-caption-to-transcribe-phone-calls/)

**Ava**
- Ava is microphone-based captioning for in-person, group and meeting use, with QR-code joining and type-to-speech. No source found showing it captions cellular calls. — [Ava App Store](https://apps.apple.com/us/app/ava-transcribe-voice-to-text/id1030067058); [Ava help](https://help.ava.me/en/articles/1466360-welcome-to-ava)

### Inferences
- **Which products keep the remote party unchanged:** all of them. The remote party just makes or receives a normal call. The caveat is that Pixel plays an audio notice, and relay services announce themselves.
- **Which products keep the user on an ordinary cellular call:** only on-device capture (Pixel Live Caption) and hardware line-tap phones truly do. ClearCaptions and InnoCaption-style forwarding moves the call off the native cellular leg and into a VoIP app. Nagish-style dialers place calls through the provider. In all of these the provider controls the call path, which is what gives it the audio.
- **Funding is what makes the US model work.** About $1/min of ASR captioning paid by the TRS Fund covers telephony and ASR cost. Pakistan has no comparable fund or obligation (see Q4), so a HumSukhan network route would have to be paid for by users, grants or an operator partner.
- **Docomo is the closest precedent to a Pakistani operator offering network-side captioning, and it was shut down after about 5 years.** That suggests weak carrier economics once OS-level captioning (Pixel) exists. The closure reason is not stated in the snippets I saw.

### Gaps
- Whether InnoCaption and ClearCaptions use the user's cellular minutes or only data for the forwarded leg, and the exact FCC numbering rules for IP CTS (provider-assigned 10-digit numbers vs. the user's own number). Not retrieved.
- Whether Deutsche Telekom, Vodafone, Verizon, T-Mobile or Telstra offer carrier-native captioned calls (as opposed to app partnerships). No source found in this pass; the Telekom search returned only Tess.
- KDDI and SoftBank equivalents of Mieru Denwa: not researched.
- Current Pixel Live Caption language list (Urdu support): not confirmed.

## Q2. Conference or three-way calling to a cloud number that streams audio to ASR

### Takeaway
Technically plausible and the most "no-install" route: the user merges a call to a cloud number whose media stream goes to Deepgram/Soniox. There are four main problems:
1. Jazz bills every conference leg as a separate call, so the user pays for a second leg each time.
2. The cloud leg receives the operator's bridge mix (remote caller plus user) on one track, so the ASR needs to separate speakers.
3. Pakistani DIDs from CPaaS providers are limited and come with paperwork.
4. PTA treats unlicensed international VoIP termination as illegal grey traffic.

Streaming costs are small (about $0.0035 to $0.0044/min). The telephony legs and ASR dominate the cost.

### Cited Findings
**Operator conference support in Pakistan**
- Jazz: "add up to 4 numbers on a conference call including on-net, off-net and international numbers. Each call log will be treated and charged as a new call according to the package plan." Free minutes are used first. It is available on all prepaid packages; postpaid pays Rs 50+tax/month. — [Jazz conference call](https://jazz.com.pk/postpaid/conference-call)
- Jazz standard prepaid voice is about Rs 3.50/min plus a Rs 0.15 call setup fee on most packages (2026 tariff summary). — [TechJuice on prepaid tariffs](https://www.techjuice.pk/pakistans-prepaid-mobile-tariffs-put-users-under-growing-cost-pressure/); [ProPakistani Jazz Budget](https://propakistani.pk/packages/jazz-budget/)
- Ufone (2013 data): conference of up to 6 people, activated by SMS "SUB" to 6789, one-time Rs 3+tax. Each leg is billed at the regular rate. Not available on some packages (Prepaid Life Value, U-Circle Life). This is dated. — [ProPakistani 2013](https://propakistani.pk/2013/01/31/how-to-make-conference-calls/)
- Zong conference-call terms: no source found.
- Telenor Pakistan no longer exists as a separate company. PTCL completed its acquisition on 31 Dec 2025, and Telenor Pakistan was amalgamated into PTML (Ufone) on 1 July 2026 after Islamabad High Court approval. Billing and SIM migration were still pending in the latest reports. Market share: Jazz 36.4%, Ufone+Telenor 35.9%. — [ProPakistani, 2 Jul 2026](https://propakistani.pk/2026/07/02/telenor-pakistan-formally-amalgamates-into-ptml-following-statutory-approvals/); [MEA Tech Watch, 1 Jan 2026](https://meatechwatch.com/2026/01/01/ptcl-completes-acquisition-of-100pc-issued-share-capital-of-telenor-pakistan-and-orion-towers/); [Developing Telecoms](https://developingtelecoms.com/telecom-business/operator-news/20471-telenor-pakistan-ceases-to-exist-as-ufone-merger-closes.html)

**CPaaS media streaming**
- Twilio `<Start><Stream>` (unidirectional) lets you pick `inbound_track` (the default), `outbound_track` or `both_tracks`. Inbound is the audio Twilio receives from the other party on the call; outbound is audio Twilio generates or bridges in. `both_tracks` arrives as separate media events, not pre-mixed. Bidirectional `<Connect><Stream>` gets only `inbound_track`. — [Twilio TwiML Stream docs](https://www.twilio.com/docs/voice/twiml/stream) (snippet; page not fetchable)
- Twilio also supports `<Siprec>` for forking call media to a recorder. — [Twilio Siprec](https://twilio.com/docs/voice/twiml/siprec)
- Twilio Conference participants are billed per participant-minute on top of voice minutes. A participant's caller ID must be a Twilio number or a verified caller ID. — [Twilio Conference TwiML](https://www.twilio.com/docs/voice/twiml/conference); [Twilio Participant resource](https://www.twilio.com/docs/voice/api/conference-participant-resource)
- Media Streams costs $0.0044/min and ConversationRelay $0.07/min (third-party reading of Twilio US pricing, dated 7 Oct 2026). — [Superdupr Twilio pricing 2026](https://superdupr.com/blog/twilio-pricing)
- Telnyx Media Streaming over WebSockets costs $0.0035/min and Decrypted Forking $0.0025/min (billed since 1 July 2023). Telnyx ConversationRelay is $0.05/min. — [Telnyx release note](https://telnyx.com/release-notes/media-streaming-and-decrypted-forking-service-pricing-updates); [Telnyx Voice API pricing](https://telnyx.com/pricing/call-control)

**Pakistani virtual numbers (DIDs)**
- Twilio has a Pakistan voice pricing page with number pricing; the snippet shows numbers "starting" at $1.15/month, but the number type could not be confirmed because the page did not load. Twilio's PK SMS guidelines say number portability is not available and two-way SMS is not listed as supported. — [Twilio voice pricing PK](https://www.twilio.com/voice/pricing/pk); [Twilio PK SMS guidelines](https://www.twilio.com/guidelines/pk/sms)
- Telnyx sells Pakistan numbers. It requires a name, contact number, a Telnyx-template letter of intent, and proof of address dated within the last 3 months (business buyers also give company details). — [Telnyx Pakistan DID requirements](https://support.telnyx.com/en/articles/11843465-pakistan-did-requirements); [Telnyx Pakistan numbers](https://telnyx.com/phone-numbers/pakistan)
- Telnyx says local calls cannot enter a country through international exchanges and must be routed through in-country carriers. — [Telnyx PSTN local calling](https://support.telnyx.com/en/articles/6622229-pstn-local-calling-with-telnyx)
- AVOXI (a competitor) says only PTA-licensed LDI operators may terminate international calls into Pakistan. — [AVOXI Pakistan virtual numbers](https://www.avoxi.com/local-phone-number-did-ddi/virtual-phone-number-pakistan/)

**Grey traffic, VoIP enforcement and termination rates**
- PTA and FIA regularly raid illegal VoIP gateways. PTA monitors incoming international traffic 24/7. One raid found five illegal exchanges costing about $1.7M/month (2011). — [ProPakistani 2011](https://propakistani.pk/2011/02/22/illegal-international-exchanges-busted-in-peshawar-and-karachi/); [ProPakistani Multan 2011](https://propakistani.pk/2011/08/11/illegal-gateway-exchange-ceased-in-multan/)
- PTA's mobile termination rate (local, long distance and international incoming) fell to Rs 0.30/min from July 2023. — [Dawn](https://www.dawn.com/news/1660474/pta-to-cut-mobile-termination-rates-from-jan-1); [ProPakistani 2021](https://propakistani.pk/2021/11/26/pta-reduces-mobile-termination-rates/)

**International call cost from Pakistan to a foreign DID**
- Only fragmentary, undated offers were found: Jazz postpaid "456" bundle at Rs 14.99 for 30 min to the USA/Canada, and a "24 Ghanta IDD" offer at Rs 2.35+tax/min. — [PhoneWorld](https://www.phoneworld.com.pk/jazz-postpaid-brings-affordable-calling-rates-to-usa-and-canada/); [ProPakistani](https://propakistani.pk/?p=19954)

### Inferences
- **Does the merged cloud leg get the remote caller's audio?** Yes, in principle. In a standard GSM/IMS multiparty call the network bridge sends each participant a mix of all the others. The cloud leg would therefore receive remote caller plus user mixed on Twilio's/Telnyx's `inbound_track`. This is standard 3GPP multiparty behaviour from general knowledge, not verified in a cited source here. HumSukhan would need diarization, or to suppress the user's own voice (for example by comparing with the phone mic signal), to caption only the remote caller.
- **Cost per captioned minute of a merged call:**
  - Second cellular leg: about Rs 3.5/min on Jazz to a local DID. More if the DID is foreign and billed as IDD.
  - CPaaS inbound minutes: rate unknown for PK.
  - Streaming: about $0.0035 to $0.0044/min.
  - ASR: Deepgram/Soniox, not covered here.
  - Total: likely a few US cents per minute, plus the user's airtime.
- **The UX is poor for incoming calls.** The user must answer, put the caller on hold, dial the cloud number, then merge, which is hard to do quickly. Merge on prepaid depends on the package (Ufone excluded some packages; Zong unknown). The remote caller may hear hold or merge tones. Android does let an app place the second call and merge programmatically only if it is the default dialer (InCallService) — this is outside this note's scope.
- **A foreign DID is the easiest to buy but makes the user pay IDD rates.** A legitimate Pakistani DID has to come through PTA-licensed carriers (LDI or local), which limits CPaaS inventory. A CPaaS that hands traffic to Pakistan over unlicensed VoIP would risk the grey-traffic problem; buying from a reputable CPaaS that uses licensed in-country carriers avoids this, but supply is uncertain.
- **Latency:** a PSTN/mobile conference bridge plus a CPaaS hop typically adds a few hundred ms one-way, on top of ASR latency. This is a general engineering estimate, not sourced. A foreign DID (for example US) adds international transit.

### Gaps
- Twilio/Telnyx/Vonage/Plivo current Pakistan DID types (mobile vs. geographic), inbound per-minute price, and whether they support voice inbound at all. Twilio and Telnyx pages failed to load; verify directly.
- Whether Twilio's PK numbers are allowed for the conference-merge use case (caller-ID and regulatory restrictions).
- Zong and Ufone current conference terms on prepaid in 2026, and post-merger PTML policy for Telenor SIMs.
- Measured latency of a Pakistan mobile conference leg into a CPaaS: no data found.

## Q3. Call forwarding to a cloud number that bridges to the user

### Takeaway
This is exactly how ClearCaptions and InnoCaption work in the US (forward your cell number to the provider's number and answer in the app). It can be set up with standard GSM forwarding codes on any Pakistani network. The cost is losing the native call experience: the user answers in a VoIP app over data, or the cloud calls the user back on a second cellular leg, which usually shows the cloud number instead of the original caller ID. The user also pays for the forwarded leg, and it is international if the cloud number is abroad.

### Cited Findings
- **ClearCaptions:** forward your mobile number to your ClearCaptions number; captions appear in the app; carrier voicemail stops answering forwarded calls. Setup uses the phone's Call Forwarding setting, and a carrier tip sheet exists. — [ClearCaptions FAQ](https://clearcaptions.com/blog/faq-items/how-do-i-forward-my-mobile-number-to-my-clearcaptions-number); [Quick Start Guide](https://clearcaptions.com/wp-content/uploads/2020/04/2092_Quick_Start_Guide_202003_V1.pdf)
- **InnoCaption:** carrier forwarding to the InnoCaption number ("One Number" system). — [InnoCaption support](https://innocaption.com/support)
- **GSM MMI forwarding service codes (3GPP TS 22.030 structure):** 21 is unconditional, 67 is on busy, 61 is on no reply. Registration uses `**SC*number#` and erasure uses `##SC#`. The codes 62 (not reachable) and 002 (all forwarding) were not shown in the retrieved source. — [oFono MMI codes doc](https://git.sysmocom.de/sysmocom/ofono/src/branch/master/doc/mmi-codes.txt); [3GPP 22-series](https://www.3gpp.org/DynaReport/22-series.htm)
- Pakistan-specific forwarding codes and charges from Jazz/Zong/Ufone: not found on official pages (only Scribd lists of "SIM codes"). — [Scribd SIM codes](https://www.scribd.com/document/435372936/sim-codes) (low authority)

### Inferences
- Conditional forwarding (**61 no-answer, **67 busy) does not help in practice: the call reaches the cloud only after the user fails to answer. Unconditional forwarding (**21) sends every call to the cloud, and the user then answers in the HumSukhan app (VoIP over WebRTC or SIP). That gives clean, separate remote-party audio, which is the best ASR input, but it is no longer the "ordinary SIM call" experience.
- **Calling back over a second cellular leg:** the cloud dials the user's own SIM and bridges. This keeps a normal ringing experience, but caller ID would be the cloud number unless the CPaaS passes through the original CLI. Passing through the original CLI on PSTN egress in Pakistan may count as spoofing, and Twilio restricts caller ID to owned or verified numbers (see Q2).
- **Cost:** the forwarded leg is billed to the user as a normal (or IDD) call, plus CPaaS inbound and outbound minutes.
- **Remote-party transparency:** forwarding is invisible to the remote party apart from slightly longer call setup.

### Gaps
- Official Jazz, Zong and Ufone forwarding charges, and whether forwarding to international numbers is allowed on prepaid.
- Whether PTA rules allow CLI passthrough from a CPaaS onto Pakistani networks.

## Q4. Carrier/IMS-level captioning, Pakistani law (interception, recording, data protection), disability obligations, and RTT/TTY

### Takeaway
Technically, an operator could fork call media in its IMS core to an ASR service, as Docomo did from 2019 to 2024. But there is no Pakistani legal mandate, no relay fund, and no known operator plan. The 1996 Telecom Act and the Investigation for Fair Trial Act 2013 tie interception to the state. Pakistan still has no enacted data protection law as of mid-2026. The only disability-telecom activity found is PTA and Zong partnerships for sign-language interpretation at offices and service centres. No RTT or TTY on Pakistani networks was found. A carrier value-added service is therefore a partnership pitch, not something HumSukhan can rely on in 2026.

### Cited Findings
**Precedent**
- Docomo Mieru Denwa did network-side ASR so the remote party needed no app; it ran 2019 to 29 Mar 2024. — [Appllio](https://appllio.com/20190221-10962-docomo-mieru-call); [iPhone Mania](https://iphone-mania.jp/news-240007/amp/)
- France's model is operator-funded accessibility under Article 105 (operators collectively chose Rogervoice). — [service-public.fr](https://service-public.fr/particuliers/actualites/A12949?lang=en); [Siècle Digital](https://siecledigital.fr/2018/10/09/grace-a-rogervoice-les-sourds-et-malentendants-peuvent-passer-des-appels/)
- Germany's model is BNetzA-secured Tess relay financed by providers. — [Bundesnetzagentur](https://www.bundesnetzagentur.de/1052216)

**Interception and lawful access**
- Section 54 of the Pakistan Telecommunication (Re-organization) Act 1996 lets the federal government authorise interception or tracing of calls for national security or crime investigation. Operators get lawful-interception directives under section 8, and the MRTT Regulations (Reg. 4) require certain operators to build interception-enabling systems. — [Telenor Authority Request Legal Overview, Pakistan, Mar 2017 (PDF)](https://www.telenor.com/binaries/esg/governance/handling-access-requests-from-authorities/Authority-Request-Legal-Overview_March-2017-pakistan.pdf)
- The Investigation for Fair Trial Act 2013 requires a High Court warrant for interception. In 2024, SRO 1005(I)/2024 (ISI surveillance under s.54) was challenged, and a June 2024 interim order limited agencies to Fair Trial Act warrants. The final ruling was not found. — [Global Voices, 2024](https://advox.globalvoices.org/2024/07/18/pakistans-intelligence-agencies-gain-legal-cover-for-surveillance/); [Dawn](https://www.dawn.com/news/amp/1845339); [IBA](https://www.ibanet.org/legal-landscape-for-privacy-surveillance-in-Pakistan)

**Recording consent and data protection**
- A commercial recording-law site says recording a private call without all parties' consent is an offence, linked to PECA 2016 s.19. It also cites a March 2026 Supreme Court ruling (PLJ 2026 SC 114) treating all-party consent as an Article 14 privacy matter. **This is a single, low-authority source and could not be corroborated; verify on pakistancode.gov.pk.** — [RecordingLaw Pakistan](https://www.recordinglaw.com/world-laws/world-recording-laws/pakistan-recording-laws/)
- Pakistan still has no comprehensive enacted personal data protection law as of May 2026. The Personal Data Protection Bill (drafts since 2018, latest 2023) has not passed Parliament. PECA was amended in 2025. — [RecordingLaw data privacy](https://www.recordinglaw.com/world-laws/world-data-privacy-laws/pakistan-data-privacy-laws/); [DLA Piper Data Protection: Pakistan](https://www.dlapiperdataprotection.com/?c=PK); [Chambers 2025 Pakistan guide](https://practiceguides.chambers.com/practice-guides/data-protection-privacy-2025/pakistan)
- Telemarketing is regulated by PTA under the 1996 Act (registration, consent, do-not-call list). — [Telnyx Pakistan page](https://telnyx.com/phone-numbers/pakistan) (secondary)

**Disability and accessibility in Pakistani telecom**
- PTA signed an MoU with DeafTawk (Jan 2025) for sign-language interpretation at PTA offices and AI text-to-sign tools on PTA platforms. PTA's chairman said "Accessibility is a fundamental right." — [PTA press release](https://pta.gov.pk/category/pta-signs-mou-with-deaftawk-to-advance-accessibility-for-the-special--need-hearing-impairments-867832596-2025-01-03); [Arab News](https://www.arabnews.com/node/2585023/amp)
- PTA signed a collaboration with ConnectHear (2025) on accessibility for women and girls with hearing impairments. — [APP](https://www.app.com.pk/?p=1198739)
- Zong and ConnectHear rolled out an AI Pakistan Sign Language system in customer service centres in Islamabad, Lahore and Karachi (Sept 2026). — [Digital Pakistan](https://digitalpakistan.pk/zong-connecthear-launch-ai-sign-language-service/)
- PTA's International Day of Persons with Disabilities release on digital inclusion. — [PTA press release](https://pta.gov.pk/en/media-center/single-media/international-day-of-persons-with-disabilities-pta-for-disability-inclusion--digital-accessibility--031220)

**RTT/TTY and VoLTE**
- Jazz tested VoLTE in 2017, launched it in 2019, and launched VoLTE roaming with AT&T in the US in Nov 2023. No RTT mention found for any Pakistani operator. — [Jazz media centre](https://jazz.com.pk/media-center/detail/jazz-pioneers-volte-roaming-services-in-partnership-with-att-usa); [ProPakistani 2017](https://propakistani.pk/2017/05/30/jazz-soon-enable-volte-across-network/)
- A Zong VoLTE rollout article carries the note "This is fake and sponsored article", so it is unreliable. — [ProPakistani](https://propakistani.pk/?p=135033)

### Inferences
- **What an operator would build:** an IMS MRF/media-server fork, or SIPREC from the operator's SBC, of VoLTE calls for opted-in subscribers, sent to a captioning provider. This is the same function as lawful-intercept media duplication, which is why regulators would examine it closely. Precedent shows it can be done (Docomo). In Pakistan it would need PTA approval as a VAS, explicit subscriber opt-in, a recording/consent position, and probably in-country data processing. That last point is uncertain given there is no data protection law and given cloud ASR hosted abroad (Deepgram/Soniox).
- **Most realistic partner path:** Jazz (largest operator, VoLTE in place) or Zong (already partnering with ConnectHear on accessibility), possibly with Universal Service Fund (USF) or Ignite grant funding. This is speculative; no source shows USF funding relay or captioning.
- **Consent:** because captioning sends the remote party's voice to a third-party cloud, HumSukhan should treat it as call recording and processing. An audible or spoken notice to the remote party (as Pixel uses) would reduce legal risk, though it changes the "remote party unaware" property.
- **No RTT/TTY found:** a network text fallback is not available, so voice-to-text ASR is the only route.

### Gaps
- PTA Universal Service Fund (USF) programmes for disability telecom: not found.
- Any Pakistani ICT accessibility policy or law that obliges operators to provide relay or captioning: none found. The ICT Rights of Persons with Disability Act (2020, ICT territory) was not checked.
- PTA rules on call recording specifically (as distinct from interception) and VAS licensing for media forking: not found.
- Status of the PECA s.19 and Supreme Court 2026 consent claims: unverified.
- Whether any Pakistani operator has deployed RTT (GSMA IR.92 RTT) or supports TTY/CTM: no evidence either way.

## Q5. Cost per minute (CPaaS streaming plus telephony) and latency added by a PSTN conference leg

### Takeaway
CPaaS media streaming is cheap: Telnyx $0.0035/min, Twilio about $0.0044/min. The real costs are the user's extra cellular leg (about Rs 3.5/min on Jazz to a local number, more for IDD), CPaaS inbound/outbound minutes for PK (unpublished in what I could retrieve), and ASR. For comparison, the US pays $0.95/min for ASR-only IP CTS. I found no measured latency data for Pakistani conference legs.

### Cited Findings
- Telnyx Media Streaming $0.0035/min; Decrypted Forking $0.0025/min. — [Telnyx pricing](https://telnyx.com/pricing/call-control); [Telnyx release note](https://telnyx.com/release-notes/media-streaming-and-decrypted-forking-service-pricing-updates)
- Twilio Media Streams $0.0044/min, local-number inbound $0.0085/min (US), recording $0.0025/min (third-party summary, Oct 2026). — [Superdupr](https://superdupr.com/blog/twilio-pricing)
- Twilio conference participants are billed per participant-minute in addition to voice minutes. — [Twilio Conference docs](https://www.twilio.com/docs/voice/twiml/conference)
- Jazz charges each conference leg as a new call (about Rs 3.50/min plus Rs 0.15 setup on most packages). — [Jazz](https://jazz.com.pk/postpaid/conference-call); [TechJuice](https://www.techjuice.pk/pakistans-prepaid-mobile-tariffs-put-users-under-growing-cost-pressure/)
- US benchmark: IP CTS ASR-only $0.95/min (FY2026-27). — [FCC DA 26-516](https://docs.fcc.gov/public/attachments/DA-26-516A1.pdf)

### Inferences
- Rough per-minute cost of the conference route: user airtime of about Rs 3.5 (about US$0.012 at roughly Rs 280/$, an exchange rate assumed and not sourced), plus CPaaS PK inbound (unknown), plus $0.0035 to $0.0044 streaming, plus ASR. This is plausibly under $0.05/min in total, roughly 20x cheaper than the US subsidy rate. Who pays is the open question.
- Latency: a conference bridge plus CPaaS hop probably adds roughly 100 to 300 ms before audio reaches the ASR. A US-hosted DID adds international transit. This is an unsourced engineering estimate and should be measured with a pilot call.

### Gaps
- CPaaS Pakistan inbound per-minute rates (Twilio/Telnyx pages unreachable).
- Measured end-to-end caption latency for any network-route product (FCC or vendor data not retrieved).
- Current Pakistani prepaid IDD rate to US/EU numbers in 2026.
