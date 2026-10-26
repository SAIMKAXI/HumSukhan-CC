# Pashto ASR inventory (models, datasets, results, APIs) as of Oct 2026

Researcher notes, compiled 2026-10-26. Sources used: the Hugging Face MCP tools (hf_fs `cat`/`ls`/`search`, hub_repo_search), which returned model cards, dataset file listings and arXiv full text through `hf://papers`; WebSearch snippets; and raw.githubusercontent.com for the Omnilingual ASR repo files.

Sites that could not be opened in this environment: arxiv.org, docs.cloud.google.com, learn.microsoft.com, elevenlabs.io, soniox.com, deepgram.com, assemblyai.com, catalog.ldc.upenn.edu and datacollective.mozillafoundation.org. They failed with DNS errors or a proxy 403. Every claim taken from those sites comes from a **search snippet** and is marked that way.

Two kinds of WER appear below. **Author-reported** means the number comes from the model card or paper. **Independently reproduced** means a third party re-ran the evaluation. Only the Rahman 2026 benchmark (arXiv 2604.04598) re-evaluates other people's models.

---

## 1. Pretrained and fine-tuned models: Whisper, HF fine-tunes, MMS, Omnilingual, Seamless, others

### Takeaway
Off-the-shelf Whisper (every size, including large-v3 and turbo) does not work for Pashto. Its WER is above 89% and can exceed 100%, and fewer than 0.8% of its outputs are in Pashto script. Usable open options fall into two groups:
- **Fine-tuned Whisper checkpoints.** The best author-reported WERs are about 13–25% on in-distribution Common Voice tests, with 30–60% WER out of domain.
- **Massively multilingual CTC models.** These are MMS-1B-all, Meta Omnilingual ASR (codes pbt, pbu, pst and pus) and SeamlessM4T-v2. They write Pashto script correctly but score about 40–48% WER zero-shot.

For a commercial, offline, low-RAM Android app, the licence-clean candidates are:
- Omnilingual ASR, Apache-2.0. A sherpa-onnx int8 export already exists.
- Apache-2.0 Whisper fine-tunes trained only on CC0 (Common Voice) or CC-BY (FLEURS) data. The strongest is ihanif/exp_009_small_cv24_vanilla, and a whisper.cpp q8 base model of about 78 MB exists.

MMS-1B-all and SeamlessM4T-v2 are CC-BY-NC 4.0, so they cannot be used commercially.

### Cited Findings

**Whisper zero-shot (independent benchmark)**
- Zero-shot WER for all seven Whisper sizes ranges from 90% to 297% on FLEURS ps_af test and a filtered CV24 subset. Whisper-medium collapses to 461% on CV24, consistent with decoder looping. No Whisper model produces Pashto-script output in more than 0.8% of utterances. MMS-1B, SeamlessM4T and OmniASR each exceed 93% Pashto-script fidelity. Pashto-unique phonemes (the retroflex series and lateral fricatives) carry a disproportionate share of errors. Rahman, Apr 2026. — [HF paper page, arXiv 2604.04598](https://huggingface.co/papers/2604.04598)
- Search-snippet figures from the same paper, which could not be read directly:
  - FLEURS Pashto WER: Whisper large-v2 95.7% and large-v3 89.8%.
  - OmniASR-CTC-300M zero-shot: 48.0% WER on FLEURS and 45.1% on CV24.

  — [arXiv 2604.04598 (via search snippet)](https://arxiv.org/pdf/2604.04598)
- Zero-shot WER on the CV24 test (N=13,643): whisper-base 171.4%, whisper-small 120.4%, whisper-large-v3-turbo 110.2%. All three output "Arabic, Dari, or Urdu script rather than Pashto". — [Rahman, "Fine-tuning Whisper for Pashto ASR: strategies and scale", arXiv 2604.06507, full text via HF](https://huggingface.co/papers/2604.06507)
- The paper says Pashto is "absent from Whisper's 680,000-hour pre-training corpus" in one passage and has "minimal presence" in another. — [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- Whisper Base zero-shot WER on Pashto is cited as 99.0%. — [Rahman & ur Rehman, arXiv 2603.27021 (search snippet)](https://arxiv.org/pdf/2603.27021)
- ElevenLabs' marketing table gives Whisper Large v3 94.3% FLEURS Pashto WER (vendor-reported). — [ElevenLabs Pashto STT page (search snippet)](https://elevenlabs.io/speech-to-text/pashto)
- Gap: the original Whisper paper (arXiv 2212.04356), Appendix Table 13, does have a FLEURS Pashto row, but I could not open it. See Gaps.

**Peer-reviewed / arXiv fine-tune results (Hanif Rahman, 2026)**
- Strategy comparison on whisper-base, CV20 test (2,800 utterances, about 3.2 h), author-reported:

  | Strategy | WER | CER |
  |---|---:|---:|
  | Vanilla full fine-tune | 21.22% | 8.52% |
  | Frozen 2 of 6 encoder layers | 35.98% | — |
  | LoRA r=64 | 54.58% | — |
  | Urdu→Pashto multistage, from sharjeel103/whisper-base-urdu | 65.78% | — |

  Urdu transfer *hurts*. The authors recommend Persian/Dari as the intermediate language instead. — [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- Model scale on CV24, training on train+dev (92,880 utterances, about 113.4 h), testing on 13,791 utterances (about 20.7 h):

  | Model | Params | WER | CER |
  |---|---:|---:|---:|
  | whisper-base | 74.4M | 27.13% | 8.79% |
  | whisper-small | 244M | 24.89% | 8.08% |
  | whisper-large-v3-turbo | 809M | 23.37% | 7.64% |

  The authors call whisper-small "the practical optimum" at this data size. Online augmentation (speed perturbation and noise) gave a 7.25 pp WER gain. The dominant errors are masculine ی vs feminine ه word-final suffix confusion, and substitutions involving څ /ts/. The paper did no dialect stratification ("speaker metadata is inconsistently labelled") and no latency or memory measurement. — [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- Whisper Base fine-tuned on MCV20 reaches 13.4% WER on the MCV20 test split. The authors note this test split differs from other benchmarks, so results are not comparable. — [arXiv 2603.27021 (search snippet)](https://arxiv.org/pdf/2603.27021)
- In the cross-domain re-evaluation of five community fine-tuned Pashto models, published WERs of about 14% degrade to 32.5–59% on out-of-distribution test sets. One augmented model scores 35.1% on both sets. — [arXiv 2604.04598](https://huggingface.co/papers/2604.04598)

**Hugging Face Hub fine-tunes (verified to exist via HF MCP; all WERs author-reported unless noted)**

| Repo ID | Base / size | Reported result | Training data | Licence (card) | Downloads |
|---|---|---|---|---|---|
| [ihanif/exp_009_small_cv24_vanilla](https://huggingface.co/ihanif/exp_009_small_cv24_vanilla) | whisper-small 244M | WER 24.89 / CER 8.08, CV24 test | CV24 train+dev (~113 h) | Apache-2.0 | 22 |
| [ihanif/exp_010_turbo_cv24_vanilla](https://huggingface.co/ihanif/exp_010_turbo_cv24_vanilla) | large-v3-turbo 809M | WER 23.37, CV24 test (paper) | CV24 | not checked | 16 |
| [ihanif/exp_008_base_cv24_vanilla](https://huggingface.co/ihanif/exp_008_base_cv24_vanilla) | whisper-base 74M | WER 27.13, CV24 (paper) | CV24 + augmentation | not checked | 12 |
| [ihanif/exp_001_base_vanilla](https://huggingface.co/ihanif/exp_001_base_vanilla) | whisper-base | WER 21.22 / CER 8.52, CV20 test | CV20 augmented | — | 8 |
| [ihanif/exp_001_base_vanilla-gguf](https://huggingface.co/ihanif/exp_001_base_vanilla-gguf) | whisper.cpp q8_0 (~78 MB) / f16 (~141 MB) | same | same | Apache-2.0 | 0 |
| [Nasimbahar/pashto-ghag-whisper-medium-asr](https://huggingface.co/Nasimbahar/pashto-ghag-whisper-medium-asr) | whisper-medium 769M | balanced mean WER 14.63 / CER 4.66 (dev_clean 12.47, dev_real 15.42, test_frozen 16.01) on author's own splits | CV17 validated, 73,355 clips / 54.4 h | Apache-2.0 | 153 |
| [nassimjp/whisper-v1-pashto-turbo](https://huggingface.co/nassimjp/whisper-v1-pashto-turbo) (card says loading id `Thomcles/whisper-v1-pashto-turbo`, calls itself "private") | large-v3-turbo | dev WER: CV27 17.85%, Spontaneous Pashto Speech 5: 41.04%, FLEURS 33.87%, macro 30.92% | 394.6 h: CV27 280.5 h (CC0), Spontaneous Speech 5 70.4 h (CC0), FLEURS 29.1 h (CC-BY-4.0), Sabtain 6.7 h, YouTube subs ~7.9 h (licence not recorded) | **No licence asserted**; card warns against commercial use without a rights review | 19 |
| [uzair0/Katib-ASR](https://huggingface.co/uzair0/Katib-ASR) (+ CT2 conversion [MWaqar996/Katib-ASR-CT2](https://huggingface.co/MWaqar996/Katib-ASR-CT2)) | whisper-large-v3 1.55B | WER 28.23 on own held-out multi-dialect set | CV24 + FLEURS + in-house recordings; claims "Afghan & Pakistani dialects"; built at University of Peshawar | **No licence metadata in card** | 196 |
| [BuzzASR/pashto](https://huggingface.co/BuzzASR/pashto) | whisper-large-v3 | CER/WER: FLEURS 19.09/47.89; CV25 8.7/26.46; combined 11.1/31.4 (large-v3 zero-shot CER 36.45) | FLEURS + CV25 (+ Goldfish text) | MIT | — |
| [ihanif/wav2vec2-xls-r-300m-pashto](https://huggingface.co/ihanif/wav2vec2-xls-r-300m-pashto) | XLS-R 300M CTC | WER 51.59 / CER 19.72, FLEURS ps_af test | FLEURS ps_af | Apache-2.0 | **222K** (most-downloaded Pashto ASR repo) |
| [ihanif/w2v-bert2-pashto-augmented](https://huggingface.co/ihanif/w2v-bert2-pashto-augmented) | w2v-BERT 2.0 (~600M) CTC | WER 34.31, FLEURS ps_af test | FLEURS | MIT | 91 |
| [ihanif/pashto-asr-v3](https://huggingface.co/ihanif/pashto-asr-v3) | w2v-BERT 2.0 | WER 13.96 (eval set unspecified, "None dataset") | unspecified | MIT | 93 |
| [ihanif/pashto-asr-v6](https://huggingface.co/ihanif/pashto-asr-v6) | w2v-BERT chain (from v5) | eval WER 30.13 | CV19 | none stated | 26 |
| [ihanif/whisper-medium-pashto](https://huggingface.co/ihanif/whisper-medium-pashto) | whisper-medium | WER 49.49, FLEURS test | FLEURS | Apache-2.0 | 36 |
| [ihanif/whisper-large-pashto](https://huggingface.co/ihanif/whisper-large-pashto) | whisper-large-v2 | WER 54.07, FLEURS test | FLEURS | Apache-2.0 | 22 |
| [ihanif/whisper-small-pashto](https://huggingface.co/ihanif/whisper-small-pashto) | whisper-small | WER 63.11, FLEURS test | FLEURS | Apache-2.0 | 44 |
| [Adnan666/whisper-small-pashto-stage2-v2](https://huggingface.co/Adnan666/whisper-small-pashto-stage2-v2) (and run11-cv24only, run11-epoch2) | whisper-small | eval WER 35.91 (dataset "unknown") | CV24 (per repo names) | Apache-2.0 | 112–252 |
| [Adnan666/whisper-small-pashto](https://huggingface.co/Adnan666/whisper-small-pashto) | from ihanif/whisper_small_ps_augmented | eval WER 32.61 | unknown | Apache-2.0 | 12 |
| [afzalmengal/whisper-small-pashto](https://huggingface.co/afzalmengal/whisper-small-pashto) | whisper-small | eval WER 30.88 | unknown | Apache-2.0 | 22 |
| [Sabtain-Dev/STT-Whisper-Pashto](https://huggingface.co/Sabtain-Dev/STT-Whisper-Pashto) | whisper-small + LoRA | test WER 43.83 | Sabtain-Dev/Pashto-ASR-Dataset | MIT | 7 |
| [AbdulMoizShah01/Whisper-Pashto](https://huggingface.co/AbdulMoizShah01/Whisper-Pashto) | whisper-medium | no WER; card claims CV (~200 h) plus ~300 h of news, podcast and conversational data (unverified) | — | card text says Apache-2.0 | 0 |
| [karimnaimy/pashto-whisper-small-ct2](https://huggingface.co/karimnaimy/pashto-whisper-small-ct2), [karimnaimy/pashto-voice-wav2vec2](https://huggingface.co/karimnaimy/pashto-voice-wav2vec2) | CTranslate2 / wav2vec2 | no card | — | — | ≤9 |

— Source for the whole table: HF MCP `cat README.md` of each repo; download counts from hub_repo_search on 2026-10-26.

**Massively multilingual models**
- [facebook/mms-1b-all](https://huggingface.co/facebook/mms-1b-all): 1B-parameter wav2vec2 with per-language adapters. `ps` is listed among its languages. Licence is **cc-by-nc-4.0**. — [model card via HF MCP](https://huggingface.co/facebook/mms-1b-all)
- MMS-1B zero-shot scores 43.8% WER on FLEURS Pashto, with more than 93% Pashto-script fidelity. — [arXiv 2604.04598](https://huggingface.co/papers/2604.04598)
- [facebook/seamless-m4t-v2-large](https://huggingface.co/facebook/seamless-m4t-v2-large): `ps` is listed. Licence is **cc-by-nc-4.0**. It scores 39.7% WER on CV24 zero-shot, the best zero-shot result reported as of April 2026. — [model card via HF MCP](https://huggingface.co/facebook/seamless-m4t-v2-large); [arXiv 2604.04598](https://huggingface.co/papers/2604.04598)
- **Meta Omnilingual ASR** (released 10 Nov 2025): models are Apache-2.0 and the corpus is CC-BY-4.0. The family includes:
  - CTC 300M: 325M params, 1.3 GiB FP32, about 2 GiB VRAM, RTF 0.001
  - CTC 1B
  - CTC 3B
  - CTC 7B
  - LLM-ASR 300M–7B
  - 7B zero-shot

  The CTC and LLM models accept audio shorter than 40 s. "Unlimited" v2 LLM variants exist. Streaming is not mentioned. — [facebook/omniASR-CTC-300M card](https://huggingface.co/facebook/omniASR-CTC-300M); [GitHub facebookresearch/omnilingual-asr](https://github.com/facebookresearch/omnilingual-asr); [Meta blog](https://ai.meta.com/blog/omnilingual-asr-advancing-automatic-speech-recognition/)
- Omnilingual supported-language IDs include `pbt_Arab`, `pbu_Arab`, `pst_Arab` and `pus_Arab`. I verified this with `lang_ids.py` from the repo. — [raw lang_ids.py](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/src/omnilingual_asr/models/wav2vec2_llama/lang_ids.py)
- Omnilingual 7B LLM-ASR per-language results (Meta's own test sets, author-reported):

  | Code | Training hours | CER |
  |---|---:|---:|
  | pbt_Arab | 5.6 | 8.8 |
  | pbu_Arab | 5.2 | 7.5 |
  | pst_Arab | 5.3 | 3.5 |
  | pus_Arab | 28.7 | 12.6 |

  For comparison: urd_Arab 237.5 h / CER 3.5, eng_Latn CER 3.0. These are numbers for the **7B** model. Smaller CTC models will be worse. — [per_language_results_table_7B_llm_asr.csv](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/per_language_results_table_7B_llm_asr.csv)
- OmniASR-CTC-300M zero-shot (independent): 48.0% WER on FLEURS and 45.1% on CV24 (search snippet), with more than 93% Pashto-script fidelity. — [arXiv 2604.04598](https://huggingface.co/papers/2604.04598)
- **sherpa-onnx exports** of Omnilingual exist:
  - [csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12](https://huggingface.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12): `model.int8.onnx` 365 MB plus `tokens.txt`.
  - A 1B int8 variant.
  - v2 2026-02-05 re-exports under csukuangfj2.

  These are offline (non-streaming) CTC models. — HF MCP `ls` of the repo.
- I found no Pashto-specific sherpa-onnx or k2 streaming Zipformer, and no Vosk Pashto model. Searching HF for "sherpa-onnx pashto" returned nothing. — HF MCP search, 2026-10-26.

### Inferences
- **Best offline fit for HumSukhan today:** two routes look viable.
  1. Omnilingual CTC-300M int8 through the sherpa-onnx runtime the app already uses (365 MB, Apache-2.0). It writes correct Pashto script, but WER is about 45–48% zero-shot and it is not streaming. It would need VAD-chunked pseudo-streaming, the way Whisper is already handled for Urdu.
  2. A Whisper-small or base Pashto fine-tune (Apache-2.0, CV-only data) exported to sherpa-onnx Whisper int8, the same pipeline as the current Urdu Whisper-base int8. Expected in-domain WER is about 25–27%.

  Fine-tuning Omnilingual CTC-300M on CV Pashto (CC0) would likely beat both. Recipes exist in the repo. This is not verified.
- MMS-1B-all and SeamlessM4T-v2 are useful only as non-commercial research baselines. Their CC-BY-NC licence rules them out of a commercial app.
- Katib-ASR and nassimjp/whisper-v1-pashto-turbo are the only open models claiming Pakistani-dialect or spontaneous-speech coverage. One has no licence and the other explicitly disclaims commercial rights, so neither is safe to ship.
- Most community WERs (13–15%) are on CV splits that likely share sentences or speakers with training data. Rahman's cross-domain re-test (32.5–59%) is the more realistic expectation for live speech.

### Gaps
- The exact Whisper-paper (2212.04356, Table 13) FLEURS Pashto WERs per size could not be read because arxiv.org is blocked. Only the derived 95.7% (large-v2) and 89.8% (large-v3) figures from Rahman's paper were found, via snippet.
- I could not read the full per-model tables of arXiv 2604.04598, including CER values and which five community models were re-tested.
- MMS-1B-all Pashto adapter-specific CER/WER from the MMS paper was not retrieved.
- SeamlessM4T-v2 FLEURS Pashto numbers from Meta's paper were not retrieved.
- NVIDIA NeMo, Canary and Parakeet: I found no evidence of Pashto support in this session and did not search exhaustively. Assumption: Canary and Parakeet v3 cover only English and European languages, so no Pashto. This is unverified.
- Google USM paper Pashto numbers: not retrieved.

---

## 2. Datasets: speech corpora and text corpora

### Takeaway
Mozilla Common Voice Pashto is CC0, and since 2024 it has become one of the largest Common Voice languages, with roughly 960–976 validated hours in CV24 (Dec 2025). It is the clear commercial-safe training base. It is read speech, its accent labels are inconsistent, and validated-hour figures vary between sources.

Other commercially usable resources:
- FLEURS ps_af, CC-BY-4.0, read Afghan Pashto.
- Meta's Omnilingual corpus, CC-BY-4.0, with pbt, pbu and pst splits of about 1.5–1.8 GB each.

Non-commercial or restricted resources:
- IARPA Babel Pashto, LDC2016S09: about 244 h of conversational telephone speech covering Afghan and Pakistani dialect regions. It is the only large conversational corpus, and it is available under LDC licence and cost.

### Cited Findings

**Common Voice Pashto (CC0)**
- CV24 Pashto (Dec 2025): 2,407,799 clips, 6,654 speakers, 975.89 validated hours, 2,768.7 total hours, up from 1.49 recorded hours in mid-2023. — [Jahani, Dawodi & Baktash, arXiv 2602.14062 (search snippet)](https://www.arxiv.org/abs/2602.14062)
- CV24 per Rahman: 840,479 validated samples (about 960.8 h), 866 unique speakers in the splits used. Official splits are train 79,089 (~94.3 h), dev 13,791 (~19.1 h) and test 13,791 (~20.7 h). That is only about 134 h in official splits, versus about 960 h validated. — [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- CV25 "Scripted Speech 25.0 – Pashto" Mozilla datasheet (released 30 Mar 2026): 4,850,876 clips, 5,313.64 h recorded (3,041.86 h validated), 8,239 speakers. The accent table could not be read. — [Mozilla Data Collective (search snippet)](https://datacollective.mozillafoundation.org/datasets/cmndf6mgs001lnz07bf9t3skp)
- **Conflict:** CV24 validated hours are about 960–976 h in two papers, while the CV25 datasheet gives 3,041.86 h. This may reflect real growth or a different counting method. It is unresolved.
- History: the corpus grew from 1.5 h and 5 contributors to 147 total hours and 1,483 speakers over CV14–CV23. MCV23 has 107,781 clips (60,337 validated, 82.33 validated hours) across 13 domains. Speakers jumped about 108× between CV17 and CV18, coinciding with a **VOA Pashto broadcast campaign**. — [Rahman & ur Rehman, arXiv 2603.27021 (search snippet)](https://arxiv.org/pdf/2603.27021)
- CV20 Pashto train+validated: 49,870 utterances, 179 speakers, "19 accent/dialect variants", 69 content domains. The paper says Common Voice "captures both [Southern Kandahari/Quetta and Northern Yusufzai/Peshawar] groups … though the distribution is uncontrolled and unbalanced". — [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- CV27 (`cv-corpus-27.0-2026-09-11`) and **Spontaneous Pashto Speech 5.0** (`sps-corpus-5.0-2026-09-11`, CC0) exist. One trainer used 280.5 h of CV27 and 70.4 h of spontaneous speech. — [nassimjp/whisper-v1-pashto-turbo card](https://huggingface.co/nassimjp/whisper-v1-pashto-turbo)
- The HF mirror `ihanif/common-voice-pashto-24` used in Rahman's paper returned "Repository not found" via the HF API on 2026-10-26, so it is gated, private or removed. Community re-uploads exist (fsicoli/common_voice_17_0/19_0/22_0, deepdml/common_voice_26_0 gated manual, Adnan666/pashto-cv24-1m-processed, SherwinDesouza/pashto-common-voice-20). — HF MCP.

**FLEURS ps_af**
- [google/fleurs](https://huggingface.co/datasets/google/fleurs) has config `ps_af` and licence **CC-BY-4.0**. — card via HF MCP.
- FLEURS Pashto (Afghanistan) is about 29.1 h, 8,369 rows, per one trainer's manifest. — [nassimjp card](https://huggingface.co/nassimjp/whisper-v1-pashto-turbo)

**Meta Omnilingual ASR corpus**
- [facebook/omnilingual-asr-corpus](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus) is CC-BY-4.0 and has configs `pbt_Arab`, `pbu_Arab` and `pst_Arab`.
  - pbt train is about 1.03 GB of parquet across 3 shards, with dev 368 MB and test 384 MB.
  - pst train is about 0.97 GB, with dev 452 MB and test 384 MB.
  - pbu train is about 0.89 GB, with dev 237 MB and test 378 MB.

  — HF MCP `ls`; licence from [omniASR card](https://huggingface.co/facebook/omniASR-CTC-300M)
- The sherpa-onnx Omnilingual card shows photographs "captured during corpus creation efforts in **Pakistan** and Liberia". — [csukuangfj sherpa-onnx omnilingual card](https://huggingface.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12)

**IARPA Babel Pashto (LDC2016S09, IARPA-babel104b-v0.4bY)**
- About 244 h of conversational and scripted *telephone* speech collected in 2011–2012 with transcripts, developed by Appen and released 15 Sep 2016. It covers **four dialect regions of Afghanistan and Pakistan**. The ISLRN record says about 214 h, which conflicts. A BUT OpenSAT 2019 system trained on about 92 h of provided Pashto. Distribution is under the LDC licence; cost was not retrieved. — [LDC catalog (search snippet)](https://catalog.ldc.upenn.edu/LDC2016S09); [ISLRN](https://www.islrn.org/resources/594-996-615-028-9/); [BUT OpenSAT 2019, arXiv 2001.11360](https://arxiv.org/pdf/2001.11360)

**Other HF speech datasets (author-claimed licences, unverified provenance)**
- [Sabtain-Dev/Pashto-ASR-Dataset](https://huggingface.co/datasets/Sabtain-Dev/Pashto-ASR-Dataset): MIT; 1K–5K clips in the domains agriculture, general, food services, health and services; mixed mp3/ogg/m4a/wav; also on Kaggle (itssabtain/pashto-asr-dataset). One trainer measured 2,590 rows / 6.7 h and treated it as "silver" labels whose underlying provenance "should be verified". — HF MCP; [nassimjp card](https://huggingface.co/nassimjp/whisper-v1-pashto-turbo)
- [Urffire/speech-corpus-he-ar-fa-ps](https://huggingface.co/datasets/Urffire/speech-corpus-he-ar-fa-ps) (Sep 2026): Pashto is 45.8 h (0.2 h spontaneous YouTube, 45.6 h read/broadcast). Every row is labelled with licence and a `commercial_ok` flag. Corpus-wide, CC-BY sources are FLEURS, Omnilingual and YODAS, and non-commercial sources are WorldSpeech (CC-BY-NC) and SADA. — HF MCP
- [shunyalabs/pashto-speech-dataset](https://huggingface.co/datasets/shunyalabs/pashto-speech-dataset): 2,513 / 217 / 512 train/validation/test clips, about 2.6 GB, no licence or provenance in the card. — HF MCP
- [ZamAI-Pashto/zamai-pashto-voice2voice](https://huggingface.co/datasets/ZamAI-Pashto/zamai-pashto-voice2voice): only 50 metadata rows with dialect tags; Apache-2.0; prototype only. — HF MCP
- `ihanif/pashto_augmented_speech` is a pre-augmented CV20 set used in arXiv 2604.06507. — [paper](https://huggingface.co/papers/2604.06507)
- YODAS2 ([sarulab-speech/yodas2_sidon](https://huggingface.co/datasets/sarulab-speech/yodas2_sidon)) appears under the language:ps ASR tag. It is YouTube CC-licensed audio, and the Pashto hours were not retrieved. — HF MCP search

**Academic corpora (Pakistan)**
- UET Peshawar (Dr. Nasir Ahmad group, 2012) built a 161-word isolated-word Pashto corpus (30 speakers, native and non-native, office recording) and a Pashto spoken-digits 0–100 database (60 speakers, 30 male and 30 female). Public availability is unknown. — [UET Peshawar isolated words corpus PDF](https://uetpeshawar.edu.pk/TRP-G/Dr.Nasir-Ahmad-TRP/Conferences/2012/The%20Development%20of%20Isolated%20Words%20Corpus%20of%20Pashto%20for%20the%20Automatic%20Speech%20Recognition%20Research.pdf); [digits PDF](https://uetpeshawar.edu.pk/TRP-G/Dr.Nasir-Ahmad-TRP/Conferences/2012/Pashto%20Spoken%20Digits%20Database%20for%20the%20Automatic%20Speech%20Recognition%20Research.pdf)
- A 2025 JEAS paper reports a medium-size continuous Pashto speech corpus with a phonetic dictionary, using MFCC/PLP features and HMM recognition. — [JEAS 44:37–49 (search snippet)](https://media.researcherslinks.com/uploads/currentIssues/pdf/1775039412JEAS_44_37-49.pdf)
- Dialectology: a University of Malakand study looks at the Thanewal accent of the Yusufzai dialect (7 speakers, 50 words). — [Pashto journal UoM (search snippet)](https://www.journals.uom.edu.pk/palatana/article/download/485/239/711)

**Text corpora for language models and normalisation**
- FineWeb-2 `pbt_Arab` train: one 855.7 MB parquet shard. Licence for FineWeb-2 is ODC-By per HF convention, not verified in this session. — HF MCP `ls hf://datasets/HuggingFaceFW/fineweb-2/data/pbt_Arab/train`
- Wikipedia Pashto (wikimedia/wikipedia 20231101.ps): 53.3 MB parquet, CC-BY-SA. — HF MCP `ls`
- Other text corpora on the Hub:
  - `ihanif/pashto-wikipedia-corpus`
  - `ihanif/ps_news_2020_100K-sentences_processed` (Leipzig-style news sentences, gated "auto")
  - `anwarosmani1/pashto-news-24k` (24K news items)
  - Many LLM SFT sets by nassimjp and tasal9/ZamAI (Apache/MIT/CC-BY claims).

  — HF MCP search
- Goldfish text corpus was used by BuzzASR. — [BuzzASR/pashto card](https://huggingface.co/BuzzASR/pashto)

### Inferences
- Common Voice Pashto (CC0) is now large enough (hundreds of validated hours) to fine-tune small on-device models commercially. The official train split uses only about 94 h. Building custom splits from the full validated set, speaker-disjoint and deduplicated by sentence, is the main lever.
- FLEURS and Omnilingual (CC-BY-4.0) are commercially usable with attribution. YouTube-derived and Kaggle sets need case-by-case rights checks.
- The Babel data matters for telephone and conversational speech and for Pakistani dialect coverage. LDC licensing may restrict commercial model distribution, so its commercial terms need checking with LDC.

### Gaps
- Official Common Voice CV26 and CV27 Pashto validated hours, gender split and accent distribution: Mozilla pages were blocked, and the HF mirror lacks stats.
- Spontaneous Speech Pashto total hours and licence: only one trainer's manifest (70 h used, CC0) was found.
- OpenSLR: no Pashto resource found. I did not search exhaustively.
- Babel Pashto LDC price and non-member cost: not retrieved.
- OSCAR and CC-100 Pashto sizes: not retrieved.
- MMS training-data sources for Pashto (Bible/religious read speech): not retrieved.

---

## 3. Published research, 2020–2026: dialects, script normalisation, code-switching

### Takeaway
Academic Pashto ASR was nearly absent until a burst of 2026 papers, mostly by Hanif Rahman (ihanif), plus a CHiPSAL 2025 workshop paper. These papers agree on four points:
- Fine-tuning is mandatory.
- Script normalisation is critical, because Arabic, Persian and Urdu letter variants creep into both transcripts and outputs.
- Pashto-unique letters (څ, retroflexes, ښ/ږ) and gender suffixes (ی vs ه) dominate errors.
- Dialect-stratified evaluation and code-switching studies **do not exist yet**.

### Cited Findings
- **Rahman 2026a, arXiv 2604.04598.** This is the first reproducible multi-model zero-shot and cross-domain benchmark on public Pashto data. It reports five structural impediments and five research priorities, and covers read speech only. — [HF paper](https://huggingface.co/papers/2604.04598)
- **Rahman 2026b, arXiv 2604.06507.** Covers strategies and scale, as summarised in section 1. Pashto is described as a 44-letter extended Perso-Arabic script, with two major dialect groups, Southern (Kandahari/Quetta) and Northern (Yusufzai/Peshawar), which differ in vowels, some consonant correspondences and lexicon. The paper did no dialect-stratified evaluation. — [HF paper](https://huggingface.co/papers/2604.06507)
- **Rahman & ur Rehman 2026, arXiv 2603.27021.** Covers the history of the Pashto Common Voice corpus and the 13.4% WER Whisper-Base baseline. — [arXiv (snippet)](https://arxiv.org/pdf/2603.27021)
- **Jahani, Dawodi & Baktash 2026, arXiv 2602.14062.** A release-level analysis of CV24 Pashto. — [arXiv (snippet)](https://www.arxiv.org/abs/2602.14062)
- **Sehar et al., CHiPSAL 2025** (COLING workshop). Title: "Benchmarking Whisper for Low-Resource Speech Recognition: An N-Shot Evaluation on Pashto, Punjabi, and Urdu". It fine-tunes Whisper-small and reports significant WER reductions from few-shot fine-tuning. — [ACL Anthology 2025.chipsal-1.20 (snippet)](https://preview.aclanthology.org/credits/2025.chipsal-1.20)
- **BuzzASR** (Singh, Yadavalli, Arnett & Warstadt), arXiv 2609.09554, Findings of EMNLP 2026. It covers 102 monolingual Whisper-large-v3 fine-tunes, including Pashto. — [BuzzASR/pashto card](https://huggingface.co/BuzzASR/pashto)
- **Script normalisation in practice.** Katib-ASR maps:
  - Arabic Kaf ك → Pashto ک
  - ݢ / گ → Pashto Gaf ګ
  - Arabic Yeh and Alef Maqsura variants → Pashto ی
  - and strips non-Arabic-script noise.

  Rahman uses HF BasicTextNormalizer and reports both normalised and orthographic WER, with a gap of about 3 pp. — [Katib-ASR card](https://huggingface.co/uzair0/Katib-ASR); [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- The Nasimbahar model card notes "performance will vary across dialects … and code-switched speech". The AbdulMoizShah01 card lists "code-switching beyond simple borrowings" as out of scope. — [Nasimbahar card](https://huggingface.co/Nasimbahar/pashto-ghag-whisper-medium-asr); [AbdulMoizShah01 card](https://huggingface.co/AbdulMoizShah01/Whisper-Pashto)
- On spontaneous speech, a turbo fine-tune trained on 395 h still scores 41.04% WER on Spontaneous Pashto Speech, against 17.85% on read CV27. — [nassimjp card](https://huggingface.co/nassimjp/whisper-v1-pashto-turbo)

### Inferences
- HumSukhan will need its own normaliser for both references and outputs: Arabic → Pashto ک/ګ/ی, Persian ی vs Pashto ې/ۍ/ئ, Urdu ے/ہ/ھ leaking into Pashto output, and zero-width-joiner and ZWNJ cleanup. Whisper's BasicTextNormalizer is not Pashto-aware.
- Given Urdu-transfer failure and the absence of code-switching benchmarks, Pashto–Urdu–English code-switching in a single model is an open research problem. A practical approach is per-utterance language ID (Omnilingual, MMS-LID or Whisper LID) routing to Urdu, Pashto and English models. This is not verified for Pashto.
- Spontaneous and conversational speech is roughly 2× worse than read speech, so expect live-caption WER closer to 35–45% than 15–25%.

### Gaps
- No published Pashto–Urdu or Pashto–English code-switching ASR dataset or paper was found.
- No dialect-stratified (Yusufzai vs Kandahari vs Central) WER results were found anywhere.
- Older IEEE and Springer Pashto ASR papers from 2020–2024 (HMM/DNN on small corpora) were not enumerated beyond the UET and JEAS items.
- The 2604.04598 discussion of letter-confusion classes was not read in full.

---

## 4. Commercial and cloud APIs with Pashto (streaming?)

### Takeaway
As of Oct 2026, the most relevant development is that **Deepgram Nova-3 added Pashto (`ps`, `ps-AF`) for batch and streaming on 27 Aug 2026**, per Deepgram's changelog (search snippet). HumSukhan already uses Deepgram Nova-3 streaming, so this is the lowest-friction cloud path.

Other providers:
- **Azure** lists ps-AF for speech-to-text.
- **AWS Transcribe** lists ps-AF as batch-only on its main docs.
- **ElevenLabs Scribe** and **AssemblyAI Universal-3.5 Pro** advertise Pashto.
- **Google** Chirp 3 Pashto and **Soniox** Pashto support could not be confirmed.
- **Speechmatics**: no evidence of Pashto.

### Cited Findings
- **Deepgram.** The changelog of 2026-08-27 is titled "Nova-3 Adds Assamese, Mongolian, and Pashto…". It reads "Pashto (ps, ps-AF) — available for batch and streaming", with no API changes needed and self-hosted models available on request. — [Deepgram changelog 2026-08-27 (search snippet)](https://developers.deepgram.com/changelog/2026/8/27)
- **ElevenLabs Scribe** (vendor-reported): Pashto is supported among 99 languages. Vendor-reported WERs are 37.8% on FLEURS and 37.1% on Common Voice. Its FLEURS comparison table lists Gemini Flash 2 at 42.9%, Whisper large-v3 at 94.3% and Deepgram Nova-2 at 100.0%; that comparison predates the Nova-3 Pashto launch. Whether Scribe's realtime variant supports Pashto was not confirmed. — [ElevenLabs Pashto page (search snippet)](https://elevenlabs.io/speech-to-text/pashto)
- **AssemblyAI** has a Pashto language page advertising Universal-3.5 Pro with automatic language detection, with tabs for "Async" and "Realtime". It gives no accuracy figures, and realtime Pashto is not explicitly confirmed. — [AssemblyAI Pashto page (search snippet)](https://www.assemblyai.com/languages/pashto)
- **Azure AI Speech.** The language support page lists ps-AF, Pashto (Afghanistan), for speech-to-text, with custom speech "Plain text" support. Real-time support for ps-AF is not explicitly confirmed in the snippet. — [Microsoft Learn language support (search snippet)](https://learn.microsoft.com/en-nz/azure/cognitive-services/speech-service/supported-languages)
- **AWS Transcribe.** The main English docs list Pashto (ps-AF) as **batch only**, with streaming "no". The China-region docs show "batch, streaming*" with an unexplained asterisk, which conflicts. — [AWS supported languages (search snippet)](https://docs.aws.amazon.com/transcribe/latest/dg/supported-languages.html); [AWS China docs (search snippet)](https://docs.amazonaws.cn/transcribe/latest/dg/supported-languages.html)
- **Google Cloud STT.** Chirp 3 (`chirp_3`, V2 API) supports StreamingRecognize, Recognize and BatchRecognize. Chirp 2's streaming list has about 16 languages, none of them Pashto. A ps-AF row could not be confirmed for any model because the docs were blocked. — [Chirp 3 docs (snippet)](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3); [Chirp 2 docs (snippet)](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-2)
- **Soniox** advertises real-time STT in 60+ languages. Searches surfaced only Persian pages and no Pashto page. — [Soniox (search snippet)](https://soniox.com/products/speech-recognition/)
- **Speechmatics**: no Pashto-specific information was found. — [search, 2026-10-26](https://vantaige.io/fr/ai-tool/speechmatics)

### Inferences
- HumSukhan could add Pashto cloud captions by passing `language=ps` (or `ps-AF`) to its existing Deepgram Nova-3 streaming integration. The accuracy of Nova-3 Pashto on Pakistani speech is unknown and should be benchmarked before launch on CV Pashto test data plus a small Peshawar/Quetta recording set.
- All cloud providers label Pashto as "Afghanistan" (ps-AF). None advertises a ps-PK locale, so Pakistani-dialect accuracy is untested.

### Gaps
- No independent WER for Deepgram Nova-3 Pashto, AssemblyAI, Azure ps-AF or Google.
- Google ps-AF support status and model list were not verifiable.
- Soniox language list was not verifiable.
- Pricing per provider for Pashto was not retrieved.
- Whether Deepgram's multilingual "multi" code-switching mode includes Pashto (for Pashto–Urdu–English) is unknown.

---

## 5. Which resource best fits Pakistani (not only Afghan) Pashto? Dialect coverage evidence

### Takeaway
No resource offers *verified, labelled* Pakistani-dialect coverage with evaluation. The strongest indirect evidence of Pakistani Pashto comes from four sources:
1. **Meta Omnilingual**, which has separate pbu (Northern/Yusufzai), pst (Central) and pbt (Southern) training and test data, with corpus collection photographed in Pakistan. It is Apache-2.0 and CC-BY-4.0.
2. **IARPA Babel Pashto**, which spans four dialect regions in Afghanistan and Pakistan, is telephone and conversational, and is under LDC licence.
3. **Common Voice**, which has mixed Northern and Southern contributors but inconsistent accent labels.
4. **Katib-ASR**, a University of Peshawar model claiming Afghan and Pakistani dialects, with no licence.

FLEURS is ps_af (Afghanistan) only.

### Cited Findings
- Omnilingual reports separate per-variety results: pbu_Arab CER 7.5 (5.2 h), pst_Arab CER 3.5 (5.3 h), pbt_Arab CER 8.8 (5.6 h) and pus_Arab CER 12.6 (28.7 h), from the 7B LLM model. — [Omnilingual results CSV](https://raw.githubusercontent.com/facebookresearch/omnilingual-asr/main/per_language_results_table_7B_llm_asr.csv)
- Omnilingual corpus creation photos are from Pakistan and Liberia. — [sherpa-onnx Omnilingual card](https://huggingface.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12)
- Babel Pashto covers four dialect regions of Afghanistan and Pakistan. — [LDC (snippet)](https://catalog.ldc.upenn.edu/LDC2016S09)
- Common Voice Pashto "captures both groups [Southern Kandahari/Quetta; Northern Yusufzai/Peshawar] … though the distribution is uncontrolled and unbalanced", and speaker metadata is "inconsistently labelled". — [arXiv 2604.06507](https://huggingface.co/papers/2604.06507)
- The CV18 contributor surge coincided with a VOA Pashto broadcast campaign. — [arXiv 2603.27021 (snippet)](https://arxiv.org/pdf/2603.27021)
- Katib-ASR was built by Muhammad Uzair at the University of Peshawar for Pakistani medical-clinic voice agents. It claims "Afghan & Pakistani dialects" and reports WER 28.23% on its own test set. It has no licence. — [Katib-ASR card](https://huggingface.co/uzair0/Katib-ASR)
- FLEURS Pashto is configured as `ps_af` (Afghanistan). — [google/fleurs card](https://huggingface.co/datasets/google/fleurs)
- `junaid008/qehwa-pashto-llm` is a text LLM tagged "peshawari, pakistani-pashto". It is not ASR, but it could be useful for LM rescoring or post-correction. Apache-2.0, 25 likes. — HF MCP search

### Inferences
- ISO 639-3 mapping, from standard knowledge and not verified in this session:
  - **pbu** = Northern Pashto, the Yusufzai/Peshawari variety dominant in Khyber Pakhtunkhwa.
  - **pbt** = Southern Pashto, Kandahari, spoken in Balochistan around Quetta and Zhob.
  - **pst** = Central Pashto, Wazirwola and other varieties of the former FATA and southern KP.

  On that basis, Omnilingual's pbu and pbt adapters are the closest open, commercially licensed match to HumSukhan's KP and Balochistan targets. The pbu and pst corpus splits are good candidates for a Pakistani-dialect dev set.
- **Recommended evaluation set** for "Pakistani Pashto":
  - Omnilingual pbu, pbt and pst test splits (CC-BY-4.0)
  - CV accent-filtered clips
  - a small, consented in-house Peshawar and Quetta recording set, which is needed because no labelled dialect benchmark exists
- **Recommended training mix** for an on-device model:
  - CV validated (CC0)
  - Spontaneous Speech Pashto (CC0)
  - FLEURS and Omnilingual pbu, pbt and pst (CC-BY-4.0)

  Avoid NC, YouTube and Babel sources unless licences are cleared.

### Gaps
- No published dialect-stratified WER exists for any model.
- Common Voice Pashto accent tag distribution (Pakistan vs Afghanistan share) could not be retrieved.
- Omnilingual corpus Pashto hours per split and speaker origin were not retrieved; only parquet sizes and training-hour totals were.
- Whether Omnilingual's "pus_Arab" (28.7 h) includes Common Voice or FLEURS is unknown.
