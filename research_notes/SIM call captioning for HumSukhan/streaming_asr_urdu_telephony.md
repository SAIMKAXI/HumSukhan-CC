# Streaming ASR for Urdu / Pakistani English / Urdu-English code-switching on telephone audio (cloud + on-device), as of Oct 2026

Research date: 2026-10-25. Method note: WebFetch and curl could not reach (DNS failure) deepgram.com, developers.deepgram.com, soniox.com, docs.cloud.google.com, learn.microsoft.com, docs.aws.amazon.com, elevenlabs.io, arxiv.org or huggingface.co web pages from this environment. Vendor facts below therefore come from **web-search result snippets** of the named vendor pages (the cited URL is the page the snippet came from), plus third-party trackers. Model cards and paper text came through the **Hugging Face MCP connector** (hf:// filesystem), which worked. Treat every vendor price or claim marked "(snippet)" as worth re-checking on the live page before it goes into a budget.

## Q1. Cloud streaming engines: Urdu, code-switching, telephony, price, privacy

### Takeaway
As of Oct 2026, four cloud engines are confirmed to stream Urdu: Deepgram Nova-3 (`ur`, monolingual), Soniox real-time (v4, now aliased to v5), AssemblyAI Universal-3.6 Pro Streaming, and Speechmatics. A fifth, Sarvam Saaras v3, streams `ur-IN` but takes 16 kHz only. Soniox and AssemblyAI U-3.6 Pro are the only ones with documented *native* Urdu-English code-switching in one stream. Deepgram's `language=multi` does **not** include Urdu, though it does include Hindi. For Google Chirp 2/3, Azure ur-PK, AWS Transcribe and ElevenLabs Scribe v2 Realtime, I could not confirm Urdu streaming in sources reachable from here.

### Cited Findings

**Deepgram (the incumbent HumSukhan engine)**
- Nova-3 added monolingual models for Hebrew, Farsi and Urdu, with Urdu under language code `ur` (changelog dated 2026-02-03; one third-party write-up says 2026-02-12, and the changelog date is the better reference). Deepgram says the models work for both real-time streaming and batch through the same Nova-3 API. Sources: [Deepgram changelog 2026-02-03](https://developers.deepgram.com/changelog/2026/2/3) (snippet), [Deepgram blog: Hebrew, Persian, Urdu on Nova-3](https://deepgram.com/learn/speech-to-text-for-hebrew-persian-urdu-on-nova-3) (snippet), [itnerd.blog 2026-02-12](https://itnerd.blog/2026/02/12/deepgram-expands-language-coverage-with-hebrew-persian-and-urdu/)
- On 2026-08-17 Deepgram shipped an improved Nova-3 Urdu model for both batch and streaming. Urdu was also among the languages with improved models in an Oct-2026 self-hosted release, but it was *not* in the Jan-2026 self-hosted release. I found no WER figure for the Urdu improvement. Sources: [Deepgram changelog 2026-08-17](https://developers.deepgram.com/changelog/2026/8/17) (snippet), [Deepgram changelog 2026-01-29](https://developers.deepgram.com/changelog/2026/1/29) (snippet)
- `model=nova-3&language=multi` (code-switching) covers 10 languages: English, Spanish, French, German, Hindi, Russian, Portuguese, Japanese, Italian and Dutch. **Urdu is not included.** Sources: [Deepgram changelog 2025-03-31](https://developers.deepgram.com/changelog/2025/3/31) (snippet), [Introducing Nova-3](https://deepgram.com/learn/introducing-nova-3-speech-to-text-api) (snippet)
- A user report says `multi` mislabelled Hindi as Spanish in Hindi-English conversations. A Deepgram community reply recommends the Hindi *monolingual* model for Hindi-English. — [GitHub deepgram discussion #1208](https://github.com/orgs/deepgram/discussions/1208) (snippet; the thread's dates look inconsistent)
- LiveKit's docs say `multi` covers fewer languages than the monolingual models. — [LiveKit Deepgram STT docs](https://docs.livekit.io/agents/models/stt/inference/deepgram/) (snippet)
- Telephony audio formats: Deepgram's sample-rate doc says `sample_rate` is required with `encoding` for raw audio and gives an 8000 Hz linear16 example. Telnyx's compatibility table lists mu-law as supported for Nova and Flux, and says Flux drops mp3, flac, webm_opus, amr_nb, amr_wb, g729 and speex compared with Nova. That implies Nova accepts those formats, including AMR-NB/WB and Opus. Sources: [Deepgram sample-rate doc](https://developers.deepgram.com/docs/sample-rate) (snippet), [Telnyx audio formats](https://developers.telnyx.com/docs/voice/stt/websocket-streaming/parameters/audio-formats) (snippet)
- I found no Deepgram-published WER for Nova-3 on 8 kHz mu-law phone audio, for any language. The launch claim of 6.84% median streaming WER is general, not telephony-specific. — [Introducing Nova-3](https://deepgram.com/learn/introducing-nova-3-speech-to-text-api) (snippet)
- Price, from third-party trackers in 2026 (Deepgram's own pricing page was not reachable). Pay-as-you-go Nova-3 monolingual streaming is about **$0.0077/min** list. A promotional rate of about $0.0048/min has no published end date. Multilingual streaming is about $0.0092/min list ($0.0058 promo). Pre-recorded is about $0.0043/min. Growth plan streaming is about $0.0042/min, from roughly $4k/yr. New accounts get **$200 free credit** with no expiry. Sources: [diyai.io Deepgram pricing 2026](https://diyai.io/ai-tools/speech-to-text/deepgram-pricing-2026/), [convertaudiototext Nova-3 pricing](https://convertaudiototext.com/blog/deepgram-nova-3-explained), [brasstranscripts](https://brasstranscripts.com/blog/deepgram-pricing-per-minute-2025-real-time-vs-batch)
- Privacy: under Deepgram's Model Improvement Partnership Program (MIP), customer audio may be used for training. Adding `mip_opt_out=true` to a request excludes it, and opted-out data is "retained only long enough to complete the request". Community posts say opting out raises the rate because you lose the participant discount. Sources: [Deepgram MIP doc](https://developers.deepgram.com/docs/the-deepgram-model-improvement-partnership-program) (snippet), [convertaudiototext opt-out guide](https://convertaudiototext.com/blog/opt-out-of-ai-training-with-your-audio), [Deepgram community](https://community.deepgram.com/answers/en/opt-out-model-improvement-dotnet-sdk-1308609946127962120)

**Soniox**
- `stt-rt-v4` was released 2026-02-05 as the successor to `stt-rt-v3`, built for low-latency voice use and covering 60+ languages. The docs now list `stt-rt-v4` as an alias for `stt-rt-v5`. The changelog said v4 would be removed on 2026-06-30, with requests routed to v5 and no API change needed. Sources: [Soniox v4 real-time blog](https://soniox.com/blog/2026-02-05-soniox-v4-real-time) (snippet), [Soniox models doc](https://soniox.com/docs/stt/models) (snippet)
- The Urdu page claims the model follows mid-sentence Urdu↔English switches "without configuration", with optional language hints to bias recognition. Real-time costs **$0.12/hour** and async $0.10/hour, at the same rate for every language. — [Soniox Urdu STT page](https://soniox.com/speech-to-text/urdu) (snippet, vendor claim)
- Endpoint detection is configurable (example `max_endpoint_delay_ms: 500`). The only latency figure I found, "sub-200 ms", comes from a third-party blog. Sources: [Soniox real-time docs](https://soniox.com/docs/stt/rt/real-time-transcription) (snippet), [callsphere.ai blog](https://callsphere.ai/blog/vw9h-build-voice-agent-soniox-v4-real-time-stt-2026)
- Soniox's own comparison claims **6.3% Urdu WER for Soniox vs 19.3% for Azure**. This is competitor marketing, with an undisclosed test set. — [Soniox vs Azure Urdu](https://soniox.com/compare/soniox-vs-azure/urdu) (snippet)
- I found nothing on Soniox data retention or 8 kHz telephony input from this environment (gap).

**AssemblyAI**
- Universal-Streaming Multilingual covers only EN, ES, DE, FR, PT and IT, so no Urdu or Hindi. Universal-3.5 Pro Streaming has 18 languages, including Hindi but not Urdu. **Universal-3.6 Pro Streaming adds Urdu** (plus Persian, Marathi and others), for 32 languages with native code-switching on by default. Sources: [AssemblyAI streaming multilingual docs](https://www.assemblyai.com/docs/streaming/universal-streaming/multilingual-transcription) (snippet), [AssemblyAI models](https://www.assemblyai.com/docs/getting-started/models) (snippet), [Vapi AssemblyAI docs](https://docs.vapi.ai/providers/transcriber/assembly-ai) (snippet)
- Price: Universal-3.5 Pro realtime is **$0.45/hr** and async $0.21/hr. Universal-Streaming is $0.15/hr. Streaming diarization adds $0.12/hr and keyterms $0.04/hr. I found no specific price for U-3.6 Pro. Sources: [AssemblyAI pricing.md](https://www.assemblyai.com/pricing.md) (snippet), [pricingsaas 2026W11](https://pricingsaas.com/companies/assemblyai/diffs/2026W11)
- AssemblyAI's Urdu page markets call-centre use and per-channel transcription, but its model table marks Urdu "Coming soon" for some models. A changelog entry says async Urdu requests were mis-routed and are now fixed to route to universal-2. Sources: [AssemblyAI Urdu page](https://www.assemblyai.com/languages/urdu) (snippet), [AssemblyAI changelog](https://www.assemblyai.com/changelog) (snippet)

**Speechmatics**
- Speechmatics advertises Urdu real-time and batch, deployable in cloud, on-prem or on-device. Sources disagree on the 2026 real-time rate: about $0.40/hr (Melia 1), $0.45/hr (Standard) and $0.80/hr (Enhanced) per one tracker, versus $0.24/hr "Pro" on Speechmatics' own page. New accounts get a $100 free credit and 2 concurrent real-time sessions. Sources: [Speechmatics Urdu](https://www.speechmatics.com/speech-to-text/urdu) (snippet), [usagepricing Speechmatics](https://www.usagepricing.com/blueprint/speechmatics), [Capterra](https://www.capterra.com/p/142054/Speechmatics/)

**Google Cloud Speech-to-Text v2 (Chirp 2 / Chirp 3 / telephony)**
- The Chirp 3 page says StreamingRecognize, Recognize and BatchRecognize are supported "in the following languages". The snippet showed hi-IN but **no Urdu**, though the table looked truncated. — [Chirp 3 doc](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3) (snippet)
- Chirp 2 marks StreamingRecognize language support as "Limited*", while sync and batch are "on par with Chirp". Streaming was added Oct 2024, and the model is GA in asia-southeast1, us-central1 and europe-west4. The page says the locations API is the authoritative source for supported languages. Sources: [Chirp 2 doc](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-2) (snippet), [STT release notes](https://docs.cloud.google.com/speech-to-text/docs/release-notes) (snippet)
- `chirp_telephony` launched Jan 2024. It is a USM/Chirp fine-tune for audio "typically recorded at an 8 kHz sampling rate". `telephony` and `telephony_short` also exist. I found no language lists, so Urdu support is unconfirmed. — [STT release notes](https://docs.cloud.google.com/speech-to-text/docs/release-notes) (snippet)
- Price (third-party): V2 standard is about $0.016/min (about $0.96/hr for the first 500k min/month), falling to about $0.004/min at volume. Billing is in 15-second increments. Chirp 3 is GA only in the US and EU multi-regions. Sources: [smallest.ai review](https://smallest.ai/blog/is-google-cloud-speech-to-text-still-the-right-choice), [dasha.ai STT pricing](https://dasha.ai/blog/speech-to-text-pricing), [Deepgram comparison](https://deepgram.com/learn/deepgram-vs-google-vs-azure-speech-to-text)

**Azure AI Speech**
- Continuous language identification works only in the Speech SDKs for C#, C++, Java, JavaScript and Python, and needs a SpeechConfig created from an endpoint. At-start LID also works in Objective-C. Microsoft advises constraining the candidate locales. Sources: [Azure language identification doc](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-identification) (snippet), [Azure LID + diarization config](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/configure-language-identification-diarization) (snippet)
- The snippets show `ur-IN` (Urdu, India) for LLM transcription and translation, and `ur-PK` only for TTS voices (Uzma, Asad). **I could not confirm `ur-PK` for real-time STT or continuous LID** from reachable sources. Sources: [Azure language support](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support) (snippet), [Azure TTS blog](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/eleven-more-languages-are-generally-available-for-azure-neural-text-to-speech/2236871)
- Price: standard real-time is about **$1.00/hr** (about $0.0167/min), billed per second, per third-party trackers citing Azure's page. — [dasha.ai](https://dasha.ai/blog/speech-to-text-pricing), [developersdigest](https://www.developersdigest.tech/models/speech/azure)

**AWS Transcribe**
- Streaming reached 54 languages after an Oct-2024 addition of 30. Urdu is not in that list of additions, and the supported-languages table snippet was cut off before the "U" rows. **Urdu streaming is unconfirmed.** Sources: [AWS What's New Oct 2024](https://aws.amazon.com/about-aws/whats-new/2024/10/amazon-transcribe-streaming-transcription-additional-languages), [Transcribe supported languages (CN mirror)](https://docs.amazonaws.cn/en_us/transcribe/latest/dg/supported-languages.html)

**ElevenLabs Scribe v2 Realtime**
- ElevenLabs claims about 150 ms latency and 90+ languages, the same set as batch. Price is about **$0.39/hr**, or $0.28/hr on annual Business plans. Urdu in *realtime* is not confirmed in the snippets. Sources: [ElevenLabs realtime STT page](https://elevenlabs.io/realtime-speech-to-text) (snippet), [goodvibecode ElevenLabs API pricing Sep 2026](https://www.goodvibecode.com/text-to-speech/elevenlabs-api-pricing-explained), [OpenRouter Scribe v2](https://openrouter.ai/elevenlabs/scribe-v2)

**OpenAI**
- `gpt-4o-transcribe` is supported on `v1/realtime`, but the model page marks `v1/realtime/transcription_sessions` as *not supported*. Its token pricing is audio in $6/1M tokens, text in $2.50/1M and text out $10/1M. The realtime cost guide instead says streaming transcription is billed by audio duration. These conflict. Sources: [OpenAI gpt-4o-transcribe model page](https://developers.openai.com/api/docs/models/gpt-4o-transcribe.md) (snippet), [OpenAI realtime costs guide](https://developers.openai.com/api/docs/guides/realtime-costs) (snippet)
- Batch is $0.006/min. Trackers mention a newer "GPT Transcribe" at $0.0045/min, a streaming "live transcribe" at about $0.017/min, and shutdown dates in Jan–Feb 2027 for whisper-1, gpt-4o-transcribe and gpt-4o-mini-transcribe. All of these are secondary sources. Sources: [costgoat OpenAI transcription pricing Oct 2026](https://costgoat.com/pricing/openai-transcription), [digitalapplied comparison 2026](https://www.digitalapplied.com/blog/openai-gpt-transcribe-stt-model-comparison-2026)
- I found no Urdu-specific WER from OpenAI. Soniox's comparison puts OpenAI Realtime at about $0.38–1.15/hr (competitor figure). — [Soniox vs OpenAI Urdu](https://soniox.com/compare/soniox-vs-openai/urdu) (snippet)

**Regional / Pakistani**
- Sarvam Saaras v3 covers 22 Indian scheduled languages plus English, **including Urdu as `ur-IN`**. It has a WebSocket streaming API with claimed time-to-first-token under 150 ms. **Streaming input is limited to WAV or raw PCM at 16 kHz**, so 8 kHz call audio must be upsampled. Batch costs about ₹30/hr (₹45/hr with diarization), and I found no published streaming price. Sources: [Sarvam Saaras doc](https://docs.sarvam.ai/api-reference-docs/getting-started/models/saaras.md) (snippet), [Sarvam transcribe API](https://docs.sarvam.ai/api-reference-docs/speech-to-text/transcribe.md) (snippet), [AWS Marketplace listing](https://aws.amazon.com/marketplace/pp/prodview-6a2ei6d2iimli)
- I found no Pakistani startup with a production Urdu streaming ASR API. The local work I found is academic or government-funded, such as the KICS project on Urdu ASR software-as-a-service for speech-based banking. — [KICS project 283](https://www.kics.edu.pk/project/index/283), [CLE dialog](https://cle.org.pk/dialog/scope.html)

### Inferences
- For live call captions in one stream that switches between Urdu and English, the strongest documented candidates are **Soniox real-time ($0.12/hr, about $0.002/min)** and **AssemblyAI Universal-3.6 Pro Streaming**. Deepgram's Urdu model is monolingual, which is why HumSukhan's current two-socket en-US + ur arbitration is needed. That design doubles the cost (about $0.0154/min list) and the upload.
- Soniox at about $0.002/min would be roughly 4–8× cheaper than Deepgram's two-socket approach, if its Urdu code-switching claims hold. They should be verified on HumSukhan's own phone-audio test set.
- Google's `chirp_telephony` is the only vendor model explicitly trained for 8 kHz, but Urdu coverage is unknown. Run the Speech v2 `locations` API check before investing in it.

### Gaps
- No vendor publishes Urdu WER on narrowband or telephone audio.
- Whether Azure ur-PK STT exists, AWS Urdu streaming, ElevenLabs realtime Urdu, and Google Chirp 2/3 or chirp_telephony ur-PK streaming all need checking on the live docs, which DNS blocked here.
- Soniox retention terms and 8 kHz/mu-law input support were not found.
- The AssemblyAI U-3.6 Pro price was not found.

## Q2. Published Urdu accuracy (FLEURS, Common Voice, conversational, telephony, code-switching)

### Takeaway
Off-the-shelf open models score roughly 20–30% WER on clean Urdu. Whisper turbo gets 21.9% on FLEURS and 26.5% on Common Voice 15, and fine-tuned Whisper-large about 22–24% on read and conversational sets. Code-switched and noisy or telephone Urdu is far worse. Open models transliterate or translate English words into Urdu script, or hallucinate Arabic or Persian. No vendor has an independently verified Urdu telephony WER.

### Cited Findings
- Whisper **turbo, Urdu: 26.5% WER on Common Voice 15 and 21.9% on FLEURS**, from an OpenAI maintainer's comment in the turbo release thread (Oct 2024). — [openai/whisper discussion #2363](https://github.com/openai/whisper/discussions/2363) (snippet)
- The per-language large-v3 vs large-v2 WER on CV15 and FLEURS is published only as a chart image in the openai/whisper README, so I could not read the Urdu value. — [openai/whisper README](https://github.com/openai/whisper)
- *WER We Stand: Benchmarking Urdu ASR Models* (COLING 2025) evaluated Whisper tiny→large-v3, MMS 300M/1B and SeamlessM4T medium/v2-large on read (ARL) and conversational (CSaLT, about 1.3 h) Urdu. **Seamless-large was best on read speech and Whisper-large best on conversational.** Fine-tuned Whisper-large scored 23.79 WER on ARL and 22.35 on CSaLT, and zero-shot whisper-tiny about 96.57 on CSaLT. The authors stress that text normalisation changes results a lot. Sources: [ACL Anthology 2025.coling-main.397](https://aclanthology.org/2025.coling-main.397/), [arXiv 2409.11252](https://arxiv.org/html/2409.11252v3) (snippets)
- *UrduSpeech* (arXiv 2605.17846, May 2026) is a 156 h corpus: 59.2 h standard Pakistani Urdu, **89.4 h Urdu-English code-switched**, and **7.3 h Pakistani-accented English**, from about 1,000–3,000 speakers. It includes a 9 h human-corrected benchmark. In the pilot, **Gemini 2.5 Pro beat Whisper-large-v3 and OmniASR-LLM-1B**. Whisper "failed on code-switched audio by transliterating or translating English into Urdu script", and OmniASR-LLM-1B "produced hallucinations in Arabic or Persian and exhibited word-looping on code-switched or accented segments". The numeric Table 1 did not come through in the HF text. The paper also notes that FLEURS and Common Voice Urdu have very few unique speakers (fewer than 20 validated). — [HF paper 2605.17846](https://huggingface.co/papers/2605.17846) (full text via HF connector)
- Omnilingual ASR (Meta, Nov 2025) reports average CER on FLEURS-81 of 22.6 for Whisper large-v3, 7.3 for the 7B-CTC model and 5.6 for 7B-LLM-ASR. I found no Urdu-specific number, and a third-party benchmark log also notes "no Urdu CTC number found". Sources: [arXiv 2511.09690](https://arxiv.org/pdf/2511.09690) (snippet), [m2moiz/dekho-suno-jaano issue #235](https://github.com/m2moiz/dekho-suno-jaano/issues/235) (snippet)
- Gemini's 2023 report says Gemini Pro beats USM and Whisper on FLEURS. It also says Gemini was trained on the FLEURS training set, so its FLEURS scores are likely inflated. — [Gemini report arXiv 2312.11805](https://arxiv.org/pdf/2312.11805) (snippet)
- **Telephony Urdu:** *Bridging the Bandwidth Gap: A Mixed-Band Telephonic Urdu ASR Approach with Domain Adaptation for Banking* (CHiPSAL 2025) built a corpus of 445 telephone speakers with a 10 h test set. A TDNN beat GMM-HMM, mixing narrowband and wideband training data cut WER further, and Whisper was evaluated as a pretrained baseline. The snippet gave no numbers. — [ACL Anthology 2025.chipsal-1.17](https://aclanthology.org/2025.chipsal-1.17)
- Commercial 8 kHz Urdu telephone corpora exist: Shaip (about 85.6 h, 484 speakers, dual channel, partly synthetic scripted calls) and Appen (47 h of Urdu India/Pakistan conversational telephone speech, mobile and landline, collected 2014). Sources: [Shaip Urdu dataset](https://www.shaip.com/offerings/speech-data-catalog/urdu-dataset/), [Appen OTS](https://datasets.appen.com/?p=1663)
- Vendor claims: Soniox says 6.3% Urdu WER vs Azure's 19.3% ([Soniox](https://soniox.com/compare/soniox-vs-azure/urdu)). On English real-time, Soniox claims 1.25% vs Deepgram 1.71% vs AssemblyAI 1.74% ([Soniox compare](https://soniox.com/compare-stt)). Both are self-published.
- An open streaming Urdu Zipformer (see Q3) reports per-domain test WER: FLEURS ur-PK 32.87, IndicVoices conversational 23.47, **CSALT noisy 37.71**, and **UrduSpeech code-switched 46.93**, against 75–79 macro WER for off-the-shelf Whisper-tiny. — [mahwizzzz/Urdu-Streaming-Zipformer-20M](https://huggingface.co/mahwizzzz/Urdu-Streaming-Zipformer-20M)

### Inferences
- Code-switched Urdu-English is the hardest condition. Errors roughly double compared with monolingual Urdu (about 47% vs 23–26% for the Zipformer). Scoring is also confounded by script: an English word written in Latin script and the same word written in Urdu script count as different. HumSukhan should normalise, or allow both scripts, when it measures its own WER.
- With no published telephony numbers, the practical step is to build a small in-house eval set (say 1–2 h). It should be real Pakistani calls, recorded with consent, or FLEURS/UrduSpeech clips passed through AMR-NB at 8 kHz. Use it to rank Deepgram ur, Soniox and AssemblyAI U-3.6.

### Gaps
- Exact Urdu FLEURS WER for Whisper large-v3, MMS-1B, SeamlessM4T v2, Chirp and Gemini 2.x/3 could not be extracted: chart images and the arXiv tables were unreachable.
- The CHiPSAL telephony WER values are missing.
- I found no Pakistani-English (en-PK) accent benchmark beyond UrduSpeech's 7.3 h US-EngPk subset.

## Q3. On-device options for low-cost Android (2–4 GB RAM)

### Takeaway
As of Oct 2026, one open **streaming** Urdu model runs in sherpa-onnx: the community *Urdu-Streaming-Zipformer-20M*, which is 42 MiB int8, peaks at 133 MiB RAM, and handles some code-switching, at about 24–31% macro WER. Everything else for Urdu is non-streaming: Whisper (which HumSukhan already ships), Omnilingual CTC 300M/1B in sherpa-onnx, and MMS. Non-streaming models would have to be run in VAD-segmented or chunked mode. Android's built-in on-device recognizer exposes per-language support only at runtime, and I found no source confirming an Urdu offline pack.

### Cited Findings
- **mahwizzzz/Urdu-Streaming-Zipformer-20M** (updated 2026-10-25, CC-BY-4.0 weights, `library_name: sherpa-onnx`) is a causal Zipformer transducer with 20.85M parameters. It uses 320 ms chunks with about 40 ms lookahead and 1.28 s left context. Its tokenizer is a 1,024-piece BPE covering Urdu script, lowercase Latin and digits. It was trained on 56.69 h (IndicVoices, Kathbath, UrduSpeech silver labels, Rasa), including 3,301 code-switched utterances, without Common Voice. INT8 on one Intel i5-8600K thread runs at RTF 0.033 (8.86 ms per 320 ms chunk), peaks at 133 MiB RSS and is 42 MiB on disk. Macro test WER is 30.49 (dev 24.47). Output has no punctuation. The card states that noisy or telephone audio degrades accuracy, and it takes **16 kHz input only**. — [HF model card](https://huggingface.co/mahwizzzz/Urdu-Streaming-Zipformer-20M)
- **Omnilingual ASR in sherpa-onnx:** csukuangfj publishes `sherpa-onnx-omnilingual-asr-1600-languages-{300M,1B}-ctc[-int8]-2025-11-12`. The 300M int8 ONNX file is 365 MB. These are CTC models, which are **non-streaming**. Sources: [HF csukuangfj 300M int8](https://huggingface.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12), [HF csukuangfj 1B int8](https://huggingface.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-1B-ctc-int8-2025-11-12)
- The Meta Omnilingual model card lists omniASR_CTC_300M (325M params, 1.3 GiB FP32, about 2 GiB VRAM, RTF 0.001 on an A100) and CTC_1B (975M, 3.7 GiB, about 3 GiB). LLM variants need 5–17 GiB with RTF about 0.09 on an A100. Licence is Apache-2.0. — [HF facebook/omniASR-CTC-1B](https://huggingface.co/facebook/omniASR-CTC-1B)
- An earlier search found no sherpa-onnx streaming Zipformer for Urdu among the official k2-fsa models. The official tables mark only the tiny zh-14M and en-20M streaming Zipformers as "suitable for Cortex A7". A community Indian-English streaming Zipformer claims 5–10× real-time int8 on Snapdragon 7-series and above, but I found no measured RTF on Cortex-A53. Sources: [react-native-sherpa-onnx docs](https://www.mintlify.com/XDcobra/react-native-sherpa-onnx/models/stt/transducer), [HF Akshatkasera007 STT-streaming-zipformer-indian-en](https://huggingface.co/Akshatkasera007/STT-streaming-zipformer-indian-en)
- **Android `SpeechRecognizer.createOnDeviceSpeechRecognizer` (API 31+):** language support is reported at runtime through `checkRecognitionSupport` and `RecognitionSupport`, as installed, supported-but-needs-download, or pending languages. A missing pack is fetched with `triggerModelDownload(Intent)`. The on-device recognizer returns an empty list of *online* languages. The docs list no languages. — [Android RecognitionSupport.Builder](https://developer.android.com/reference/android/speech/RecognitionSupport.Builder), [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer?hl=en)
- Live Transcribe has worked offline since March 2022 once a language pack is installed. Multiple offline languages require Android 12+ on selected devices and Pixels; Android 8–11 devices get offline **English only**. Urdu was not named in any source. Sources: [Google Accessibility help](https://support.google.com/accessibility/android/answer/9158064?hl=en), [Wikipedia Live Transcribe](https://en.wikipedia.org/wiki/Live_Transcribe)
- Whisper on device: in a lightweight Whisper study, Whisper-Small had the best zero-shot Urdu WER at 33.68%, on a different dataset from COLING. Smaller Whisper models without fine-tuning do badly on Urdu (tiny about 96.6% on CSaLT). Sources: [arXiv 2508.09865](https://arxiv.org/pdf/2508.09865) (snippet), [WER We Stand](https://aclanthology.org/2025.coling-main.397/) (snippet)
- A third-party test on a 116 s code-switched Urdu clip found full Whisper large-v3 took 218 s versus 85 s for turbo, and large-v3 ignored a Roman-Urdu prompt. — [m2moiz/dekho-suno-jaano issue #33](https://github.com/m2moiz/dekho-suno-jaano/issues/33)
- Silero VAD handles 8 kHz and 16 kHz, with 32 ms frames (256 samples at 8 kHz, 512 at 16 kHz). The model is about 1–2 MB and takes about 1 ms per chunk on one CPU thread. — [Pipecat Silero VAD analyzer](https://docs.pipecat.ai/server/utilities/audio/silero-vad-analyzer), [voiceclean VAD API](https://voiceclean.readthedocs.io/en/latest/api/vad/)
- NVIDIA Parakeet/Canary, Moonshine and Vosk: no search result showed Urdu support. Not confirmed; see Gaps.

### Inferences
- **The best on-device streaming candidate is the Urdu-Streaming-Zipformer-20M**, used through HumSukhan's existing sherpa-onnx `OnlineRecognizer`. Its 133 MiB RSS and 42 MiB size fit 2–4 GB phones. Desktop RTF of 0.033 suggests roughly 0.1–0.3 on a Cortex-A53/A55 (an estimate, not a measurement). That should comfortably sustain real time and give first partials at about 320–640 ms.
  - Two caveats: it was not trained on telephone audio, so expect WER well above 30% on 8 kHz AMR, and its CC-BY-4.0 weights need attribution to AI4Bharat and ASLP-lab.
  - Fine-tuning it on narrowband-simulated data (resample to 8 kHz, AMR-NB codec, back to 16 kHz) is the obvious improvement route.
- Running Whisper base or small in VAD-segmented mode can give "final-only" captions, with 1–3 s delay after each utterance ends. Pseudo-streaming (re-decoding a growing 30 s window) costs much more compute and is likely too slow for 2 GB phones in real time. That is an inference from Whisper's encoder-decoder design, not a measured result.
- Omnilingual CTC 300M int8 (365 MB on disk, likely 0.5–1 GB RAM at runtime) is feasible only as an offline or segment-level fallback on 4 GB phones. Urdu accuracy is unknown, and UrduSpeech reports hallucination problems for the LLM-1B variant.

### Gaps
- No measured RTF or RAM on Cortex-A53/A55 for any Urdu model.
- Whether Google's on-device recognizer offers an `ur` or `ur-PK` offline pack (check `checkRecognitionSupport` on a device).
- Vosk Urdu, Parakeet/Canary Urdu, Moonshine Urdu: no evidence found, so presumably unsupported. Unverified.

## Q4. Telephony pipeline engineering: resampling, VAD, endpointing, bitrate, latency, data per hour, Pakistan data cost

### Takeaway
Phone audio arrives at 8 kHz (AMR-NB, CVSD, μ-law) or 16 kHz (AMR-WB, EVS, mSBC). Cloud engines accept 8 kHz linear16 or μ-law directly. The on-device Urdu Zipformer and Sarvam need 16 kHz, so upsampling is needed, and it adds no information. Upload volume ranges from about 7 MB/h (Opus) to 115 MB/h (16 kHz PCM) per stream. On Pakistani monthly bundles that is cheap: under Rs 2 per hour even with two PCM sockets. **On pay-as-you-go rates (Rs 2.75–5 per MB) it is prohibitively expensive.** Compression and a single code-switching stream therefore matter a lot.

### Cited Findings
- Deepgram requires `encoding` + `sample_rate` for raw audio, and 8000 Hz is valid. Twilio media streams are mulaw/8000, and wrong values degrade accuracy. Sources: [Deepgram sample-rate doc](https://developers.deepgram.com/docs/sample-rate) (snippet), [Bolna Deepgram config](https://www.bolna.ai/docs/deepgram-transcriber)
- Deepgram Nova accepts webm_opus, amr_nb, amr_wb, g729 and speex in addition to mu-law. This is inferred from Telnyx's list of formats that Flux drops relative to Nova. — [Telnyx audio formats](https://developers.telnyx.com/docs/voice/stt/websocket-streaming/parameters/audio-formats) (snippet)
- Sarvam streaming takes only 16 kHz WAV or raw PCM. — [Sarvam Saaras doc](https://docs.sarvam.ai/api-reference-docs/getting-started/models/saaras.md) (snippet)
- Endpointing: Soniox's `max_endpoint_delay_ms` (example 500 ms) ([Soniox RT docs](https://soniox.com/docs/stt/rt/real-time-transcription), snippet). Silero VAD uses 32 ms frames at about 1 ms each ([Pipecat](https://docs.pipecat.ai/server/utilities/audio/silero-vad-analyzer)). The streaming Zipformer emits every 320 ms ([HF card](https://huggingface.co/mahwizzzz/Urdu-Streaming-Zipformer-20M)).
- Pakistan mobile data, based on PTA's 30-Sep-2026 tariff list via secondary sites:
  - Monthly bundles: about Rs 7/GB (Telenor Monthly Prime, 300 GB), about Rs 9/GB (Ufone), about Rs 13.5/GB (Zong Monthly Pro Max Basic, Jazz Monthly X, before withholding tax).
  - Weekly bundles: about Rs 60/GB.
  - Pay-as-you-go without a bundle: **Jazz Rs 5/MB, Telenor and Zong Rs 4/MB plus tax, Ufone Rs 2.75/MB plus tax.**
  - Sources: [pakera.pk price per GB](https://pakera.pk/cheapest-monthly-weekly-package-per-gb-pakistan/), [csinfo.pk PTA standard rates 2026](https://www.csinfo.pk/pta-prepaid-standard-rates-2026), [techjuice Jazz data charges](https://www.techjuice.pk/jazz-exposed-as-the-worst-operator-amid-skyrocketing-data-charges/), [pehlepakistan best packages 2026](https://pehlepakistan.pk/mobiles/best-internet-packages-pakistan/)

### Inferences
These are calculations, not cited figures.

**Upload bitrate and data per hour, per stream:**

| Format | Bitrate | Data per hour |
|---|---:|---:|
| 16 kHz 16-bit PCM | 256 kbps | ≈115 MB |
| 8 kHz 16-bit PCM | 128 kbps | ≈58 MB |
| 8 kHz μ-law | 64 kbps | ≈29 MB |
| Opus at 16–24 kbps | 16–24 kbps | ≈7–11 MB |
| AMR-WB 12.65 kbps | 12.65 kbps | ≈5.7 MB |

Add roughly 5–10% for WebSocket/TLS framing. The current two-socket Deepgram design at 16 kHz PCM uses about 230 MB/h.

**User cost per hour on that two-socket design:**
- Monthly bundle at Rs 7–13.5/GB: about Rs 1.6–3.1 per hour.
- Weekly bundle at about Rs 60/GB: about Rs 14 per hour.
- Pay-as-you-go at Rs 4/MB: **about Rs 900+ per hour**.
- One Opus stream at about 10 MB/h on the same PAYG rate: about Rs 40/h.

**Conclusions from those numbers:**
- Default to Opus or μ-law plus a single code-switching stream.
- Warn users who are not on a data bundle.
- Prefer on-device recognition when no bundle is detected.

**8 kHz input and resampling:**
- For 8 kHz sources (AMR-NB, CVSD SCO, PSTN μ-law), send 8 kHz natively to cloud engines that accept it (Deepgram, and probably others) rather than upsampling. This halves bandwidth with no information loss.
- Upsample 8→16 kHz (polyphase or sinc, for example via sherpa-onnx's internal resampler or Android's resampler) only for 16 kHz-only engines: the Zipformer, Sarvam, and Whisper.
- Upsampled narrowband audio has an empty 4–8 kHz band. Wideband-trained models lose accuracy on it, which is why mixed-band training helped in the CHiPSAL paper.

**Latency budget for a first partial under 1 s:**

| Stage | Time |
|---|---:|
| Audio frame | 20–100 ms |
| Uplink on 3G/4G | 50–150 ms |
| Engine partial | 150–300 ms (vendor claims) |
| Downlink and render | 50–100 ms |
| **Total** | **≈0.3–0.65 s** |

On device, the Zipformer chunk is 320 ms plus compute, about 0.4–0.7 s total. Gate the stream with VAD (Silero) to cut both cost and data during silence. Many cloud vendors bill only for audio sent. Keep a keep-alive message going during long silences.

**Battery:** A continuous WebSocket over the cellular radio plus resampling is likely to draw less than running Whisper locally. A 20M-parameter streaming Zipformer at single-thread RTF of about 0.2 would probably use about 20% of one core. Both points are inferences; I found no measurement.

### Gaps
- I found no published measurements of end-to-end caption latency over Pakistani 3G/4G, or of battery drain for streaming ASR on low-end Android.
- I did not confirm which cloud engines accept Opus or AMR input over *streaming* WebSockets beyond the Deepgram/Telnyx table.
- Pakistan per-GB figures come from secondary aggregators of PTA data, not the PTA filing itself.
