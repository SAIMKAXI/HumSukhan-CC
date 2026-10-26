# Cloud ASR services for Pashto and Pakistani Punjabi (Shahmukhi), and options for collecting and licensing speech data in Pakistan (as of 26 Oct 2026)

**Method and reliability note (read first).** In this environment, WebFetch and curl failed (DNS errors or proxy 403) for almost every vendor site: developers.deepgram.com, soniox.com, docs.speechmatics.com, elevenlabs.io, learn.microsoft.com, docs.azure.cn, docs.cloud.google.com, docs.aws.amazon.com, assemblyai.com, sarvam.ai and arxiv.org. **Unless a finding says otherwise, it comes from web-search result snippets of the cited page, not from a full read of that page. Each one is tagged [snippet].** One source was read in full: the arXiv 2604.04598 abstract, via the Hugging Face papers mirror (hf://papers/2604.04598). I also ran Hugging Face Hub dataset searches directly. The evidence date is 26 Oct 2026 unless a finding gives another date.

---

## 1. Cloud ASR support matrix: Pashto (ps) and Punjabi (pa / pnb, Shahmukhi)

### Takeaway
Deepgram nova-3, the engine HumSukhan already uses, added **Pashto (ps, ps-AF; changelog 27 Aug 2026)** and **Punjabi (pa, pa-IN; changelog 5 Aug 2026)** for both batch and streaming. That makes it the cheapest path with the least integration work. However, every vendor's "Punjabi" is Indian Punjabi (pa-IN, Gurmukhi script). **No cloud vendor I checked lists a Pakistani Punjabi locale (pa-Arab-PK / pnb) or output in Shahmukhi script.** Pakistani Punjabi will need either Gurmukhi→Shahmukhi transliteration or an own or fine-tuned model. Pashto is listed by Deepgram, Azure (ps-AF), AWS (batch only), AssemblyAI (low-accuracy tier) and ElevenLabs Scribe, but vendor accuracy on Pashto is poor (FLEURS WER is about 38% or worse even in a vendor's own benchmark).

### Cited Findings

**Deepgram (nova-3)**
- Changelog, 27 Aug 2026: "Nova-3 Adds Assamese, Mongolian, and Pashto…". It lists "Pashto (ps, ps-AF), available for batch and streaming", used by setting model=nova-3 plus the language code [snippet] — [Deepgram changelog 2026-08-27](https://developers.deepgram.com/changelog/2026/8/27)
- Changelog, 5 Aug 2026 ("Nova-3 Model Update"): Nova-3 *monolingual* models now support Punjabi (pa, pa-IN) and Nepali (ne), batch and streaming [snippet] — [Deepgram changelog 2026-08-05](https://developers.deepgram.com/changelog/2026/8/5)
- One search summary tied Punjabi to the Self-Hosted release 260812 (12 Aug 2026). A separate snippet of the 5 Aug changelog shows it as a hosted Nova-3 update. My reading is that the language reached hosted first and self-hosted on 12 Aug, but this is unverified [snippet] — [Deepgram changelog 2026-08-12](https://developers.deepgram.com/changelog/2026/8/12)
- Per a search snippet, the Models & Languages Overview lists "Pashto: ps, ps-AF" and "Punjabi: pa, pa-IN" [snippet] — [Deepgram Models & Languages Overview](https://developers.deepgram.com/docs/models-languages-overview)
- Deepgram's Punjabi product page gives the writing system as **Gurmukhi** [snippet] — [Deepgram Punjabi STT page](https://deepgram.com/product/speech-to-text/punjabi)
- A third-party open-source tool (subgeneratorr v3.1.0) added Punjabi (pa) as part of "Deepgram's August 2026 Nova-3 expansion (batch and streaming)". It did not verify Punjabi transcription output itself [snippet] — [newreleases.io subgeneratorr v3.1.0](https://newreleases.io/project/github/tylerbcrawford/subgeneratorr/release/v3.1.0)
- No Pashto/Punjabi accuracy figure for nova-3 was found. ElevenLabs' competitor table lists **Deepgram Nova-2 at 100% WER on FLEURS Pashto**. That figure is for the older model, not nova-3 [snippet] — [ElevenLabs Pashto STT page](https://elevenlabs.io/speech-to-text/pashto)
- Pricing (third-party, Oct 2026): Nova-3 monolingual streaming $0.0048/min and batch $0.0043/min. Multilingual streaming $0.0058/min and batch $0.0052/min, pay-as-you-go [snippet] — [Activepieces, 20 Oct 2026](https://www.activepieces.com/blog/deepgram-pricing-2026-per-minute-rates-and-add-ons.md); [HappyRobot](https://www.happyrobot.ai/hub/deepgram-pricing). This **conflicts with** Soniox, which puts Deepgram multilingual streaming at $0.0092/min [snippet] — [Soniox vs Deepgram pricing](https://soniox.com/pricing/stt/soniox-vs-deepgram). Pashto and Punjabi are *monolingual* models, so the monolingual rate presumably applies (inference).
- Data use: Deepgram's Model Improvement (Partnership) Program can be opted out with `mip_opt_out=true`. Sources differ on whether opting out raises the price or only forgoes a discount. A third-party source says opted-out audio is kept only long enough to process the request [snippet] — [Deepgram MIP docs](https://developers.deepgram.com/docs/the-deepgram-model-improvement-partnership-program); [Deepgram changelog 2025-07-31](https://developers.deepgram.com/changelog/2025/7/31); [convertaudiototext](https://convertaudiototext.com/blog/opt-out-of-ai-training-with-your-audio)

**Google Cloud Speech-to-Text v2 (Chirp 2 / Chirp 3)**
- The Chirp 3 docs list **Punjabi (Gurmukhi, India), pa-Guru-IN, in Preview**. **Pashto did not appear** in any cached Chirp 3 transcription or diarization language list [snippet] — [Chirp 3 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3); [Chirp 3 (it)](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3?hl=it)
- Chirp 3 supports StreamingRecognize, Recognize and BatchRecognize. It is V2-only, with diarization and automatic language detection. Regions: US/EU multi-region GA, asia-northeast1 and asia-southeast1 GA, asia-south1 Preview. Google says the Locations API is the authoritative source for languages by model [snippet] — [Chirp 3 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3?authuser=4)
- Chirp 2: language coverage differs by method (StreamingRecognize < Recognize < BatchRecognize). No ps-AF row was visible in the snippets. Regions: us-central1, europe-west4, asia-southeast1 [snippet] — [Chirp 2 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-2)
- No pa-Arab-PK / pnb / Shahmukhi locale was found for any Chirp model [snippet] — [Chirp 3 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3)
- Price: Chirp 3 is about $0.016/min (reseller listing, "Released May 5, 2026"). V2 dynamic batch is quoted at $0.003–$0.004/min, and sources conflict. No official pricing page was reachable [snippet] — [OpenRouter Chirp 3](https://openrouter.ai/models/google/chirp-3); [convertaudiototext pricing 2026](https://convertaudiototext.com/blog/speech-to-text-api-pricing-2026); [smallest.ai](https://smallest.ai/blog/is-google-cloud-speech-to-text-still-the-right-choice)

**Google Gemini (Gemini 3.5 Transcribe; Gemini audio understanding)**
- Gemini 3.5 Transcribe: "automatic detection of 85+ languages, handling of multi-language code-switching, speaker identification, word-level timestamps". A live variant (`gemini-3.5-transcribe-live`) runs over WebSockets, with 10-minute sessions and no diarization or timestamps. The file model accepts up to 1 h per request. Public preview from 26 Aug 2026, per secondary sources [snippet] — [Gemini API model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-transcribe); [eesel.ai review](https://eesel.ai/blog/gemini-3-5-transcribe)
- Price (secondary): about $0.005/min blended for the file model and about $0.009/min for live. Another source gives $2 per 1M audio input tokens (about $0.003/min) plus $12 per 1M output tokens [snippet] — [eesel.ai](https://eesel.ai/blog/gemini-3-5-transcribe); [relevantaudience](https://www.relevantaudience.com/ai/gemini-3-5-transcribe-thai-supported-language/)
- I could not confirm whether Pashto or Punjabi are among the 85+ languages (gap).
- ElevenLabs' vendor table: **Gemini Flash 2 at 42.9% WER on FLEURS Pashto and 11.7% on FLEURS Punjabi** [snippet] — [ElevenLabs Pashto](https://elevenlabs.io/speech-to-text/pashto); [ElevenLabs Punjabi](https://elevenlabs.io/speech-to-text/punjabi)
- A developer-forum bug report says Gemini *audio generation* (TTS) renders Pashto with Urdu/Arabic phonemes. This is anecdotal and about TTS, not ASR [snippet] — [Google AI dev forum](https://discuss.ai.google.dev/t/bug-gemini-audio-generates-urdu-arabic-phonemes-for-pashto-text/144191)

**Microsoft Azure AI Speech**
- The Chinese-localised language-support tables list **ps-AF (Pashto, Afghanistan) ✅** and **pa-IN (Punjabi, India) ✅** under speech-to-text. The feature columns (real-time, fast transcription, custom speech) were not visible in the snippets, so real-time support is **unconfirmed** [snippet] — [Azure language support (docs.azure.cn)](https://docs.azure.cn/zh-cn/ai-services/speech-service/language-support?tabs=stt); [Microsoft Learn](https://learn.microsoft.com/en-nz/azure/cognitive-services/speech-service/supported-languages)
- No Pakistani Punjabi locale was found. A Microsoft Q&A thread warns that some Indic locales may detect sentence boundaries without producing the expected Unicode output, so test before relying on it [snippet] — [MS Q&A](https://learn.microsoft.com/en-us/answers/a/1897329)
- Pricing and retention for Azure were not retrieved (gap).

**AWS Amazon Transcribe**
- The current English docs list **Pashto (ps-AF) and Punjabi (pa-IN) as batch only**, with no streaming and no other features. The China mirror (docs.amazonaws.cn) shows "batch, streaming*" for both, so the sources conflict. Treat both as batch-only [snippet] — [AWS Transcribe supported languages](https://docs.aws.amazon.com/transcribe/latest/dg/supported-languages.html); [AWS China mirror](https://docs.amazonaws.cn/en_us/transcribe/latest/dg/supported-languages.html)

**AssemblyAI**
- Urdu is in the 18-language Universal-3.5 Pro set. **Punjabi and Pashto are only in the Universal-2 "Fair accuracy (>50% WER)" tier.** A support FAQ dated Oct 2025 lists "Panjabi, Pashto, Urdu" among the 99 Universal languages [snippet] — [AssemblyAI supported languages](https://www.assemblyai.com/docs/pre-recorded-audio/supported-languages.md); [AssemblyAI FAQ](https://www.assemblyai.com/docs/faq/what-languages-do-you-support-)
- Streaming support for Pashto/Punjabi was not confirmed (gap). AssemblyAI's Pashto marketing page claims automatic language detection for Pashto [snippet] — [AssemblyAI Pashto](https://www.assemblyai.com/languages/pashto)

**ElevenLabs Scribe**
- Scribe (batch, v1/v2) "supports 99 languages", and both Pashto and Punjabi have product pages [snippet] — [ElevenLabs Pashto](https://elevenlabs.io/speech-to-text/pashto); [ElevenLabs Punjabi](https://elevenlabs.io/speech-to-text/punjabi)
- ElevenLabs' own FLEURS benchmarks: **Pashto: Scribe v1 37.8% WER (Common Voice 37.1%), Gemini Flash 2 42.9%, Whisper large-v3 94.3%, Deepgram Nova-2 100%. Punjabi: Scribe v1 11.6%, Gemini Flash 2 11.7%, Whisper large-v3 92.9%.** The Punjabi page headline claims 3.1% FLEURS WER, which contradicts its own table [snippet] — same pages
- Scribe v2 Realtime (launched Nov 2025) covers 90+ languages, including 11 Indian languages, "Punjabi and Sindhi" among them. **Pashto was not mentioned** for Realtime [snippet] — [CXOToday](https://cxotoday.com/media-coverage/elevenlabs-launches-scribe-v2-realtime-its-most-advanced-low-latency-speech-to-text-model/); [AlternativeTo, Nov 2025](https://alternativeto.net/news/2025/11/elevenlabs-launches-scribe-v2-realtime-its-latest-ultra-low-latency-speech-to-text-model)
- Price: Scribe v2 Realtime $0.39/h (about $0.0065/min) on the API pricing page, or $0.28/h on annual Business plans. Zero-retention mode, plus EU and India data residency, is Enterprise only [snippet] — [ElevenLabs API pricing](https://elevenlabs.io/pricing/api); [ElevenLabs realtime STT](https://elevenlabs.io/realtime-speech-to-text)

**Soniox**
- Soniox has Punjabi pages claiming real-time streaming, Punjabi–English code-switching in one stream, and handling of the Majhi and Malwai varieties. It claims 1.25% Punjabi WER against 3.24% (OpenAI) and 1.71% (Speechmatics), which is a vendor claim. Real-time price is quoted from about $0.12/h [snippet] — [Soniox Punjabi voice agents](https://soniox.com/speech-to-text/use-cases/voice-agents/punjabi); [Soniox vs OpenAI (Punjabi)](https://soniox.com/compare-stt/soniox-vs-openai/punjabi); [Soniox vs Speechmatics (Punjabi)](https://soniox.com/compare-stt/soniox-vs-speechmatics/punjabi)
- Soniox has a Deaf/hard-of-hearing captioning use-case page for Punjabi [snippet] — [Soniox App DHH Punjabi](https://soniox.com/soniox-app/for/deaf-and-hard-of-hearing-travel-captions-and-translation-in-punjabi)
- **No evidence of Pashto support** was found (60+ languages overall; Persian is listed) [snippet] — [Soniox Persian](https://soniox.com/speech-to-text/use-cases/voice-agents/persian)

**Speechmatics**
- Claims 55+ languages, with availability depending on contract. Pashto/Punjabi rows were not visible in snippets. The 2022 expansion to 50 languages did not include them [snippet] — [Speechmatics languages](https://www.speechmatics.com/languages); [Speechmatics docs](https://docs.speechmatics.com/introduction/supported-languages); [SpeechTechMag](https://www.speechtechmag.com/Articles/News/Speech-Technology-News/Speechmatics-Adds-Support-for-14-Languages-155051.aspx)
- Soniox's comparison pages imply Speechmatics supports Punjabi (1.71% WER, a Soniox claim) [snippet] — [Soniox vs Speechmatics](https://soniox.com/compare-stt/soniox-vs-speechmatics/punjabi)

**OpenAI**
- gpt-4o-transcribe is priced by tokens: $6.00 per 1M audio input tokens, $2.50 per 1M text input, $10.00 per 1M text output. That is about $0.006/min by aggregator estimate. gpt-realtime-whisper costs $0.017/min [snippet] — [OpenAI gpt-4o-transcribe](https://developers.openai.com/api/docs/models/gpt-4o-transcribe); [OpenAI gpt-realtime-whisper](https://developers.openai.com/api/docs/models/gpt-realtime-whisper.md); [CostGoat](https://costgoat.com/pricing/openai-transcription)
- No per-language Pashto/Punjabi figure for gpt-4o-transcribe was found. Whisper large-v3 is 94.3% (Pashto) and 92.9% (Punjabi) WER on FLEURS per ElevenLabs. An independent paper finds **Whisper produces Pashto script in ≤0.8% of utterances** (see §2) [snippet] — [ElevenLabs Pashto](https://elevenlabs.io/speech-to-text/pashto)

**Sarvam AI (India)**
- Saaras v3 covers "23 languages (22 Indian + English)". Sarvam has a Punjabi page highlighting code-mixing and dialects. Pricing is ₹30/h for STT and ₹45/h with diarization, billed per second [snippet] — [Sarvam Punjabi](https://www.sarvam.ai/apis/speech-to-text/punjabi); [Sarvam pricing](https://docs.sarvam.ai/api/getting-started/pricing.md); [AWS Marketplace Saaras](https://aws.amazon.com/marketplace/pp/prodview-6a2ei6d2iimli)
- Sarvam serves the Indian languages of the Eighth Schedule, where Punjabi is Gurmukhi. No Pashto support was found. The output script was not confirmed as Gurmukhi (gap). Reverie was not researched (gap).

**Other**
- Phonexia lists Pashto among its newer transcription languages (on-prem/enterprise vendor) [snippet] — [Phonexia blog](https://phonexia.com/blog/phonexia-releases-new-languages-for-its-most-accurate-speech-transcription)
- Proto (proto.cx) lists Punjabi (Pakistan) as "in development", with a baseline of 48.5% WER before fine-tuning [snippet] — [Proto Punjabi](https://proto.cx/languages/punjabi)

### Inferences
- **Quickest option for streaming captions:** Deepgram nova-3 `language=ps` and `language=pa` through HumSukhan's existing streaming pipeline. This is a one-parameter change, pending HumSukhan's own WER test. Because these are *monolingual* models, they likely will not handle Urdu/English code-switching. The current Urdu/English bilingual path probably cannot be reused for Pashto+Urdu without a language-ID switch.
- For **Pakistani Punjabi**, every option outputs Gurmukhi (or is unconfirmed), and FLEURS Punjabi is Indian Punjabi. Pakistani Punjabi has more Urdu/Perso-Arabic vocabulary and different dialects (Majhi/Lahori, Saraiki-adjacent). Plan on (a) Gurmukhi→Shahmukhi transliteration as a post-processing step, which the LUMS paper says recovers up to 25 WER points for script issues (§2), and (b) an in-house evaluation set of Pakistani speech.
- For **Pashto**, vendor FLEURS numbers (about 38–43% WER at best) suggest captions will be hard to read. FLEURS Pashto is Afghan (ps-AF) read speech, and Pakistani Pashto (Yusufzai/Peshawar dialects) may differ.
- **Streaming candidates:** Deepgram (ps, pa), Soniox (pa), ElevenLabs Scribe v2 Realtime (pa), Google Chirp 3 (pa-Guru-IN, Preview), Gemini 3.5 Transcribe live (languages unconfirmed), and possibly Azure (unconfirmed). AWS is batch only.

### Gaps
- Real-time and fast-transcription status of Azure ps-AF and pa-IN, plus Azure price and retention: Microsoft Learn was unreachable.
- Whether Chirp 2 or Chirp 3 supports ps-AF in any method: Locations API or docs not reachable.
- Soniox and Speechmatics official language lists (Pashto status unknown).
- Whether Gemini 3.5 Transcribe's 85+ languages include ps and pa, and the script it outputs for Punjabi.
- Actual script of Deepgram nova-3 `pa` output, and nova-3 accuracy on ps/pa. Needs an empirical test.
- OpenAI API data retention policy (not retrieved). Data-retention terms for Google, Azure, AWS, AssemblyAI and Soniox were not retrieved.
- Reverie Language Technologies was not researched.

---

## 2. Independent evaluations of ASR on Pashto and Punjabi

### Takeaway
There are no Artificial Analysis or Open ASR Leaderboard results specific to Pashto or Punjabi. The best independent evidence is a set of 2026 academic papers. They show Whisper-family models (and so likely OpenAI's API family) **fail at the script level** on Pashto, Punjabi and Sindhi. Meta's SeamlessM4T, MMS and OmniASR do much better, and no model is production grade.

### Cited Findings
- arXiv 2604.04598 (Hanif Rahman, 6 Apr 2026), "Benchmarking Multilingual Speech Models on Pashto", **read in full via the HF papers mirror**. Ten models were evaluated on FLEURS Pashto and filtered Common Voice 24:
  - Zero-shot Whisper WER is 90–297%, with Whisper-medium at 461% on CV24 (decoder looping).
  - SeamlessM4T-v2-large scores **39.7% WER on CV24** (best zero-shot). MMS-1B scores **43.8% on FLEURS**.
  - "No Whisper model produces Pashto-script output in more than 0.8% of utterances". MMS-1B, SeamlessM4T and OmniASR each exceed 93% Pashto-script fidelity.
  - Fine-tuned models' published 14% WER degrades to 32.5–59% out of domain.
  - Retroflex and lateral-fricative phonemes carry disproportionate error. Read speech only.
  - [HF paper page](https://huggingface.co/papers/2604.04598) / [arXiv](https://arxiv.org/abs/2604.04598)
- arXiv 2604.08786 "Script collapse in multilingual ASR": script collapse in 21 of 100 model–language pairs, 20 of them involving Whisper [snippet] — [arXiv 2604.08786](https://arxiv.org/pdf/2604.08786)
- Interspeech 2026, "Dissecting ASR Failures in Low-Resource South Asian Languages" (Azeemi, Qazi, Mustafa, Raza; **LUMS**). It covers Urdu, Punjabi, Pashto and Sindhi with five multilingual models and two benchmarks:
  - Script mismatch is most of Whisper's errors on 3 of 4 languages.
  - Best is SeamlessM4T, at **16.3% WER Urdu and 22.1% Punjabi**.
  - Up to 35% cross-language characters appear in the output.
  - WER is inflated up to 3.1 points by spelling and Unicode variation.
  - **Transliteration post-processing recovers up to 25 WER points.**
  - [snippet] — [PDF on aghaaliraza.com](https://aghaaliraza.com/publications/2026--Interspeech--Dissecting_ASR_Failures_in_Low-Resource_South_Asian_Languages.pdf)
- arXiv 2603.27021 (Interspeech 2026): Whisper Base fine-tuned on Pashto MCV20 reaches 13.4% WER, against 99.0% zero-shot [snippet] — [arXiv 2603.27021](https://arxiv.org/abs/2603.27021)
- Related: arXiv 2604.06507 "Fine-tuning Whisper for Pashto ASR: strategies and scale" (7 Apr 2026). Found via HF paper search; not read — [HF paper](https://huggingface.co/papers/2604.06507)
- Vendor-reported FLEURS figures (ElevenLabs: Pashto Scribe 37.8% WER, Punjabi 11.6%) and Soniox's Punjabi claims are self-reported, not independent [snippet] — [ElevenLabs Pashto](https://elevenlabs.io/speech-to-text/pashto); [Soniox vs OpenAI](https://soniox.com/compare-stt/soniox-vs-openai/punjabi)
- Gemini 3.5 Transcribe is reported by Artificial Analysis at 4.0% streaming and 2.6% non-streaming WER, but that is an aggregate, mostly English benchmark with no Pashto/Punjabi breakdown [snippet] — [eesel.ai](https://eesel.ai/blog/gemini-3-5-transcribe)

### Inferences
- Any vendor evaluation must report a **script-fidelity rate** (share of output in Pashto Arabic script or Shahmukhi) alongside WER/CER. HumSukhan should do the same.
- Contacting the LUMS group (Agha Ali Raza, Ihsan Ayyub Qazi) is a natural route to an evaluation or data partnership for Punjabi and Pashto in Pakistan.

### Gaps
- No independent benchmark of *commercial* APIs (Deepgram nova-3, Google, Azure, ElevenLabs, Soniox) on Pashto or Pakistani Punjabi was found.
- The specific models and datasets in the LUMS paper were not confirmed (PDF unreachable).

---

## 3. Existing paid and licensable speech corpora

### Takeaway
Licensable Pashto speech exists, mostly telephone and broadcast and mostly Afghan: LDC BABEL (about 214–244 h), Appen (about 55 h + 39 h), and ELRA TRAD broadcast news. Pakistani Punjabi is almost absent commercially. Appen's 20 h "Panjabi (Pakistan)" telephony set is the only off-the-shelf item found. Prices are not published, so everything is by quote.

### Cited Findings
- **LDC2016S09, IARPA Babel Pashto Language Pack (IARPA-babel104b-v0.4bY):** "approximately 244 hours of Pashto conversational and scripted telephone speech collected in 2011 and 2012" with transcripts. ISLRN says about 214 h, so the sources conflict. For-profit, non-member and not-for-profit licence types exist. Price not shown; non-members "may license this data for a fee" [snippet] — [LDC catalog](https://catalog.ldc.upenn.edu/LDC2016S09); [ISLRN](https://www.islrn.org/resources/594-996-615-028-9/); [LDC newsletter](https://www.ldc.upenn.edu/node/12840)
- **Appen PAS_ASR001:** Pashto (Afghanistan) conversational telephony, 55.5 h, 2005, 8 kHz, with a pronunciation lexicon [snippet] — [Appen catalogue](https://www.appen.com/data-catalog/audio-catalogue/pas-asr001)
- **Appen PAS_ASR002:** Pashto, 39 h, 2014 [snippet] — [Appen catalogue](https://www.appen.com/data-catalog/audio-catalogue/pas-asr002)
- **Appen PAP_ASR001, Panjabi (Pakistan) conversational telephony:** 20 h, language "pan", country PAK, fully transcribed and time-stamped, 2017, mobile and landline, 205 contributors, 8 kHz [snippet] — [Appen OTS datasets](https://datasets.appen.com/country-hungary-or-pakistan)
- **ELRA-S0381, TRAD Pashto Broadcast News Speech Corpus:** produced by ELDA under the French DGA "PEA TRAD" project. LREC 2012 describes a "100 hours speech database recorded and manually transcribed". Licence and price not found [snippet] — [ISLRN](https://islrn.org/resources/802-643-297-429-4/); [LREC 2012 L12-1490](https://aclanthology.org/L12-1490/)
- **Andovar** (custom collection vendor) advertises Punjabi voice-data collection across dialects and "both Gurmukhi and Shahmukhi speakers", scripted and spontaneous [snippet] — [Andovar](https://andovar.com/languages/punjabi-data-services-for-ai/)
- **LDC-IL Punjabi Raw Speech Corpus** is Indian (Gurmukhi) [snippet] — [LDC-IL](https://data.ldcil.org/punjabi-raw-speech-corpus)
- **Hugging Face Hub search (run directly, 26 Oct 2026):**
  - "shahmukhi" returned 0 datasets.
  - "pashto speech" returned `shunyalabs/pashto-speech-dataset` (updated Aug 2025).
  - "punjabi asr" returned only Indian/Gurmukhi-style sets (e.g., `kdcyberdude/Punjabi_ASR_datasets`, `aaparajit02/punjabi-asr`).
  - [HF Hub search](https://huggingface.co/datasets?search=shahmukhi)

### Inferences
- For a *Pakistani Pashto* evaluation set, these resources are mostly Afghan and telephone 8 kHz, a domain mismatch for in-person mobile-mic captioning. They are still useful for training or augmentation if commercial licences are affordable.
- Nexdata/Datatang, Shaip, Defined.ai, Magic Data, FutureBeeAI and Macgence probably sell or collect to order. No Pashto or Shahmukhi catalogue item was confirmed for them.

### Gaps
- Prices for LDC2016S09 (non-member for-profit), Appen sets and ELRA-S0381.
- Nexdata, Shaip, Defined.ai, Magic Data, FutureBeeAI and Macgence: no confirmed Pashto or Shahmukhi off-the-shelf listings found.
- The size and licence of the KICS Punjabi (Shahmukhi) TTS corpus (see §4).

---

## 4. Crowdsourced and community data collection, partners, costs and tooling

### Takeaway
Mozilla Common Voice is the strongest commercial-friendly (CC0) route. Pashto has grown to thousands of hours (CV 25.0, Mar 2026). There is **no Common Voice pnb (Shahmukhi) speech locale**; Punjabi is pa-IN only. HumSukhan could sponsor a pnb locale, which would use the standard Pontoon localisation and CC0 sentence workflow. Pakistani research partners include KICS/CLE (UET Lahore) for Shahmukhi phonetics and TTS corpora, and LUMS for ASR evaluation. Project Vaani does not cover Pakistan.

### Cited Findings
- **Common Voice Pashto:** the Scripted Speech 25.0 datasheet (2026-03-09) lists 4,850,876 clips, **5,313.64 h total, 3,041.86 h validated**, 8,239 speakers [snippet] — [Mozilla Data Collective CV 25.0 Pashto](https://datacollective.mozillafoundation.org/datasets/cmndf6mgs001lnz07bf9t3skp)
  - CV 24.0 (Dec 2025): 2,768.7 h total and 975.89 h validated — [arXiv 2602.14062](https://arxiv.org/html/2602.14062v1)
  - MCV23: 82.33 validated h and 1,483 speakers — [arXiv 2603.27021](https://arxiv.org/abs/2603.27021)
  - Growth was about 108-fold between CV17 and CV18, tied to a **VOA Pashto broadcast campaign** — [arXiv 2603.27021](https://arxiv.org/abs/2603.27021)
  - Clips are read prompts, not conversational speech [snippet]
- **Common Voice Punjabi:** CV 25.0 Punjabi is locale **pa-IN**, CC0-1.0, read speech. No pnb/Shahmukhi speech dataset was found. Mozilla Data Collective does host **pnb text** corpora (Mediamen Punjabi Literature Corpus and an English–Punjabi (Shahmukhi) parallel corpus, both CC-BY-NC-4.0, and the Chishti Sons corpus, non-commercial) [snippet] — [MDC Mediamen org](https://datacollective.mozillafoundation.org/organization/cmhq65prc00mqnz07ox7oejap); [MDC Chishti Sons](https://datacollective.mozillafoundation.org/datasets/cmi39dqwq08jnmn0739vleijb)
- **Common Voice licence:** recent Scripted Speech datasets on Mozilla Data Collective show CC0-1.0. No 2026 licence change was found [snippet] — [MDC listings](https://dev.datacollective.mozillafoundation.org/datasets?page=31); [DPG listing](https://www.digitalpublicgoods.net/r/mozilla-common-voice-dataset)
- **Adding a Common Voice locale:**
  - Request the language on GitHub, localise the interface in Pontoon, and collect CC0 or self-written sentences via Sentence Collector.
  - The localisation threshold is reported as 75% (GitHub docs), 60% (older blog) or 90%+ (Discourse). The sources conflict.
  - Sentence targets by resource band: A 750, B 2,000, C 5,000. Corpora over 100K sentences have a separate bulk-import process.
  - [snippet] — [CV LANGUAGE.md](https://redirect.github.com/common-voice/common-voice/blob/main/docs/LANGUAGE.md); [Mozilla blog](https://www.mozillafoundation.org/en/blog/common-voice-localisation-overhaul); [Discourse](https://discourse.mozilla.org/t/new-language-workflow-5k-sentences-requirement/87616)
- **Common Voice in-country programmes and grants:** past Kiswahili grants of up to USD 50,000 for each of eight projects (Gates Foundation, FCDO, GIZ, 2021/22). No 2026 Common Voice grant call was found [snippet] — [Mozilla Common Voice in-country programmes](https://www.mozillafoundation.org/en/common-voice/in-country-programmes/)
- **Project Vaani** (IISc, ARTPARK, Google) covers India only. Phase 2 open release: about 31,270 h of audio and about 2,067 h transcribed, 109 languages, 165 districts. **No Pakistan coverage** [snippet] — [Vaani](https://vaani.iisc.ac.in); [arXiv 2603.28714](https://arxiv.org/html/2603.28714v2)
- **KICS / CLE, UET Lahore:** Interspeech 2025 (Naseem, Hussain, Rauf et al.) built a Punjabi **Shahmukhi** speech corpus, phonetic lexicon and text-analysis module for TTS. The Shahmukhi phonetic inventory is on Zenodo (record 15532968). ITU Lahore (Faisal Kamiran) is a co-author per the erratum [snippet] — [ISCA archive](https://www.isca-archive.org/interspeech_2025/naseem25_interspeech.html); [CLE](https://cle.org.pk/research/reports.htm)
- **LUMS:** the ASR failure analysis for Urdu, Punjabi, Pashto and Sindhi (§2) [snippet] — [Raza et al. PDF](https://aghaaliraza.com/publications/2026--Interspeech--Dissecting_ASR_Failures_in_Low-Resource_South_Asian_Languages.pdf)
- **UET Peshawar:** an earlier Pashto isolated-words ASR corpus (2012) [snippet] — [UET Peshawar PDF](https://uetpeshawar.edu.pk/TRP-G/Dr.Nasir-Ahmad-TRP/Conferences/2012/The%20Development%20of%20Isolated%20Words%20Corpus%20of%20Pashto%20for%20the%20Automatic%20Speech%20Recognition%20Research.pdf)
- **Deaf organisations:**
  - ConnectHear works with Ufone 4G (Dec 2024) and HANDS on AI disaster alerts for Deaf users, with GSMA Innovation Fund backing, starting with 1,000 beneficiaries (Mar 2025) [snippet] — [Ufone](https://www.ufone.com/ufone-4g-connecthear-partner-to-deliver-ai-powered-assistive-technologies-for-disaster-response/); [ProPakistani](https://propakistani.pk/2025/03/20/connecthear-launches-ai-powered-disaster-preparedness-initiative-for-pakistans-deaf-community-at-access-ability-tech-event/amp/); [GSMA](https://www.gsma.com/solutions-and-impact/connectivity-for-good/mobile-for-development/digital-grantees-portfolio/connecthear/)
  - DeafTawk signed an MoU with PTA (3 Jan 2025) for sign-language interpretation and AI text/speech-to-sign tools [snippet] — [PTA](https://pta.gov.pk/category/pta-signs-mou-with-deaftawk-to-advance-accessibility-for-the-special--need-hearing-impairments-867832596-2025-01-03)
- **Radio Pakistan (PBC) archives:** the Peshawar station digitised about 10,000 h (2018), including 400 Pashto and 400 Urdu audio dramas, and intends to put them "online for research purposes". Digitisation of the national archive was "in progress". **No licensing terms were found** [snippet] — [Arab News](https://www.arabnews.com/node/1370926); [Pakistan Observer](https://pakobserver.net/radio-pakistan-achieves-significant-milestones-in-digital-migration-solangi/)
- **Transcription labour cost (proxies):**
  - Appen lists Kannada transcription at **$24.00 per audio hour**, paid per audio hour processed.
  - A blog estimates about $3–8 per audio hour of worker earnings on Appen-type platforms (anecdotal).
  - Karya says its workers earn "at least 20 times the Indian minimum wage", with no per-hour figure.
  - [snippet] — [Appen Kannada listing](https://jobs.lever.co/appen/9435884d-7a7e-4d75-8ed6-09a04adf22bb); [lilachbullock blog](https://www.lilachbullock.com/hindi-transcription-work-talk-platforms/)

### Inferences
- A pnb Common Voice locale would let HumSukhan pool community Shahmukhi read speech under CC0, which allows commercial use. Pashto already has enough Common Voice volume for fine-tuning, though it is mostly read speech and Afghan-skewed. What is missing is *conversational, Pakistani-dialect, code-switched* evaluation data, which probably needs paid collection (for example Andovar or local agencies, or university partners such as KICS, LUMS and UET Peshawar).
- The VOA Pashto campaign suggests that **media partnerships** (Radio Pakistan Peshawar, Mashaal Radio, FM stations) work well for recruiting contributors.
- Deaf-led organisations (ConnectHear, DeafTawk) are better suited as user-testing and co-design partners than as speech-data sources.

### Gaps
- Typical cost per transcribed hour of Pakistani Pashto or Punjabi, from vendors or local agencies.
- Karya's actual rates, and whether Karya operates in Pakistan.
- PBC/PTV copyright and licensing policy for archive reuse in ML.
- Whether NUST, the University of Peshawar or CSaLT (LUMS) hold Pashto or Punjabi speech corpora.
- Tooling (Label Studio, Common Voice self-hosting) was not researched in this pass.

---

## 5. Legal and ethical considerations in Pakistan; licence choices

### Takeaway
As of late 2026, Pakistan has **no enacted standalone data-protection law** that I could verify. The Personal Data Protection Bill has repeatedly stalled, and one unverified 2026 source claims a 2026 Act. PECA 2016, as amended in 2025, is the operative cyber law. Recording without consent is reportedly criminal. Use explicit, recorded, informed consent; extra safeguards for minors (best excluded); and CC0 or CC-BY for any data released publicly.

### Cited Findings
- DLA Piper: "Pakistan currently has not enacted a specific data protection legislation". PECA 2016 serves a similar purpose with penal sanctions, and "an amendment to this law was passed in 2025" [snippet] — [DLA Piper Data Protection – Pakistan](https://www.dlapiperdataprotection.com/?c=PK)
- PDP Bill history:
  - The 2023 draft was cabinet-approved in July 2023 without public consultation — [Privacy International](https://privacyinternational.org/news-analysis/5090/privacy-international-raises-concerns-regarding-pakistans-personal-data)
  - Feb 2025: cabinet-approved and "pending approval of the National Assembly and Senate" — [Global Legal Post](https://www.globallegalpost.com/lawoverborders/data-protection-law-guide-1072382791/pakistan-1623790143)
  - An unverified 2026 source claims the 2023 Senate bill was withdrawn and that a 14 May 2026 National Assembly debate referred to a "Personal Data Protection Act 2026", with no assent or Gazette evidence — [offlist.me](https://www.offlist.me/what-is-pakistan-data-protection)
  - [snippet]
- PECA (Amendment) 2025 created the Social Media Protection and Regulatory Authority and the National Cyber Crime Investigation Agency, and added up to 3 years' imprisonment for "false information". It has been criticised by Amnesty (Jan 2025), and a policy paper (Apr 2026) urges reform [snippet] — [Amnesty](https://www.amnesty.org/en/latest/news/2025/01/pakistan-authorities-pass-bill-with-sweeping-controls-on-social-media/); [Friday Times, 24 Apr 2026](https://www.thefridaytimes.com/24-Apr-2026/peca-reform-urgently-needed-protect-digital-rights-pakistan-policy-paper-warns); [LUMS SAHSOL analysis](https://sahsol.lums.edu.pk/sites/default/files/2025-11/The%20PECA%20Amendment%202025%20A%20Critical%20Analysis.pdf)
- Recording consent: a recording-law guide claims recording private calls or conversations without every participant's consent is a criminal offence (2–5 years) and cites a March 2026 Supreme Court ruling. This is **unverified**; the guide itself points to pakistancode.gov.pk [snippet] — [recordinglaw.com](https://recordinglaw.com/pakistan-recording-laws)
- Common Voice audio is CC0, and its sentences must be CC0 or self-written. This keeps downstream commercial use open [snippet] — [CV LANGUAGE.md](https://redirect.github.com/common-voice/common-voice/blob/main/docs/LANGUAGE.md)
- Many existing Shahmukhi *text* corpora are CC-BY-NC, which is unusable for a commercial language model or sentence prompts without permission [snippet] — [MDC Mediamen org](https://datacollective.mozillafoundation.org/organization/cmhq65prc00mqnz07ox7oejap)

### Inferences
- Design consent to the strictest likely standard: a GDPR-like, purpose-specific opt-in, which is the direction of the draft PDP Bill. Provide consent forms in Urdu, Pashto and Shahmukhi, with an audio or read-aloud version for low-literacy contributors.
- For real-time captioning in the app, third parties' voices are captured. A "data donation" opt-in (as distinct from simply using the app) is needed before any user audio is kept for training. Vendor-side training should be disabled where possible (for example Deepgram `mip_opt_out`, ElevenLabs zero retention).
- Licence choices: CC0 (Common Voice) or CC-BY-4.0 allow commercial use. Avoid NC or ND licences for training data and prompt text.

### Gaps
- The verified current status of the PDP Bill/Act 2026 (Senate and National Assembly records, Gazette) and any cross-border data-transfer or localisation rules (relevant because Supabase and vendor regions are outside Pakistan).
- Pakistani rules on children's data and age of consent for data processing.
- Verification of the claimed March 2026 Supreme Court recording ruling.

---

## 6. Funding and grant programmes

### Takeaway
I found no open 2026 call that specifically targets Pashto or Punjabi speech data. Possible sources are Lacuna Fund (past NLP rounds of up to $100K–$250K, with no 2026 call confirmed), Mozilla Common Voice in-country programmes (past grants of up to $50K per project, Gates/FCDO/GIZ funded), the GSMA Innovation Fund (which already funded ConnectHear in Pakistan), and Pakistan's planned Ignite-run AI funds (not yet disbursing).

### Cited Findings
- **Lacuna Fund:** a third-party listing (possibly outdated) gives up to $100,000 for smaller and $100,000–$250,000 for larger dataset projects. No 2026 South Asia speech call was found [snippet] — [GrantedAI listing](https://grantedai.com/grants/natural-language-processing-nlp-program-lacuna-fund-7f4bc49e)
- **Mozilla Common Voice:** Kiswahili grants of up to $50,000 for each of 8 projects (Gates Foundation with FCDO and GIZ) [snippet] — [Mozilla in-country programmes](https://www.mozillafoundation.org/en/common-voice/in-country-programmes/)
- **GSMA Innovation Fund for Humanitarian Challenges** funded ConnectHear's Deaf disaster-alert work in Pakistan (2024–25) [snippet] — [Ufone/ConnectHear](https://www.ufone.com/ufone-4g-connecthear-partner-to-deliver-ai-powered-assistive-technologies-for-disaster-response/)
- **Pakistan:**
  - The proposed **Pakistan Emerging Technology and AI Fund** is Rs 28.8 bn over 2026–2031, with Rs 3 bn proposed for FY2026-27 under IGNITE, pending budget approval and with zero spending so far — [letsdatascience](https://letsdatascience.com/news/pakistan-creates-emerging-technology-and-ai-fund-11eb5e42)
  - The **National AI Fund (NAIF)** would get at least 30% of Ignite's R&D budget — [ProPakistani](https://propakistani.pk/2024/04/05/it-ministry-to-establish-national-ai-fund/)
  - Ignite also ran the **AI Wrapper Competition 2025** (Rs 8.75 m prize pool) and the **Pakistan Startup Fund**, tied to Indus AI Week, 9–15 Feb 2026
  - [snippet] — [Ignite Business Plan 2024–28](https://ignite.org.pk/wp-content/uploads/2018/06/Ignite-Business-Plan-2024-28-Final-Version.pdf); [startup.pk](https://startup.pk/?p=29793)

### Inferences
- HumSukhan's accessibility mission fits GSMA's Assistive Tech and Innovation Fund lines, and possibly Ignite/NAIF once those disburse. Pairing with a university (LUMS, KICS) would strengthen Lacuna-style or academic grant bids.

### Gaps
- Current, dated calls from Lacuna Fund, Google.org, the Gates Foundation, Meta language-technology partner programmes and the GSMA Assistive Tech Innovation Fund for 2026–27.
- Ignite or NAIF eligibility rules and deadlines.
