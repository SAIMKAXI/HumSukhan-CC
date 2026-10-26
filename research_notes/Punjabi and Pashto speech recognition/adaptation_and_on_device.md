# Adaptation methods, deployable architectures, toolchains and base-model licensing for low-resource ASR (Pashto, Pakistani Punjabi/Shahmukhi) on low-cost Android

Research date: 2026-10-26. Sources used: Hugging Face MCP (model cards, paper full text via `hf://papers/...`), GitHub raw (facebookresearch/omnilingual-asr README + per-language CSV, huggingface/blog mms_adapters.md, k2-fsa/sherpa docs .rst), and WebSearch snippets. arxiv.org, aclanthology.org, huggingface.co web, k2-fsa.github.io and api.semanticscholar.org were blocked (proxy 403 / DNS) in this environment, so some paper numbers below come from search snippets only; this is marked where it applies.

---

## 1. Base model options, licences and streaming capability

### Takeaway
Base models that are licensed for commercial use and cover pnb/pus: Whisper (MIT), XLS-R (Apache-2.0), w2v-BERT 2.0 (MIT) and Meta Omnilingual ASR (Apache-2.0, released Nov 2025, already exported to sherpa-onnx as a 300M int8 CTC model). MMS (CC-BY-NC-4.0) cannot be shipped commercially. NVIDIA Parakeet/Canary (CC-BY-4.0) and Moonshine (MIT for most streaming models) are licensed for commercial use but have no Pashto or Punjabi checkpoints. You would have to train or fine-tune them for these languages. None of the large multilingual models streams natively. True streaming on device means training a streaming Zipformer transducer (icefall) or a cache-aware FastConformer (NeMo). The alternative is pseudo-streaming a CTC model with VAD and chunking.

### Cited Findings
**Licences and coverage (from HF model cards, checked via HF MCP on 2026-10-26)**
- `openai/whisper-large-v3-turbo`: 808.9M params, **MIT**, language tags include `ur`, `pa`, `ps`, `sd`. — [HF model card](https://hf.co/openai/whisper-large-v3-turbo)
- `facebook/wav2vec2-xls-r-300m`: **Apache-2.0**, pretraining tags include `ps`, `pa`, `ur`, `fa`, `sd`, `hi`. — [HF model card](https://hf.co/facebook/wav2vec2-xls-r-300m)
- `facebook/w2v-bert-2.0` (Seamless, arXiv:2312.05187): 580.5M params, **MIT**, language tags include `pa`, `ps`, `ur`, `fa`, `sd`, `hi`. — [HF model card](https://hf.co/facebook/w2v-bert-2.0)
- `facebook/mms-1b-all`: 964.8M params, **CC-BY-NC-4.0**, tags include `pa`, `ps`. `facebook/mms-lid-4017` (970.1M) is also **CC-BY-NC-4.0**. — [mms-1b-all](https://hf.co/facebook/mms-1b-all); [mms-lid-4017](https://hf.co/facebook/mms-lid-4017)
- Omnilingual ASR: "Omnilingual ASR code and models are released under the Apache 2.0" licence. The training corpus `facebook/omnilingual-asr-corpus` is **CC-BY-4.0**. It supports 1,600+ languages, and "new languages [can] be added with just a few paired examples." — [omnilingual-asr README (GitHub raw)](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md); HF card also lists apache-2.0 — [omniASR-LLM-7B card](https://huggingface.co/facebook/omniASR-LLM-7B/blob/main/README.md)
- Omnilingual ASR model family (README table; RTF measured relative to LLM_7B on GPU):
  - CTC_300M: 325.5M params, 1.3 GiB FP32, ~2 GiB VRAM, RTF 0.001
  - CTC_1B: 975M params, 3.7 GiB
  - CTC_3B: 3.08B params, 12 GiB
  - CTC_7B: 6.5B params, 25 GiB
  - LLM_300M: 1.63B params, 6.1 GiB
  - LLM_1B: 2.28B params
  - LLM_3B: 4.38B params
  - LLM_7B: 7.8B params, 30 GiB, ~17 GiB VRAM
  - LLM_7B_ZS (zero-shot): 7.81B params, ~20 GiB VRAM
  - `_v2` checkpoints with improved CER, and `LLM_Unlimited_*_v2` for unlimited audio length (no fine-tuning recipe for the Unlimited variant yet)
  - Fine-tuning recipes exist for CTC and LLM models (`workflows/recipes/wav2vec2/asr`).
  - Source: [omnilingual-asr README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)
- Omnilingual ASR paper: arXiv 2511.09690, "Omnilingual ASR: Open-Source Multilingual Speech Recognition for 1600+ Languages", published 2025-11-12. — [HF Papers](https://huggingface.co/papers/2511.09690)
- NVIDIA Parakeet-TDT-0.6B-v3 (627M, FastConformer-TDT) is **CC-BY-4.0** and covers 25 European languages only (no ur/pa/ps). Canary-1B-v2 (979M) is **CC-BY-4.0** with the same 25 languages. — [parakeet-tdt-0.6b-v3](https://hf.co/nvidia/parakeet-tdt-0.6b-v3); [canary-1b-v2](https://hf.co/nvidia/canary-1b-v2)
- NVIDIA `stt_en_fastconformer_hybrid_large_streaming_multi`: **CC-BY-4.0**, English only, cache-aware streaming (arXiv:2312.17279), Transducer+CTC hybrid. — [HF card](https://hf.co/nvidia/stt_en_fastconformer_hybrid_large_streaming_multi)
  - The NGC catalogue lists cache-aware FastConformer-Hybrid streaming models of ~114M params with 80 ms look-ahead. — [NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/nemo/models/stt_en_fastconformer_hybrid_large_streaming_80ms)
- Kyutai `stt-1b-en_fr` (989M, streaming): **CC-BY-4.0**, English and French only. — [HF card](https://hf.co/kyutai/stt-1b-en_fr)
- Moonshine licensing:
  - `moonshine-ai/moonshine` and `moonshine-streaming-tiny` (44.1M) are **MIT**, English. — [moonshine](https://hf.co/moonshine-ai/moonshine); [moonshine-streaming-tiny](https://hf.co/moonshine-ai/moonshine-streaming-tiny)
  - Moonshine Voice docs say models are MIT by default, but older non-streaming non-English models remain under the non-commercial "Moonshine Community License". Arabic Tiny Streaming is MIT; Korean and Ukrainian are Community-licensed. No Urdu, Punjabi or Pashto is listed. — [Moonshine Voice available models (via search snippet)](https://moonshine-voice.readthedocs.io/en/stable/models/available-models/)
  - The "Flavors of Moonshine" paper (Sep 2025) says its Arabic/Chinese/Japanese/Korean/Ukrainian/Vietnamese models were released under a permissive licence. This conflicts with the later Community License. — [arXiv 2509.02523 (search snippet)](https://web3.arxiv.org/pdf/2509.02523)
- AI4Bharat `indic-conformer-600m-multilingual`: **MIT**, gated, ships ONNX. It targets Indian languages, so Punjabi coverage would be Gurmukhi script. — [HF card](https://hf.co/ai4bharat/indic-conformer-600m-multilingual)
- sherpa-onnx support for Omnilingual ASR:
  - An int8 300M CTC export exists: `csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12` (updated 14 Nov 2025). — [HF repo](https://hf.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12)
  - Third-party code loads it via `sherpa_onnx.OfflineRecognizer.from_omnilingual_asr_ctc(...)`. — [HF Space commit (search snippet)](https://huggingface.co/spaces/RO-Rtechs/Am-Srt-v1/commit/8c27967dde77a40417d4b09c748e66e5ab35cfcc)
  - sherpa-onnx 1.12.18 changelog lists "export omniASR_CTC_1B (#2788)". — [sherpa_onnx_ios changelog (search snippet)](https://pub-web-s1.flutter-io.cn/packages/sherpa_onnx_ios/changelog)
- sherpa-onnx's README lists offline support for Whisper, Moonshine, NeMo Parakeet-TDT, SenseVoice, Dolphin, TeleSpeech CTC and Zipformer CTC/transducer. Streaming (online) support is mainly Zipformer transducer/CTC. — [sherpa-onnx README (GitHub raw)](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/README.md)

### Inferences
- **Streaming-capable architectures**:
  - Native streaming: icefall streaming Zipformer transducer/CTC, NeMo cache-aware FastConformer, Moonshine streaming, Kyutai STT.
  - Non-streaming (need VAD-chunked or "simulated streaming" decoding): Whisper, XLS-R/MMS/Omnilingual CTC, w2v-BERT CTC, Canary, IndicConformer offline.
  - A bidirectional CTC model of ~300M params on short chunks (e.g. 1–2 s with overlap) is the most realistic way to get first partials in under 1 s from an Omnilingual or XLS-R fine-tune. This needs on-device testing.
- **Best commercially safe candidates for Pashto/Punjabi fine-tuning:**
  1. omniASR_CTC_300M (Apache-2.0, already in sherpa-onnx int8, covers pus/pbt/pbu/pst/pnb)
  2. XLS-R 300M (Apache-2.0)
  3. w2v-BERT 2.0 (MIT, 580M; heavier)
  4. Whisper small/base (MIT; batch only)
- MMS's adapter recipe is the most data-efficient below 1 h, but the CC-BY-NC weights rule it out for HumSukhan unless Meta grants a separate licence. Omnilingual ASR looks like Meta's commercially usable successor, released under Apache-2.0.

### Gaps
- I could not fetch the Omnilingual ASR paper tables (arxiv blocked; the HF paper text exceeded output budgets). The fine-tuning-hours vs CER curves and the exact in-context-learning recipe are therefore unverified.
- I could not confirm the IndicConformer streaming variant or the Punjabi script in the gated model card.
- Google USM is not open-weights. This is background knowledge only and was not re-verified this session.
- I did not verify whether w2v-BERT 2.0 CTC fine-tunes export cleanly to sherpa-onnx.

---

## 2. Data requirements: WER/CER vs hours of fine-tuning data; related-language transfer

### Takeaway
The direct evidence on Pashto is a 2026 preprint fine-tuning Whisper on Common Voice, which reaches about 21–27% WER and about 8–9% CER. Whisper zero-shot on Pashto is unusable (WER over 100%, wrong script). In that study, full fine-tuning beat LoRA by more than 30 pp and Urdu→Pashto staged transfer failed. Omnilingual ASR's own training data includes only about 12 h of Shahmukhi Punjabi and about 29 h of Pashto, and its 7B model scores CER 31.2% on pnb_Arab and 12.6% on pus_Arab. Pakistani Punjabi is therefore the weaker language and needs in-domain data most. Below 1 h of data, adapter-style methods (MMS) win; at 1–2 h and above, XLS-R catches up.

### Cited Findings
**Omnilingual ASR per-language results** (7B LLM-ASR, from the repo CSV of training hours and CER):

| Language code | Language / script | Training hours | CER |
|---|---|---|---|
| pnb_Arab | Western Punjabi, Shahmukhi | 11.9 | 31.2 |
| pus_Arab | Pashto | 28.7 | 12.6 |
| pbt_Arab | Southern Pashto | 5.6 | 8.8 |
| pbu_Arab | Northern Pashto | 5.2 | 7.5 |
| pst_Arab | Central Pashto | 5.3 | 3.5 |
| urd_Arab | Urdu | 237.5 | 3.5 |
| pan_Guru | Punjabi, Gurmukhi | 207.5 | 4.3 |
| hno_Arab | Hindko | 12.2 | 17.1 |
| skr_Arab | Saraiki | 1.5 | 17.0 |
| snd_Arab | Sindhi | 12.6 | 6.6 |
| fas_Arab | Persian | 214.7 | 3.4 |
| eng_Latn | English | 63,591.5 | 3.0 |

Source: [per_language_results_table_7B_llm_asr.csv (GitHub raw)](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/per_language_results_table_7B_llm_asr.csv)

- The 7B LLM-ASR achieves CER below 10 for 78% of 1,600+ languages. — [omnilingual-asr README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)
- Omnilingual ASR paper (via search snippets/summaries):
  - In the "low-resource" bucket (<10 h training data per language), only 34–36% of languages meet the CER<10 threshold, with average CER 18.6 and 18.0 for two model variants.
  - The zero-shot model with 10 in-context examples cut average CER on 32 held-out languages from 26.33% to 14.4%.
  - Source: [Emergent Mind summary](https://www.emergentmind.com/papers/2511.09690); [Moonlight review](https://www.themoonlight.io/en/review/omnilingual-asr-open-source-multilingual-speech-recognition-for-1600-languages). These are secondary summaries; the exact numbers need checking against [arXiv 2511.09690](https://arxiv.org/pdf/2511.09690).

**Whisper on Pashto** (Rahman 2026, "Fine-tuning Whisper for Pashto ASR: strategies and scale"; full text read via HF Papers — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1))
- Zero-shot on CV24 Pashto: whisper-base WER 171.4%, small 120.4%, large-v3-turbo 110.2%. No model produces Pashto script in more than 0.8% of utterances.
- Strategy comparison: whisper-base, CV20 (~57.7 h train, offline-augmented, 179 speakers), 3.2 h test.

  | Strategy | Trainable params | WER | CER |
  |---|---|---|---|
  | Vanilla full fine-tuning | 74.4M | 21.22% | 8.52% |
  | Frozen 2/6 encoder layers | — | 35.98% | — |
  | LoRA r=64 on q/v | 2.36M (3.15%) | 54.58% | 17.21% |
  | Urdu→Pashto multistage (from `sharjeel103/whisper-base-urdu`) | — | 65.78% | — |

- Model scale: CV24, 113.4 h train, 866 speakers, 20.7 h test.

  | Model | WER | CER |
  |---|---|---|
  | whisper-base | 27.13% | 8.79% |
  | whisper-small | 24.89% | 8.08% |
  | large-v3-turbo | 23.37% | 7.64% |

  The authors call whisper-small "the practical optimum" at about 100 h.
- Data efficiency: the vanilla whisper-base learning curve is still improving at 10k steps (WER 55.6% at step 500, 33.1% at 2k, 26.6% at 5k, 21.2% at 10k).
- Error analysis: the dominant errors are word-final suffix confusion (masculine ی vs feminine ه) and confusion of the Pashto-specific consonant څ.
- The authors attribute the Urdu-transfer failure to an unverified intermediate checkpoint, phonological mismatch (Urdu lacks Pashto retroflex/pharyngeal sounds) and an LR that was too low. They recommend Persian/Dari as the intermediate language.
- Caveats: this is a single-author preprint, single seed, and LoRA was not tuned. The authors say "The reported result characterises this configuration, not LoRA as a strategy class."

**Other evidence**
- CHiPSAL 2025 (COLING workshop): "Benchmarking Whisper for Low-Resource Speech Recognition: An N-Shot Evaluation on Pashto, Punjabi, and Urdu" (Sehar, Khalid, Adeeba, Hussain — CLE/UET Lahore) fine-tuned whisper-small and reports large WER reductions from few-shot fine-tuning. — [ACL Anthology 2025.chipsal-1.20](https://aclanthology.org/2025.chipsal-1.20)
  - A search snippet reported WER vs hours of broadcast data:

    | Language | WER at 1 h | WER at 10–15 h |
    |---|---|---|
    | Punjabi | 45.18 | 38.01 (15 h) |
    | Urdu | 33.14 | 23.43 (10 h) |
    | Pashto | 53.08 | 34.10 (15 h) |

    Source: [search result for aclanthology PDF](https://aclanthology.org/2025.chipsal-1.20.pdf). I could not open the PDF to confirm the table.
- Other Whisper LoRA results:
  - Swiss German: best LoRA 26.28% vs full fine-tuning 25.60% WER, so the gap is small at larger scale. — [arXiv 2606.07608 (search snippet)](https://arxiv.org/pdf/2606.07608)
  - Nepali financial domain (303 utterances): LoRA cut WER by 67%. — [SpeakPay, HF Papers 2609.01737](https://huggingface.co/papers/2609.01737)
- MMS vs XLS-R in fieldwork languages (10/30/60/120 min subsets): "MMS is best suited when extremely small amounts of training data are available, whereas XLS-R shows parity performance once training data exceed one hour" / "XLS-R performs similarly well with 2 hours". — [arXiv 2506.17459 / ACL FieldMatters 2025 (search snippets)](https://arxiv.org/pdf/2506.17459)
- MMS adapters: about 2.5M weights per language (attention-block adapters plus a language-specific output layer). The HF blog claims "astonishingly low word error rates after just 10-20 minutes of fine-tuning." It recommends replacing the tokenizer and vocabulary with one built from the target data. — [HF blog mms_adapters.md (GitHub raw)](https://raw.githubusercontent.com/huggingface/blog/main/mms_adapters.md)
- XLS-R scaling, Frisian (master's thesis, not the XLS-R paper): fine-tuning XLS-R with 10 min, 1 h and 10 h gave WER 62.25%, 25.4% and 8.83%. — [RUG thesis (search snippet)](https://campus-fryslan.studenttheses.ub.rug.nl/360/1/MA%20S3944867%20DA%20Balan.pdf)
- The XLS-R paper's Common Voice few-shot setup uses 1 h per language and reports phoneme error rate, not WER. — [arXiv 2111.09296 (search snippet)](https://arxiv.org/pdf/2111.09296)
- Liu et al. (as cited by Rahman 2026): fine-tuning Whisper on seven low-resource FLEURS languages took zero-shot WER of 48–90%+ down to 12–45%. Freezing the bottom encoder layers helps only for models with 12 or more encoder layers. — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)

### Inferences
- Rough expectation for a commercially licensed, Apache/MIT base model:
  - 10–20 h of clean read speech should give CER of roughly 10–20% (WER 30–45%) on matched data.
  - 50–100 h should give CER of roughly 8–10% (WER about 20–27% for Pashto).
  - Conversational and far-field captioning audio will be worse than Common Voice read speech.
- For Shahmukhi Punjabi, Omnilingual's 31% CER at about 12 h suggests the base model's coverage is weak. Collecting in-domain pnb data, or transferring from Gurmukhi Punjabi via transliteration (pan_Guru has 207 h at CER 4.3), is likely to give the biggest gains.
- Related-language transfer through staged fine-tuning (Urdu→Pashto) is risky. Multilingual joint fine-tuning, or starting from a model that already saw the language (Omnilingual includes pus/pnb), is safer. This is an inference; I found no Pashto/Punjabi joint fine-tuning ablation.
- LoRA on small Whisper models (base/tiny) badly under-adapts for a new script and phoneme inventory. Use full fine-tuning for models under 250M params.

### Gaps
- I found no published Pashto or Punjabi fine-tuning curve for XLS-R, Omnilingual CTC or w2v-BERT at 1/10/50/100 h. The writer should treat those as needing experiments.
- I could not verify the Omnilingual paper's own fine-tuning or "add a new language" data-scaling results.
- I found no evidence on Hindi→Punjabi or Persian→Pashto staged fine-tuning gains.

---

## 3. Semi-supervised, data augmentation, synthetic data, LM fusion, cross-script transfer

### Takeaway
Augmentation is well supported for Pashto: online speed and noise augmentation gave −7.25 pp WER at 113 h. In-context examples (Omnilingual zero-shot) and n-gram LMs for CTC are cheap wins. Pseudo-labelling, TTS synthesis and Gurmukhi→Shahmukhi transliteration are plausible, but I found no Pashto/Punjabi-specific evidence for them this session.

### Cited Findings
- Online augmentation on Pashto (whisper-base, 113 h, matched settings): WER 27.13% with augmentation vs 34.38% without (−7.25 pp), and CER 8.79% vs 11.43%. The augmentations were speed perturbation ±10–15% and Gaussian noise at SNR 15 dB, applied with p=0.7. — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)
- The offline augmentation set in that paper was speed, pitch shift, Gaussian noise (SNR 15–30 dB), gain and reverb at p=0.7. The augmented dataset is released as `ihanif/pashto_augmented_speech`. — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)
- Omnilingual zero-shot with 10 in-context audio-text examples: average CER fell from 26.33% to 14.4% on 32 unseen languages. This runs on the 7.8B LLM_7B_ZS model (~20 GiB VRAM), so it is server-side only. It could serve as a pseudo-labeller. — [Emergent Mind summary](https://www.emergentmind.com/papers/2511.09690); [README model table](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)
- The MMS paper reports FLEURS-102 results with n-gram LM decoding. A comparison table in the Omnilingual paper gives MMS an average FLEURS-102 CER of about 6.3–6.4 with an LM (search snippet). — [arXiv 2305.13516](https://arxiv.org/pdf/2305.13516); [arXiv 2511.09690](https://arxiv.org/pdf/2511.09690)
- Transcript correction cost: correcting ASR-generated transcripts took about 30 h of labour per audio hour in the lab and 36 h in the field (Bambara study). English professional transcription costs about $90–180 per audio hour in the US. — [arXiv 2510.12781 (search snippet)](https://arxiv.org/pdf/2510.12781v1)

### Inferences
- A practical pipeline, untested for these languages:
  1. Collect unlabelled Pashto/Punjabi audio (radio/YouTube; check copyright).
  2. Pseudo-label it server-side with a fine-tuned Whisper-small/turbo or Omnilingual LLM model, using in-context examples for pnb.
  3. Filter by confidence or agreement between two models.
  4. Train the small on-device CTC/transducer model on the labelled plus pseudo-labelled set.
  5. Add a KenLM or n-gram LM, or sherpa-onnx hotwords, for names and domain terms.
- Narrowband (8 kHz phone-call) simulation is worth adding if the app captions calls.
- Gurmukhi→Shahmukhi transliteration of Indian Punjabi text could generate LM text and pseudo-targets. Transliteration is lossy: short vowels are unwritten in Shahmukhi and the two lexicons differ (Hindi/Sanskrit vs Urdu/Persian loanwords). Its value is unproven.

### Gaps
- I did not confirm whether MMS-TTS has pnb/pus voices or their licence. `facebook/mms-tts-pus` was not found under that ID; other IDs may exist. MMS-TTS is likely CC-BY-NC like MMS, which would bar using it to generate synthetic training data for a commercial model. This needs checking.
- I found no papers on noisy-student or pseudo-labelling for Pashto or Punjabi.
- I found no measured effect of KenLM fusion on Pashto/Punjabi CTC models.
- I found no study of Gurmukhi→Shahmukhi transliteration for ASR.

---

## 4. Streaming on-device: icefall Zipformer, NeMo FastConformer, Whisper chunking, CTC chunked inference, quantisation, measured RTF/RAM

### Takeaway
The proven route to streaming in sherpa-onnx is an icefall streaming Zipformer transducer. Small (~20M) English and Chinese models are documented as suitable for Cortex-A7. The int8 encoders are about 41–87 MB. Low-resource community models, such as Vosk's Bengali streaming Zipformer packaged in Feb 2026, show the path works for new languages. Omnilingual CTC-300M int8 runs in sherpa-onnx but only offline. I found no independently measured RTF or RAM figures for Cortex-A53/A55 phones; HumSukhan needs to benchmark this itself.

### Cited Findings
- sherpa-onnx docs list `sherpa-onnx-streaming-zipformer-en-20M-2023-02-17` and `zh-14M-2023-02-23` as "Suitable for Cortex A7 CPU". The 20M model comes from icefall `pruned-transducer-stateless7-streaming-small`, trained on LibriSpeech. — [sherpa-onnx README](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/README.md); [sherpa docs zipformer-transducer-models.rst (GitHub raw)](https://raw.githubusercontent.com/k2-fsa/sherpa/master/docs/source/onnx/pretrained_models/online-transducer/zipformer-transducer-models.rst)
- Size example: the streaming bilingual small zh-en Zipformer has int8 files of encoder 41 MB, decoder 3.4 MB and joiner 3.1 MB, vs FP32 85/14/13 MB. Exports are available at chunk sizes 32 (default), 64 and 96; "The larger the number, the lower the RTF." — [sherpa docs .rst](https://raw.githubusercontent.com/k2-fsa/sherpa/master/docs/source/onnx/pretrained_models/online-transducer/zipformer-transducer-models.rst)
- `sherpa-onnx-streaming-zipformer-bn-vosk-2026-02-09` (Bengali) is converted from `alphacep/vosk-model-small-streaming-bn`, with encoder.onnx 87 MB. It is a recent low-resource streaming Zipformer packaged for sherpa-onnx. — [sherpa docs .rst](https://raw.githubusercontent.com/k2-fsa/sherpa/master/docs/source/onnx/pretrained_models/online-transducer/zipformer-transducer-models.rst)
- Community model-card RTFs (x86 desktop CPUs, not phones):
  - Korean streaming Zipformer, 71.4M, trained on ~1,000 h KsponSpeech: RTF 0.038 on one CPU thread at chunk-64, int8. — [kangkyu/icefall-asr-ko-streaming-zipformer-72m (search snippet)](https://huggingface.co/kangkyu/icefall-asr-ko-streaming-zipformer-72m)
  - Indian-English streaming Zipformer: int8 RTF 0.035 vs FP32 0.183 on a 4-thread Xeon, 640 ms latency per chunk. — [Akshatkasera007/STT-streaming-zipformer-indian-en (search snippet)](https://huggingface.co/Akshatkasera007/STT-streaming-zipformer-indian-en)
  - Hebrew `zipformer2-66m-streaming-he` ships sherpa-onnx int8 files and a fine-tuning path through icefall's finetune script. — [HF (search snippet)](https://huggingface.co/thewh1teagle/zipformer2-66m-streaming-he)
- Zipformer unified streaming/non-streaming paper: up to 30 epochs on 8× V100. — [arXiv 2506.14434 (search snippet)](https://arxiv.org/pdf/2506.14434)
- Icefall export docs: export scripts differ per recipe, and the chunk-length option is specific to streaming Zipformer. — [icefall export-onnx docs (search snippet)](https://k2-fsa.github.io/icefall/model-export/export-onnx.html)
- NeMo cache-aware streaming:
  - It trains with limited right context and caches activations to avoid recomputation. — [NeMo ASR models docs (search snippet)](https://docs.nvidia.com/nemo-framework/user-guide/26.02/nemotoolkit/asr/models.html)
  - Nemotron speech streaming 0.6B exposes right-context settings {0, 1, 6, 13} via `att_context_size` (e.g. [70,13]). — [search snippet re: NVIDIA docs](https://docs.nvidia.com/deeplearning/nemo/user-guide/docs/en/main/asr/models.html)
  - A community Quran FastConformer streaming fine-tune describes ONNX export with `export_cache_support` and `encoder.forward_for_export`, feeding cache tensors back each chunk. — [HF discussion](https://huggingface.co/Muno459/fastconformer-quran-streaming/discussions/5)
- Omnilingual CTC in sherpa-onnx is an OfflineRecognizer, not streaming. — [HF Space commit snippet](https://huggingface.co/spaces/RO-Rtechs/Am-Srt-v1/commit/8c27967dde77a40417d4b09c748e66e5ab35cfcc)
- Execution providers: a React-Native sherpa-onnx wrapper lists QNN ("Best performance on Qualcomm devices"), NNAPI and XNNPACK, without numbers. — [react-native-sherpa-onnx perf docs (search snippet)](https://www.mintlify.com/xdcobra/react-native-sherpa-onnx/advanced/performance-optimization)
- The Whisper Pashto paper did not measure inference latency or memory: "No deployment cost measurement." — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)

### Inferences
- **Recommended architecture for live captions under 1 s on 2–4 GB A53/A55 phones:** a streaming Zipformer transducer of 20–70M params, int8, chunk-32/64 (~320–640 ms), trained in icefall on Pashto or Punjabi data (labelled plus pseudo-labelled). It decodes with sherpa-onnx OnlineRecognizer, which HumSukhan already uses for English, and the int8 package is about 50–90 MB.
- **Fallback or second pass:** a VAD-segmented offline model (Omnilingual CTC-300M int8, roughly 300+ MB, or a fine-tuned Whisper-base int8, as HumSukhan already does for Urdu) to re-decode finished utterances for accuracy.
- Training a streaming Zipformer from scratch on under 100 h will likely underperform an SSL-pretrained CTC fine-tune. Two options help:
  - Distil or pseudo-label from a large fine-tuned teacher (Whisper-turbo or Omnilingual) onto hundreds of hours of unlabelled audio.
  - Initialise from a multilingual Zipformer.

  This is untested.
- Omnilingual CTC-300M is about 325M params, roughly 4–5× Whisper-base. On a Cortex-A53 at int8 it may be too slow for continuous chunked streaming. Benchmark it before committing.

### Gaps
- I found no measured sherpa-onnx RTF or RAM on Cortex-A53/A55/A75 Android phones for any model, in official docs or community reports this session. The sherpa docs pages with RTF tables were blocked (k2-fsa.github.io 403).
- I found no whisper.cpp or chunked-Whisper streaming latency measurements on ARM.
- I found no documented path converting NeMo cache-aware streaming models to sherpa-onnx's online recognizer. sherpa-onnx does document offline NeMo transducer/CTC models.
- I did not verify GPU-hours for an icefall Zipformer recipe at 50–100 h.

---

## 5. Code-switching and language identification; script normalisation and evaluation

### Takeaway
SpeechBrain's VoxLingua107 ECAPA LID is Apache-2.0 and covers pa, ps and ur. That makes it the commercially usable on-device LID option. MMS-LID-4017 is CC-BY-NC. Whisper LID is MIT-licensed but its Pashto output is unreliable. For evaluation, CER after letter-variant normalisation should be the primary metric for Arabic-script Pashto and Shahmukhi, with normalised WER as secondary. Unnormalised (orthographic) WER is 1–3 pp higher.

### Cited Findings
- `speechbrain/lang-id-voxlingua107-ecapa`: **Apache-2.0**, 107 languages including `pa`, `ps`, `ur`, `hi`, `fa`, `sd`, `en`. — [HF card](https://hf.co/speechbrain/lang-id-voxlingua107-ecapa)
- `facebook/mms-lid-4017`: 970M params, **CC-BY-NC-4.0**. — [HF card](https://hf.co/facebook/mms-lid-4017)
- Whisper zero-shot on Pashto audio outputs Arabic, Dari or Urdu script, with Pashto script in under 0.8% of utterances. This shows Whisper's LID and decoding confuse Pashto with Urdu/Persian. — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)
- sherpa-onnx offers spoken language ID through multilingual Whisper models. — [sherpa-onnx README](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/README.md)
- Omnilingual LLM-ASR models support "optional language conditioning". — [README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)
- Metrics in the Pashto paper:
  - Normalised WER (HF BasicTextNormalizer), orthographic WER and CER are all reported.
  - Orthographic WER runs about 1.3–3.4 pp above normalised WER (e.g. 21.22 vs 22.56; 23.37 vs 26.77).
  - CER is given as "finer-grained signal for Pashto's Perso-Arabic script". — [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)
- Omnilingual reports CER as its primary metric across all languages. — [README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)

### Inferences
- For Urdu–Punjabi–English or Pashto–Urdu–English mixing, the most deployable design is a single multilingual model per region with a shared vocabulary. One example is a Zipformer or CTC trained jointly on ur+pnb+en (Punjab) or ps+ur+en (KP), with English kept in Latin script or transliterated. This avoids routing latency.
- Utterance-level LID routing (ECAPA on a 1–2 s VAD segment) between existing Urdu/English models and a new pnb/ps model is simpler, but it fails on intra-sentence switching.
- Normalisation should map Arabic vs Urdu/Persian letter variants (ي/ی/ې/ۍ/ئ, ك/ک, ه/ہ/ە/ھ, Pashto-specific ګ/ړ/ډ/ټ/ښ/ځ/څ/ږ/ڼ), strip diacritics and tatweel, and unify ZWNJ handling. The masculine ی vs feminine ه confusion in Pashto is a real grammatical error and must not be normalised away.

### Gaps
- I did not obtain VoxLingua107 ECAPA per-language accuracy for pa/ps/ur, or results on short or code-switched segments.
- I found no published token-level LID or code-switching ASR results for Punjabi–Urdu or Pashto–Urdu.
- Whether VoxLingua107 "pa" data is mostly Gurmukhi/Indian Punjabi, which would affect Shahmukhi-speaker detection, is unverified.

---

## 6. Compute and data-collection cost

### Takeaway
Fine-tuning at the scale needed here is cheap. Whisper base/small on about 60–113 h of Pashto fits on a single 24 GB consumer GPU (RTX 4090) in about 10k steps, and turbo fits on a 48 GB A40, rented from RunPod in that study. Labelled data is the dominant cost. Transcript correction runs about 30–36 labour-hours per audio hour, and professional English transcription costs about $90–180 per audio hour.

### Cited Findings
- Hardware used in the Pashto Whisper study (RunPod cloud):
  - whisper-base: single RTX 4090 (24 GB), 10,000 steps.
  - whisper-small: RTX 4000 Ada (20 GB) with gradient checkpointing.
  - whisper-large-v3-turbo: A40 (48 GB), streaming dataset mode to avoid a 110 GB Arrow cache, best checkpoint at step 5,000, effective batch 64.
  - Source: [arXiv 2604.06507](https://arxiv.org/abs/2604.06507v1)
- Omnilingual inference VRAM: CTC_300M ~2 GiB, CTC_1B ~3 GiB, LLM_7B ~17 GiB, LLM_7B_ZS ~20 GiB. — [README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)
- Zipformer research training: up to 30 epochs on 8× V100. — [arXiv 2506.14434 (search snippet)](https://arxiv.org/pdf/2506.14434)
- Transcription and labelling cost: 30 h (lab) to 36 h (field) of human labour per audio hour to correct ASR transcripts in Bambara, and $90–180 per audio hour for US professional English transcription. — [arXiv 2510.12781 (search snippet)](https://arxiv.org/pdf/2510.12781v1)
- Microsoft Research India crowdsourced 109 h of Marathi speech from 36 participants, including low-income workers, with quality comparable to university students'. The snippet did not include cost figures. — [LREC 2020 (search snippet)](https://preview.aclanthology.org/moar-dois/2020.lrec-1.343.pdf)

### Inferences
- A fine-tuning run for whisper-small or XLS-R/Omnilingual-CTC-300M on 50–100 h is plausibly 1–2 GPU-days on a single 24–48 GB GPU, which is low tens of USD at typical rental prices. This is an inference: the paper does not report wall-clock time.
- Budget 10× that for hyperparameter sweeps and a streaming Zipformer trained from pseudo-labels on several hundred hours.

### Gaps
- No source gave explicit GPU-hours or USD for any recipe.
- I found no documented per-hour crowdsourcing cost for Pakistan, or for Common Voice, IndicVoices or Vaani.

---

## 7. Licensing for commercial deployment

### Takeaway
These base models are licensed for commercial use, with attribution required for the CC-BY ones:

| Model | Licence |
|---|---|
| Whisper | MIT |
| XLS-R | Apache-2.0 |
| w2v-BERT 2.0 | MIT |
| Omnilingual ASR | Apache-2.0 |
| Omnilingual corpus | CC-BY-4.0 |
| NVIDIA Parakeet/Canary/FastConformer streaming | CC-BY-4.0 |
| Kyutai STT | CC-BY-4.0 |
| Moonshine (most models) | MIT |
| VoxLingua107 ECAPA LID | Apache-2.0 |
| IndicConformer | MIT (gated) |

MMS ASR and MMS-LID are CC-BY-NC-4.0 and cannot ship in a commercial app, and some older Moonshine non-English models are non-commercial.

### Cited Findings
- MIT: Whisper large-v3-turbo — [card](https://hf.co/openai/whisper-large-v3-turbo); w2v-BERT 2.0 — [card](https://hf.co/facebook/w2v-bert-2.0); Moonshine English/streaming-tiny — [card](https://hf.co/moonshine-ai/moonshine-streaming-tiny); IndicConformer 600M — [card](https://hf.co/ai4bharat/indic-conformer-600m-multilingual)
- Apache-2.0: XLS-R 300M — [card](https://hf.co/facebook/wav2vec2-xls-r-300m); Omnilingual ASR code and models — [README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md); VoxLingua107 ECAPA — [card](https://hf.co/speechbrain/lang-id-voxlingua107-ecapa)
- CC-BY-4.0: Parakeet-TDT-0.6B-v3 — [card](https://hf.co/nvidia/parakeet-tdt-0.6b-v3); Canary-1B-v2 — [card](https://hf.co/nvidia/canary-1b-v2); FastConformer hybrid streaming — [card](https://hf.co/nvidia/stt_en_fastconformer_hybrid_large_streaming_multi); Kyutai stt-1b-en_fr — [card](https://hf.co/kyutai/stt-1b-en_fr); omnilingual-asr-corpus dataset — [README](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/README.md)
- CC-BY-NC-4.0 (non-commercial): MMS-1B-all — [card](https://hf.co/facebook/mms-1b-all); MMS-LID-4017 — [card](https://hf.co/facebook/mms-lid-4017)
- Moonshine Community License: non-commercial, applies to older non-streaming non-English models (e.g. Korean). — [Moonshine Voice docs (search snippet)](https://moonshine-voice.readthedocs.io/en/stable/models/available-models/)
- A third-party CoreML int8 conversion of Omnilingual CTC-300M (`aoiandroid/omni-asr-coreml-int8`) is labelled CC-BY-NC-4.0 for the conversion, unlike the Apache-2.0 upstream. Check the licence of each converted artefact, not just the upstream model. — [search snippet](https://huggingface.co/aoiandroid/omni-asr-coreml-int8)

### Inferences
- In-app attribution and NOTICE files:
  - Apache-2.0 (Omnilingual, XLS-R, SpeechBrain LID): include the licence text and NOTICE.
  - CC-BY-4.0 (any NVIDIA/Kyutai weights, the Omnilingual corpus): credit the source and note modifications.
  - MIT: include the copyright notice.
- Fine-tuned derivatives inherit these obligations.
- Data licences matter as much as model licences:
  - Common Voice is CC0, safe for commercial training.
  - FLEURS is CC-BY-4.0.
  - Any CC-BY-NC, LDC or "research only" corpus (e.g. some CLE/UET datasets) would taint a commercial model.
  - Pseudo-labelling with a CC-BY-NC model such as MMS is a legal grey area. Avoid it, or get legal advice.

### Gaps
- I did not verify the licence of the sherpa-onnx Omnilingual int8 export repo; its card shows no licence tag.
- I did not verify current NVIDIA "Open Model License" terms for newer Nemotron/Parakeet releases, beyond the CC-BY-4.0 tags on the cards checked.
- I did not verify the dataset licences of Common Voice Pashto/Punjabi, FLEURS or the CLE corpora this session; another researcher covers the inventories.
