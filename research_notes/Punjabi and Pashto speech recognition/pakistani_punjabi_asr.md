# Pakistani Punjabi (pnb, Shahmukhi) and Related Varieties: ASR Models, Datasets, Script Conversion and APIs (as of 26 Oct 2026)

Method note: Sources were checked on 26 Oct 2026. I used the Hugging Face MCP tools (`hf_fs` search/cat/ls/find, `hub_repo_details` overview and preview), WebSearch snippets, and raw.githubusercontent.com through curl for the Omnilingual ASR repository (CSV and lang_ids.py downloaded and grepped). WebFetch failed with DNS errors on every host I tried (arxiv.org, huggingface.co, deepgram.com, elevenlabs.io, soniox.com). The proxy also blocked aclanthology.org, arxiv.org and huggingface.co for curl. So any figures from ACL or vendor pages come from search snippets, not full-text reads, and are marked as such. "Author-reported" means the model or dataset owner published the number. Unless stated otherwise, I reproduced nothing.

## Models: Whisper, MMS, Omnilingual ASR, SeamlessM4T, AI4Bharat, Google/Azure, and Hugging Face Shahmukhi fine-tunes

### Takeaway
Meta Omnilingual ASR (Nov 2025, Apache-2.0) is the only large open model family that explicitly includes `pnb_Arab`, `skr_Arab`, `hno_Arab` and `phr_Arab`. It also ships as sherpa-onnx CTC exports, which is HumSukhan's existing on-device stack. Its author-reported CER for pnb_Arab is poor, though: 31.2 with the 7B LLM-ASR model and 11.9 training hours, against 4.3 for pan_Guru. Every other mainstream model (Whisper `pa`, MMS `pan`, SeamlessM4T `pa`, IndicConformer `pa`, Chirp 3 `pa-Guru-IN`) targets Gurmukhi/Indian Punjabi. Shahmukhi-specific Hugging Face fine-tunes are tiny student or hobby projects with little or no data documentation.

### Cited Findings

**OpenAI Whisper (`pa` token)**
- Whisper's `pa` language token corresponds to Eastern Punjabi in Gurmukhi script. A Shahmukhi fine-tune therefore forces the Urdu token (`ur`) instead: "the model uses the Urdu language token (`ur`) internally rather than the Whisper `pa` token, which corresponds to Eastern Punjabi in Gurmukhi script." — [Ghost3454/translynx-pakistani-punjabi-whisper-small model card (HF MCP cat)](https://huggingface.co/Ghost3454/translynx-pakistani-punjabi-whisper-small)
- CLE/UET Lahore authors (Sehar, Khalid, Adeeba, Hussain) report that Whisper "defaulted to Gurmukhi" on Pakistani Punjabi even though Shahmukhi has the larger user base. Their in-house test set came from Bhulekha (Bulekha) TV vlogs (Majhi dialect, Shahmukhi annotation), with 15 h for fine-tuning and 4.2 h for evaluation. Reported results: zero-shot Whisper-large WER about 54.73%, small and medium often above 90%, and fine-tuned Whisper-small WER falling from about 45.18% (1 h) to about 38.01% (15 h). The dataset does not appear to be public. — [ACL Anthology 2025.chipsal-1.20 (CHiPSAL @ COLING 2025, pp. 202–207)](https://aclanthology.org/2025.chipsal-1.20/); numbers via [Lacuna summary](https://lacuna.tiptreesystems.com/work/benchmarking-whisper-for-low-resource-speech-recognition-an-n-shot-evaluation-on/wrk_ade4c16900ef44b62683d77330d9926a) and search snippets of the [PDF](https://aclanthology.org/2025.chipsal-1.20.pdf). The PDF was not readable here, so check the exact figures before citing.
- Whisper-large-v3 zero-shot on FLEURS Punjabi (pa_in, Gurmukhi) has a CER of 41.24 (BuzzASR authors' measurement). It is 53.91 CER on Common Voice 25 and 42.33 combined. The BuzzASR full fine-tune of large-v3 (MIT licence; FLEURS + CV25 + Goldfish text) reports FLEURS CER 10.86 / WER 30.59 and CV25 CER 0.39 / WER 1.49. — [BuzzASR/punjabi model card (HF MCP)](https://huggingface.co/BuzzASR/punjabi); paper [arXiv:2609.09554, Findings of EMNLP 2026](https://arxiv.org/abs/2609.09554)
- I could not retrieve the official Whisper paper's per-language FLEURS WER for Punjabi, because arxiv.org was blocked. See Gaps.

**Meta MMS (`facebook/mms-1b-all`)**
- Licence: CC-BY-NC-4.0, which bars commercial use. The model is 1B parameters with adapters for 1,162 languages. — [facebook/mms-1b-all README (HF MCP)](https://huggingface.co/facebook/mms-1b-all)
- An adapter file listing (HF MCP `find adapter.p*`) shows `adapter.pan.safetensors` (Punjabi) and nothing between `adapter.pmf` and `adapter.pny`. So **there is no `pnb` adapter**, and a `find` for `adapter.skr*` and `adapter.hno*` returned nothing. MMS-1b-all has no Shahmukhi Western Punjabi, Saraiki or Hindko adapter. — [facebook/mms-1b-all files](https://huggingface.co/facebook/mms-1b-all/tree/main)
- In a Pashto benchmark, MMS-1B, SeamlessM4T and OmniASR each kept over 93% target-script fidelity, while no Whisper model produced Pashto script in more than 0.8% of utterances. This is an analogous "script failure" result for a Pakistani Perso-Arabic language. — [arXiv:2604.04598 abstract (HF papers)](https://huggingface.co/papers/2604.04598)

**Meta Omnilingual ASR (released Nov 2025)**
- Code and models are Apache-2.0. The corpus is CC-BY-4.0. — [omnilingual-asr README (raw GitHub)](https://github.com/facebookresearch/omnilingual-asr)
- `src/omnilingual_asr/models/wav2vec2_llama/lang_ids.py` contains `pnb_Arab`, `pan_Guru`, `skr_Arab`, `hno_Arab`, `phr_Arab`, `urd_Arab`, `urd_Latn`, `urd_Deva` and `snd_Arab` (grepped from the raw file). There is no `pnb_Guru` and no `pan_Arab`. — [lang_ids.py](https://github.com/facebookresearch/omnilingual-asr/blob/main/src/omnilingual_asr/models/wav2vec2_llama/lang_ids.py)
- Author-reported per-language CER for the 7B LLM-ASR model, from `per_language_results_table_7B_llm_asr.csv` (training hours, CER): — [per-language CSV](https://github.com/facebookresearch/omnilingual-asr/blob/main/per_language_results_table_7B_llm_asr.csv)
  - pnb_Arab (Western Punjabi, Shahmukhi): **11.9 h, CER 31.2**
  - pan_Guru (Eastern Punjabi, Gurmukhi): 207.5 h, CER 4.3
  - skr_Arab (Saraiki): 1.5 h, CER 17.0
  - hno_Arab (Hindko): 12.2 h, CER 17.1
  - phr_Arab (Pahari-Pothwari): 17.4 h, CER 23.0
  - urd_Arab: 237.5 h, CER 3.5; urd_Latn (Roman Urdu): 20.3 h, CER 0.8; snd_Arab: 12.6 h, CER 6.6
  - For comparison with other Pakistani languages: pbt_Arab 5.6 h / 8.8; pst_Arab 5.3 h / 3.5; khw_Arab (Khowar) 13.0 h / 4.5; scl_Arab (Shina) 6.9 h / 14.9; bgp_Arab (Balochi) 8.4 h / 24.5
- Headline claim: the 7B LLM-ASR model has CER below 10 for 78% of its 1,600+ languages. — [omnilingual-asr README](https://github.com/facebookresearch/omnilingual-asr)
- Ready-made sherpa-onnx exports exist on the Hub:
  - `csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12`: `model.int8.onnx` is 365,352,120 bytes, with `tokens.txt` and an Apache-2.0 LICENSE.
  - 1B CTC variants, plus "v2-2026-02-05" re-exports under `csukuangfj2/`.
  These are CTC (non-autoregressive, offline) models. The per-language CSV covers the 7B LLM-ASR model, **not** the 300M/1B CTC models, so CTC CER for pnb is unknown. — [HF MCP search "omnilingual"](https://huggingface.co/csukuangfj/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12)

**SeamlessM4T v2**
- `facebook/seamless-m4t-v2-large` is 2.3B parameters, licensed CC-BY-NC-4.0. Its language tags include `pa`, `ur` and `sd`, with no `pnb` and no `skr`. — [HF repo details](https://huggingface.co/facebook/seamless-m4t-v2-large)

**AI4Bharat (Gurmukhi only)**
- `ai4bharat/indicconformer_stt_pa_hybrid_ctc_rnnt_large` (NeMo hybrid CTC/RNNT, language `pa`) is licensed MIT and gated. — [HF repo details](https://huggingface.co/ai4bharat/indicconformer_stt_pa_hybrid_ctc_rnnt_large)
- `ai4bharat/indic-conformer-600m-multilingual` (ONNX, custom code, 22 Indian languages) is licensed MIT, gated, with 1.6M downloads. — [HF repo details](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual)
- A community ONNX conversion, `AI-pro11/indicconformer-punjabi-ctc-onnx` (Sep 2026), exists but has no README. — [HF search](https://huggingface.co/AI-pro11/indicconformer-punjabi-ctc-onnx)
- I found no AI4Bharat IndicWhisper/Vistaar Punjabi checkpoint by searching the HF org. A `manish-iisc/vistaar` repo exists, but its Punjabi coverage is unverified. — [HF search "vistaar"](https://huggingface.co/manish-iisc/vistaar)

**Google, Azure and others (Gurmukhi locales)**
- Google Cloud Chirp 3 lists "Punjabi (Gurmukhi India) `pa-Guru-IN`" as **Preview**, not GA. The search snippets showed no Shahmukhi or `pnb` locale. — [Chirp 3 docs (search snippet)](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3)
- Azure Speech recognises the locale `pa-IN`, seen through the Pipecat Azure STT integration list. I could not reach the official Microsoft page. — [Pipecat Azure STT docs](https://docs.pipecat.ai/server/services/stt/azure)

**Hugging Face Shahmukhi/pnb ASR fine-tunes (exhaustive Hub search: "shahmukhi", "pnb", "western punjabi", "punjabi pakistan", "saraiki", "hindko", "pothwari", tag `language:pnb`)**
- `Ghost3454/translynx-pakistani-punjabi-whisper-small` (Aug 2026, Apache-2.0): whisper-small fully fine-tuned, Shahmukhi output via the `ur` token. Author-reported WER is 7.07% on validation (seen speakers) and **11.50% on one unseen speaker**, against a baseline of about 70%. The training data is only 3,500 recordings: 7 speakers each reading the same 500 sentences, so the result is closed-vocabulary and not representative of spontaneous speech. — [model card](https://huggingface.co/Ghost3454/translynx-pakistani-punjabi-whisper-small)
- `sny2ksa/whisper-punjabi-shahmukhi`, `-v1`, `-v3` and `-large` (Aug 2026, Apache-2.0): all are whisper-small fine-tunes. The "-large" repo is also based on whisper-small despite its name. The cards are auto-generated, with "None dataset", no results and no data description. — [sny2ksa/whisper-punjabi-shahmukhi-large](https://huggingface.co/sny2ksa/whisper-punjabi-shahmukhi-large), [sny2ksa/whisper-punjabi-shahmukhi](https://huggingface.co/sny2ksa/whisper-punjabi-shahmukhi)
- `kingabzpro/wav2vec2-large-xlsr-53-punjabi` (Apache-2.0, 381K downloads) is **Gurmukhi**. It was trained on Common Voice 8 pa-IN and reports test WER 36.02 / CER 12.81 with an LM. — [model card](https://huggingface.co/kingabzpro/wav2vec2-large-xlsr-53-punjabi)
- Saraiki: `themohal/saraiki-whisper-medium` appeared in search results (snippet: WER 19.41, CER 5.64, "unknown dataset"), but the HF MCP returned "Repository not found" on 26 Oct 2026, so it has been deleted or made private. The same author (`themohal`) has many gated Saraiki text and TTS repos (e.g. `saraiki-vits-tts`, `lfm2.5-audio-saraiki` with an MIT licence and an empty card). None of them is a documented Saraiki ASR model. — [web search snippet](https://huggingface.co/themohal/saraiki-whisper-medium); [HF search "saraiki"](https://huggingface.co/themohal)
- No Hindko or Pothwari ASR model exists on the Hub. Search returned only a Hindko tokenizer, OCR and a chatbot. — [HF search "hindko"](https://huggingface.co/junaid008/hindko-tokenizer)

### Inferences
- For an offline, commercially licensed Shahmukhi baseline today, Omnilingual ASR CTC via sherpa-onnx (Apache-2.0) is the only drop-in option. Expect quality well below the Urdu models: if the 7B model has CER 31.2 on pnb, the 300M CTC model is likely worse. It is also non-streaming, so it would need VAD-chunked pseudo-streaming, as HumSukhan presumably already does for its offline models.
- MMS and SeamlessM4T are both CC-BY-NC, so they cannot be used commercially, and neither has pnb anyway.
- The high pnb CER relative to hno, skr and phr probably reflects orthographic inconsistency in pnb transcripts rather than acoustic difficulty. See the Datasets section on lexical mixing in the Omnilingual pnb transcripts. This is my inference, not an author claim.
- The most practical route is fine-tuning: Whisper-small/turbo with the `ur` token, or an Omnilingual CTC/w2v-BERT model, on a commercially licensed Shahmukhi corpus. The TransLynx and CLE results show that 15 h gets WER to roughly 38% on spontaneous broadcast speech, so far more data is needed.

### Gaps
- I could not read the official Whisper paper FLEURS WER table for Punjabi, because arXiv was blocked.
- I found no published CER for the Omnilingual 300M/1B CTC models on pnb_Arab.
- I could not confirm the MMS `pan` vocabulary script directly (vocab.json is 1.3 MB and was not parsed). It is presumed Gurmukhi from FLEURS/CV pa-IN.
- I could not confirm the Azure pa-IN streaming status or AWS Transcribe pa-IN from official pages.

## Datasets: speech corpora (Indian Punjabi, Shahmukhi, Saraiki, Hindko, Pothwari) and Shahmukhi text corpora

### Takeaway
Open Shahmukhi speech data is tiny. The largest openly licensed source I found is the Omnilingual ASR Corpus `pnb_Arab` subset (CC-BY-4.0, 420 train rows of about 60 s each, roughly 7 h train, ~1.26 GB parquet including dev/test). Common Voice has no pnb locale, but it does have Saraiki (6.75 h), Pahari-Pothwari (14.3 h validated) and Northern Hindko (10.47 h), all CC0. Indian Punjabi (Gurmukhi) data is much larger: IndicVoices, Kathbath, Shrutilipi (94 h), FLEURS and CV pa-IN. Shahmukhi text is modest: Wikipedia pnb has 72.3K articles, FineWeb-2 pnb_Arab has 20.8K documents, and there is a 6.3M-sentence transliteration corpus.

### Cited Findings

**Shahmukhi / Pakistani speech**
- **Omnilingual ASR Corpus, `pnb_Arab`** (CC-BY-4.0). Files: train 464 MB + 461 MB, dev 150 MB, test 181 MB. The train split has 420 rows. The rows are spontaneous answers to prompts, with durations of about 58–72 s in the preview and tags such as `<hesitation>` and `<unintelligible>`. Glottocode west2386, script Arab. — [HF MCP ls + dataset_preview](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus)
- **Omnilingual ASR Corpus, `hno_Arab`** (Hindko): train 380 MB + 380 MB, dev 259 MB, test 331 MB. The corpus also has `phr_Arab` (Pothwari) and `pst_Arab`, `pbt_Arab` and `pbu_Arab` (Pashto). It has no `skr_Arab` folder, so Saraiki training hours came from elsewhere. — [HF MCP ls data/](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus/tree/main/data)
- Preview transcripts of `pnb_Arab` mix in Eastern/Hindi-influenced vocabulary written in Shahmukhi, for example مکھ (mukh, "main"), پرکار (prakar, "type"), رسوئیاں (rasoi, "kitchens") and بناؤندا. They also mix Urdu spellings such as سکتے ہیں. — [HF MCP dataset_preview pnb_Arab/train](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus)
- **Common Voice Saraiki (skr)**, v24.0: 5,837 clips, 6.75 h total, 4.33 h validated, 60 speakers, CC0-1.0, released 5 Dec 2025. Saraiki was added in CV 11. — [Mozilla Data Collective, CV 24.0 Saraiki](https://datacollective.mozillafoundation.org/datasets/cmj8u3pta00phnxxbsw61jb2r)
- **Common Voice Pahari-Pothwari (phr)**, v24.0: 14.3 h validated, 63 speakers. There is also a v25.0 listing. — [Data Collective CV 24.0 Pahari-Pothwari](https://datacollective.mozillafoundation.org/datasets/cmj8u3pmm00l5nxxbcnnigee7); [CV 25.0 Pahari-Pothwari](https://datacollective.mozillafoundation.org/datasets/cmn2ch9gl01c3o107pqn1noey)
- **Common Voice Northern Hindko**, v25.0 (22 Mar 2026): 9,407 clips, 10.47 h, 10.15 h validated, 36 speakers, a 2,349-sentence corpus, CC0-1.0. The datasheet forbids re-hosting and speaker re-identification. — [Data Collective CV 25.0 Northern Hindko](https://datacollective.mozillafoundation.org/datasets/cmn2alr7p018jo1071gyxr951)
- **Common Voice has no `pnb` (Western Punjabi / Shahmukhi) locale** that I could find. Searches returned only pa-IN Punjabi. — [web search, Data Collective listings](https://datacollective.mozillafoundation.org/datasets?page=4)
- **MirasAI "Saraiki 10 Hours TTS Dataset"** (release 1 Apr 2026, CC-BY-NC-SA-4.0, so non-commercial). — [Data Collective listing](https://datacollective.mozillafoundation.org/datasets/cmnggqr8z0082mh07vbsbm6t5)
- **Appen pa-PK** "Panjabi (Pakistan)" conversational telephony corpus: about 20 h, collected 2017, fully transcribed with a pronunciation lexicon, licence commercial. — [Appen catalogue PAP_ASR001](https://www.appen.com/data-catalog/audio-catalogue/pap-asr001)
- **CLE/UET Lahore**: a district-names speech corpus for Urdu ASR covers 6 accents (Urdu, Punjabi, Pashto, Sindhi, Saraiki, Balochi) at 8 kHz, with 139 district names and 34 other words. This is Urdu-content speech, not a Punjabi corpus. The CLE in-house Bhulekha-vlog Shahmukhi set (15 h + 4.2 h) is described in the CHiPSAL paper but is not public. — [CLE presentation PDF](https://www.cle.org.pk/research/news10/presentation/DISTRICT%20NAMES%20SPEECH%20CORPUS%20FOR%20URDU%20ASR1.pdf); [ACL 2025.chipsal-1.20](https://aclanthology.org/2025.chipsal-1.20/)
- **Namal University CDC** (Mianwali) project page: "Punjabi Speech Recognition" for Pakistani Punjabi in Shahmukhi, with a 50k+ word dictionary and 10 speakers. It is an older project page and the data is not released. — [Namal CDC project](https://cdc.namal.edu.pk/projectDetails/punjabi-speech-recognition)
- **TransLynx** private read-speech set: 7 speakers × 500 Shahmukhi sentences, 3,500 recordings. It is not released. — [model card](https://huggingface.co/Ghost3454/translynx-pakistani-punjabi-whisper-small)
- I found no ITU, PUCIT, NUST or LUMS CSaLT Shahmukhi speech corpus. LUMS has a Language Engineering Lab page, but nothing Punjabi-speech-specific turned up. — [web search](https://web.lums.edu.pk/~ncbc/?p=65)

**Indian Punjabi (Gurmukhi) speech**
- **FLEURS** includes `pan` (pa_in), CC-BY-4.0, with about 10 h of train supervision per language. — [google/fleurs HF details](https://huggingface.co/datasets/google/fleurs)
- **Common Voice pa-IN**: v25.0 is listed on Data Collective (CC0-1.0, MP3), but I could not retrieve its hours. — [web search snippet](https://datacollective.mozillafoundation.org/datasets?q=Thai)
- **IndicVoices** (CC-BY-4.0, gated): 23.7K h total, 11.2K h transcribed as of 23 Dec 2025, 22 languages, 51K speakers. I could not see the per-language Punjabi hours because the repo is gated. — [ai4bharat/IndicVoices HF details](https://huggingface.co/datasets/ai4bharat/IndicVoices)
- **Kathbath** (CC-BY-4.0, gated): 1,684 h across 12 languages including Punjabi. — [ai4bharat/Kathbath HF details](https://huggingface.co/datasets/ai4bharat/Kathbath)
- **Shrutilipi** (All India Radio news): Punjabi 94 h, out of 6,457 h across 12 languages. — [AIKosh Shrutilipi listing (search snippet)](https://aikosh.indiaai.gov.in/home/datasets/details/shrutilipi.html)
- **Project Vaani** (IISc/ARTPARK, Google-funded): about 31,270 h of audio and about 2,067 h transcribed across 109 languages (arXiv v2, Mar 2026). The licence is CC-BY-4.0. It is India-only, with no Pakistan data. — [arXiv:2603.28714](https://arxiv.org/html/2603.28714v2); [vaani.iisc.ac.in](https://vaani.iisc.ac.in)
- **SpeechDataAI Punjabi Conversational**: 500 h, recorded in India, 50 speakers, commercial licence at $65/h. Only the card is hosted on HF. — [HF dataset card](https://huggingface.co/datasets/SpeechDataAI/punjabi-conversational-speech)
- Other HF Gurmukhi ASR sets: `kdcyberdude/Punjabi_ASR_datasets` and `aaparajit02/punjabi-asr`. Their licences were not checked. — [HF search](https://huggingface.co/datasets/kdcyberdude/Punjabi_ASR_datasets)

**Shahmukhi text (for LM, rescoring and tokenizers)**
- **Wikipedia pnb** (20231101 dump): 72.3K articles. — [wikimedia/wikipedia preview](https://huggingface.co/datasets/wikimedia/wikipedia)
- **FineWeb-2 `pnb_Arab`**: 20.8K train documents. The first sample is a 2013 pnb.wikipedia crawl, which suggests heavy Wikipedia overlap. — [HuggingFaceFW/fineweb-2 preview](https://huggingface.co/datasets/HuggingFaceFW/fineweb-2)
- The `language:pnb` tag also covers OSCAR, CulturaX, Glot500, GlotCC-V1 and `espnet/mms_ulab_v2` (MMS unlabeled audio). I did not check sizes or licences. — [HF search tag language:pnb](https://huggingface.co/datasets?language=language:pnb)
- **Goldfish `pnb_arab` LMs** at 5 MB/10 MB/100 MB/full, indicating roughly ≥100 MB of pnb text was available to their authors. — [goldfish-models/pnb_arab_full](https://huggingface.co/goldfish-models/pnb_arab_full)
- **ShahiEmotion** (MeLLM 2026): 30,379 Shahmukhi sentences. Shahmukhi NER corpus: 318,275 tokens. — [ACL 2026.mellm-1.20](https://aclanthology.org/2026.mellm-1.20/); [ResearchGate NER](https://www.researchgate.net/publication/339228622_Named_Entity_Recognition_and_Classification_for_Punjabi_Shahmukhi)

### Inferences
- About 7–12 h of open pnb audio is far too little for robust ASR. Commercially usable data must come from new collection (CC0 Common Voice pnb locale creation, or paid collection) or from licensing (Appen pa-PK 20 h; the CLE data if negotiable).
- Saraiki, Hindko and Pothwari each have roughly 5–15 h of CC0 data in Common Voice. That is enough to fine-tune an Omnilingual CTC model into a basic recogniser, but not enough for production quality.
- The Omnilingual pnb transcripts are written by multiple transcribers with East Punjabi/Hindi-influenced vocabulary and Urdu spellings. A Shahmukhi orthography normaliser will be needed for training and evaluation.

### Gaps
- I could not obtain exact Punjabi hours for Common Voice pa-IN (v24/v25), IndicVoices or Kathbath.
- I could not confirm whether pnb exists in the MMS Bible-based labeled data (MMS-lab) or in `espnet/mms_ulab_v2`.
- I could not check the scripts used in Common Voice Saraiki, Hindko or Pothwari. They are presumed Perso-Arabic but unverified.
- I found no Punjabi radio, TV or YouTube Shahmukhi speech dataset with an open licence.

## Script conversion: Gurmukhi↔Shahmukhi transliteration resources, accuracy, and pitfalls

### Takeaway
Gurmukhi→Shahmukhi transliteration is a solved-ish problem at the text level: about 98.6–99.5% word accuracy (author-reported). Shahmukhi→Gurmukhi is harder (BLEU 87.7; 91–97% word accuracy). A pipeline of "Gurmukhi ASR + transliteration" is therefore technically feasible. It would still produce East Punjabi lexicon and spelling, not Lahori Shahmukhi usage, and it compounds errors.

### Cited Findings
- `SLPG/Punjabi_Gurmukhi_to_Shahmukhi_Transliteration` and `SLPG/Punjabi_Shahmukhi_to_Gurmukhi_Transliteration` are fairseq NMT models (Jul 2024). Author-reported Gurmukhi→Shahmukhi results: BLEU 98.1 and word accuracy 99.5%. The reverse direction scores BLEU 87.7. The test set is FLORES-101. The card's "CER 99.1%" is evidently mislabeled. **No licence is declared** on either the models or the corpus. Paper: Ambreen, Abdul Rauf, Abbas Malik, Imran, *Heliyon* 2024 ("under review"). — [model card](https://huggingface.co/SLPG/Punjabi_Gurmukhi_to_Shahmukhi_Transliteration)
- `SLPG/Punjabi_Transliteration_Corpus`: 6.3M parallel Gurmukhi/Shahmukhi sentences, drawn from CCAligned, CCMatrix, TED, QED, OPUS, TICO, Wikimedia, EMILLE, IJCNLP, XLEnt and ParaCrawl. It is tagged `pa`/`pnb` and declares no licence. — [dataset card](https://huggingface.co/datasets/SLPG/Punjabi_Transliteration_Corpus)
- G.S. Lehal (Punjabi University): the Gurmukhi→Shahmukhi system has more than 98.6% word accuracy, and Shahmukhi→Gurmukhi about 97%, which he calls "more complex and challenging". Prior systems for comparison: Saini et al. 2008 reached 91.37% Shahmukhi→Gurmukhi. Malik 2006 reached 98%, but only with fully diacritised input, which is rare in practice. — [learnpunjabi.org Gurmukhi→Shahmukhi PDF](https://learnpunjabi.org/pdf/GurmukhiToShahmukhiTransliteration.pdf); [COLING 2012 C12-3039](https://aclweb.org/anthology/C12-3039.pdf); [COLING 2012 poster](https://learnpunjabi.org/pdf/COLING2012POSTERS062.pdf)
- Google's XTREME-UP benchmark includes a sentence-level Punjabi Shahmukhi↔Gurmukhi transliteration task (`pa_Arab_Guru`) with ByT5 baselines. I did not retrieve the per-pair scores. — [arXiv:2305.11938](https://arxiv.org/pdf/2305.11938)
- Wikimedia had a grant project for a Gurmukhi–Shahmukhi machine transliteration service for the Wikipedias. — [Meta-Wiki grant page](https://meta.wikimedia.org/wiki/Grants:Project/Developing_and_Enhancing_Gurmukhi-Shahmukhi_Machine_Transliteration_Service_for_Wikipedias)
- Shahmukhi uses the Urdu alphabet plus extra letters for Punjabi phonology, so it cannot simply reuse Urdu output. — [Wikipedia: Shahmukhi](https://en.wikipedia.org/wiki/Shahmukhi)
- For a different pair (Tajik–Farsi), a 2026 benchmark found that subword multilingual models such as mT5-small did worst among neural approaches, and recommended ByT5 or a G2P Transformer. This is indirect evidence for using byte-level transliterators. — [arXiv:2605.02270](https://arxiv.org/pdf/2605.02270)

### Inferences
- The "train on Gurmukhi, then transliterate" route might use IndicConformer-pa (MIT) or BuzzASR-punjabi (MIT) followed by the SLPG G→S model. The licences of the ASR side allow commercial use, but the SLPG transliterator and corpus have **no declared licence**, which blocks commercial use until clarified. Lehal's rule-based system is a possible alternative, with licence unknown.
- Pitfalls, from my own analysis combined with the sources above:
  - Gurmukhi→Shahmukhi has to choose among homophonous Perso-Arabic letters (س/ص/ث, ز/ذ/ض/ظ, ت/ط, ہ/ح) for loanwords. Gurmukhi does not encode the distinction, so the transliterator must learn Urdu-style etymological spelling.
  - Short vowels (zer/zabar/pesh) are normally omitted in Shahmukhi. That is easy in this direction, but Pakistani readers expect specific conventions such as ے vs ی and نوں/دا.
  - The East Punjab lexicon, with Sanskritised and Hindi words (ਪ੍ਰਕਾਰ → پرکار), differs from Lahori/Majhi Pakistani usage, which uses Urdu/Persian loans (قسم). Transliteration preserves the Indian word choice.
  - Gurmukhi ASR models trained on Indian speakers will mis-hear Pakistani accents and Urdu/English code-switches. An Urdu word spoken mid-sentence would be written in Gurmukhi, then transliterated back, possibly with the wrong spelling.
  - Both error sources compound, so CER(final) ≥ CER(ASR) + transliteration error.

### Gaps
- I found no published end-to-end evaluation of "Gurmukhi ASR + G→S transliteration" against native Shahmukhi transcripts.
- I could not retrieve XTREME-UP pa_Arab_Guru scores.
- The SLPG and Lehal licences are unknown.
- I found no open transliterator that handles Saraiki- or Hindko-specific letters (e.g. ٻ ڄ ݙ ڳ).

## Published research 2020–2026 on Shahmukhi / Pakistani Punjabi / Saraiki ASR, and Punjabi–Urdu code-switching

### Takeaway
Peer-reviewed Shahmukhi ASR work is almost nonexistent. The main 2025 paper is CLE's CHiPSAL Whisper benchmark (zero-shot about 55% WER at best; fine-tuned whisper-small about 38%). Meta's Omnilingual ASR paper is the only large-scale source of pnb, skr and hno numbers. I found no Punjabi–Urdu code-switching speech corpus or paper.

### Cited Findings
- CHiPSAL 2025 (CLE, UET Lahore): see the Models section. It found Whisper defaults to Gurmukhi, reported zero-shot large WER of about 54.73% on Pakistani Punjabi broadcast vlogs, and fine-tuned whisper-small to about 38.01% WER with 15 h. — [ACL Anthology 2025.chipsal-1.20](https://aclanthology.org/2025.chipsal-1.20/)
- Omnilingual ASR (Meta FAIR, Nov 2025): the per-language table covers pnb, skr, hno and phr (see above). The README header photographs show corpus collection "in Pakistan and Liberia". — [arXiv:2511.09690](https://arxiv.org/pdf/2511.09690); [README](https://github.com/facebookresearch/omnilingual-asr)
- Pashto benchmark (Rahman, Apr 2026): Whisper produces target-script output in at most 0.8% of utterances, while MMS, Seamless and OmniASR exceed 93%. The paper argues that WER alone hides script failure, a lesson that applies directly to Shahmukhi evaluation. — [arXiv:2604.04598](https://huggingface.co/papers/2604.04598)
- Indian Punjabi ASR: Kumar & Singh (2017) built an HMM system on spontaneous speech. A 2023 *Data in Brief* paper released real and synthetic Punjabi (Gurmukhi) speech datasets, and notes that Shahmukhi is used in Pakistan while Common Voice and Shrutilipi are the main existing sources. — [Springer IJST 2017](https://link.springer.com/article/10.1007/s10772-017-9408-2); [PMC10749247](https://pmc.ncbi.nlm.nih.gov/articles/PMC10749247/)
- Code-switching: the closest work is Urdu–English. UrduSpeech (arXiv May 2026) is a 156 h corpus that includes Urdu-English code-switched speech. An O-COCOSDA 2020 paper adapted a 25 h Urdu corpus for code-switching. A 2021 JLLS paper is a linguistic study of Urdu/Punjabi code-mixing in child speech, not a speech resource. — [arXiv:2605.17846](https://arxiv.org/pdf/2605.17846); [search summary](https://files.eric.ed.gov/fulltext/EJ1313712.pdf)
- "WER We Stand: Benchmarking Urdu ASR Models" (COLING 2025) is relevant for the Urdu side of code-switching. — [ACL 2025.coling-main.397](https://aclanthology.org/2025.coling-main.397.pdf)
- BuzzASR (Findings EMNLP 2026) covers 102 monolingual Whisper fine-tunes, including Punjabi (Gurmukhi) and Urdu, under an MIT licence. — [arXiv:2609.09554 via BuzzASR card](https://huggingface.co/BuzzASR/punjabi)

### Inferences
- HumSukhan would be among the first to deploy Shahmukhi ASR. Its evaluation should report CER and a script-fidelity metric (the share of output in Shahmukhi and not Gurmukhi or Urdu), following the Pashto paper.
- For Punjabi–Urdu–English code-switching, Shahmukhi and Urdu share the alphabet. A single Perso-Arabic output vocabulary with Latin for English, plus Roman-Urdu-aware normalisation, is the natural design. No benchmark exists, so HumSukhan would have to build its own.

### Gaps
- I could not read the CHiPSAL PDF full text to confirm the exact WERs.
- I found no Saraiki- or Hindko-specific peer-reviewed ASR paper.
- I found no Punjabi–Urdu code-switching corpus.

## Commercial and cloud APIs for Pakistani Punjabi (Shahmukhi) speech recognition

### Takeaway
As of October 2026 I found no cloud STT vendor that documents Shahmukhi (pnb / pa-Arab-PK) output. Every vendor exposes Punjabi as `pa` / `pa-IN` / `pa-Guru-IN`, which is Gurmukhi or unspecified. Deepgram Nova-3 (HumSukhan's current cloud engine) added `pa` / `pa-IN` on 5 Aug 2026 for batch and streaming. It needs to be tested for script and Pakistani-accent performance.

### Cited Findings
- **Deepgram**: the Nova-3 monolingual models added Punjabi (`pa`, `pa-IN`) and Nepali, batch and streaming, in the changelog of 5 Aug 2026. — [Deepgram changelog 2026/8/5](https://developers.deepgram.com/changelog/2026/8/5)
- **Google Cloud**: Chirp 3 offers `pa-Guru-IN` in Preview, with no Shahmukhi locale found. — [Chirp 3 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3)
- **Azure**: `pa-IN` is listed in the Pipecat Azure integration. I could not read official docs. — [Pipecat](https://docs.pipecat.ai/server/services/stt/azure)
- **Soniox**: offers Punjabi real-time and async STT. Its app page describes Punjabi as Gurmukhi (ਪੰਜਾਬੀ), and the marketing references speakers in India and Pakistan. Soniox self-reports about 10% WER on Punjabi, against 39.5% for ElevenLabs, on its own test data. — [Soniox Punjabi STT](https://soniox.com/speech-to-text/punjabi); [Soniox vs ElevenLabs](https://soniox.com/compare-stt/soniox-vs-elevenlabs/punjabi) (search snippets; site blocked)
- **ElevenLabs Scribe**: Punjabi is among its 99 languages. The page notes Gurmukhi (India) and Shahmukhi (Pakistan) scripts but does not confirm Shahmukhi output. Its figures conflict: 3.1% FLEURS WER in one place, 11.6% for Scribe v1 FLEURS elsewhere. — [ElevenLabs Punjabi STT](https://elevenlabs.io/speech-to-text/punjabi) (search snippet)
- **AssemblyAI**: Punjabi is supported via its Universal models, with no Shahmukhi statement. — [AssemblyAI Punjabi](https://www.assemblyai.com/languages/punjabi)
- **Sarvam AI**: Saaras v3 supports 22 Indian languages including Punjabi, with WebSocket streaming. It is India- and Gurmukhi-oriented. — [Sarvam STT API](https://www.sarvam.ai/apis/speech-to-text)
- **AWS Transcribe and Speechmatics**: I found no evidence of Punjabi support in search results, and docs.speechmatics.com was blocked by the proxy. — [web search](https://docs.pipecat.ai/server/services/stt/azure)

### Inferences
- Since HumSukhan already uses Deepgram nova-3, the fastest experiment is `language=pa` on Pakistani audio. If the output is Gurmukhi, apply the G→S transliterator server-side, subject to the licence caveats. If instead it writes Urdu-like Arabic script, it needs Shahmukhi normalisation. Either way, accent robustness for Lahori and Saraiki speech is unknown.
- Vendors claiming "Punjabi" without a script specification should be tested with a script-fidelity check, because Whisper-derived systems default to Gurmukhi (CHiPSAL 2025).

### Gaps
- I could not access any vendor docs directly (DNS/proxy blocks), so script output for Deepgram, Soniox, ElevenLabs and AssemblyAI is unverified.
- I found no official Azure or AWS language-table confirmation.
- I found no independent benchmark of any vendor on Pakistani Punjabi.
