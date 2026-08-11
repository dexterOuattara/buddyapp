# BuddyWize Audio-to-Materials Benchmark

**Benchmark date:** 2026-08-11
**Pipeline:** mobile AAC recording → resumable API upload → Cloudflare R2 → Cloudflare Whisper → DeepSeek study-material generation → PostgreSQL → mobile sync

## Executive summary

BuddyWize's audio pipeline is inexpensive in API terms. Under the current Cloudflare prices, a successful first attempt costs approximately **$0.01–$0.02 for 2 minutes**, **$0.03–$0.04 for 30 minutes**, **$0.08–$0.09 for 2 hours**, and **$0.11–$0.12 for 3 hours**.

R2 is not the cost bottleneck. Its Standard free tier includes **10 GB-month of storage, 1 million Class A operations, 10 million Class B operations, and free egress each month**. At the selected 48 kbps capture profile, 10 GB holds approximately **463 hours of audio**.

BuddyWize now records with the conservative speech profile **AAC-LC, 48 kbps, 16 kHz, mono, in an m4a container**. Compared with the measured 129.7 kbps baseline, it should reduce audio size, upload time, and full-file API memory pressure by approximately **62.5%** without changing the upload, R2, playback, or transcription format contract. AI pricing remains duration/token based, so compression does not directly reduce Whisper or DeepSeek cost.

The current technical constraints matter more than storage cost:

- material generation is capped at 60,000 transcript characters, approximately 76–89 minutes of the measured lecture speech;
- long Whisper segments are processed sequentially;
- the API buffers the complete audio in memory before its single R2 `PutObject`;
- DeepSeek requests have a 120-second timeout, while real short-recording generations already took 76–88 seconds;
- an automatic pipeline retry repeats transcription and can multiply time and AI cost.

Recordings up to approximately 30 minutes are a reasonable target for the current implementation. Reliable 2–3-hour support needs resumable pipeline stages and hierarchical material generation.

## Benchmark methodology

Two short lecture recordings were measured with the production providers. No mock speech-to-text, material generator, or object storage provider was used.

| Measurement | Real run A | Real run B |
|---|---:|---:|
| Audio duration | 100 seconds | 79 seconds |
| Audio size | 1,624,033 bytes | 1,279,382 bytes |
| Effective AAC bitrate | 129.7 kbps | 129.6 kbps |
| Stored transcript | 1,125 characters | 987 characters |
| Timed transcript cues | 11 | 11 |
| Whisper processing | about 8 seconds | about 10 seconds |
| DeepSeek generation | about 88 seconds | about 76 seconds |
| Server claim to materials ready | about 97 seconds | about 87 seconds |
| Persisted material payload | about 7.4 KB | about 6.4 KB |

The 30-minute, 2-hour, and 3-hour results in this document are projections based on those real measurements and the current implementation. They are not presented as completed long-duration soak tests.

The measurements above predate the 48 kbps profile and remain the real production-provider baseline. The new profile has been validated on a physical Android 13 device; equivalent iOS validation is still required before treating the profile as cross-platform measured.

## Selected capture profile

| Setting | Selected value |
|---|---:|
| Codec / container | AAC-LC / m4a |
| Bitrate | 48 kbps |
| Sample rate | 16 kHz |
| Channels | 1 (mono) |

Physical Android validation produced a 21.056-second, 129,569-byte m4a file. `ffprobe` reported AAC-LC, exactly 48,000 audio bits/second, 16,000 Hz, and one mono channel. The effective whole-file rate was approximately 49.2 kbps including container overhead.

That same file completed the real production-provider path without mocks: R2 upload, one Cloudflare Whisper segment, a 39-character transcript with one timed cue, DeepSeek material generation, PostgreSQL persistence, and mobile re-sync. Whisper took approximately 4.3 seconds, DeepSeek generation approximately 62.3 seconds, and the durable job took approximately 67.0 seconds from claim to completion. The mobile UI ended at **Matériel d’étude prêt**.

Projected audio footprint at a constant 48 kbps:

| Recording duration | Audio size | 256 KiB mobile chunks | Theoretical upload at 10 Mbps |
|---|---:|---:|---:|
| 2 minutes | 0.72 MB / 0.69 MiB | 3 | 0.6 seconds |
| 30 minutes | 10.8 MB / 10.3 MiB | 42 | 8.6 seconds |
| 2 hours | 43.2 MB / 41.2 MiB | 165 | 34.6 seconds |
| 3 hours | 64.8 MB / 61.8 MiB | 248 | 51.8 seconds |

These are codec-rate projections, not measured file sizes. Container overhead, encoder behavior, and device implementation add small variance. Processing latency after upload and AI API cost are expected to remain approximately the same because both are driven primarily by audio duration and transcript/output tokens.

## Baseline projection assumptions

- Audio bitrate: measured **129.7 kbps AAC**, rounded to 130 kbps.
- Mobile upload: **10 Mbps** stable uplink for the main timing table.
- Mobile upload chunks: **256 KiB**, sent sequentially to the BuddyWize API.
- Whisper slicing: at most **15 minutes or 20 MiB** per provider request.
- Whisper calls: sequential in the current implementation.
- DeepSeek output: an estimated **2,000–4,096 billed output tokens**, including possible reasoning tokens.
- Text token estimate: approximately four transcript characters per input token.
- Healthy queue: processing begins promptly after the upload is finalized.
- Cost: successful first attempt, before any Workers AI included usage or promotional allowance.

Actual results vary with speech density, silence, language, network quality, Cloudflare load, retries, and concurrent jobs.

## Measured-baseline size and processing projection

| Recording duration | Audio size | Mobile API chunks | Whisper calls | Transcript ready after server processing starts | Materials ready after stopping at 10 Mbps | Total from pressing Record |
|---|---:|---:|---:|---:|---:|---:|
| 2 minutes | 1.95 MB / 1.86 MiB | 8 | 1 | 10–16 seconds | 1.5–2.4 minutes | 3.5–4.4 minutes |
| 30 minutes | 29.2 MB / 27.8 MiB | 112 | 2 | 2.4–4 minutes | 4.3–6.8 minutes | 34–37 minutes |
| 2 hours | 116.8 MB / 111.4 MiB | 446 | 8 | 9.6–16 minutes | 13–21 minutes | 2 h 13–21 minutes |
| 3 hours | 175.1 MB / 167.0 MiB | 669 | 12 | 14.4–24 minutes | 19–31 minutes | 3 h 19–31 minutes |

The theoretical network transfer time is:

```text
upload seconds = audio size in MB × 8 ÷ upload speed in Mbps
```

Protocol latency, 256 KiB request overhead, API processing, and the final R2 upload must be added to that theoretical minimum. At 5 Mbps, a long upload can add approximately 2–5 minutes beyond the 10 Mbps projection.

The hundreds of mobile chunk requests are requests to the BuddyWize API, not R2 operations. The current server assembles those chunks in memory and performs one R2 `PutObject` when the upload finishes.

## Transcript projection

The real lecture recordings produced approximately 674–791 transcript characters per audio minute. The word estimates assume approximately 115–135 spoken words per minute.

| Recording duration | Expected transcript characters | Expected spoken words | Approximate plain-text size |
|---|---:|---:|---:|
| 2 minutes | 1,300–1,600 | 230–270 | about 1–2 KB |
| 30 minutes | 20,000–24,000 | 3,450–4,050 | about 20–26 KB |
| 2 hours | 81,000–95,000 | 13,800–16,200 | about 85–105 KB |
| 3 hours | 121,000–142,000 | 20,700–24,300 | about 130–155 KB |

The complete transcript is persisted on its recording row. Timed cues remain attached to that original recording so synchronized playback is not corrupted when chapter materials are consolidated.

## Workers AI cost projection

Cloudflare currently lists:

- [`@cf/openai/whisper-large-v3-turbo`](https://developers.cloudflare.com/workers-ai/models/whisper-large-v3-turbo/) at **$0.00051 per audio minute**;
- [`@cf/deepseek-ai/deepseek-r1-distill-qwen-32b`](https://developers.cloudflare.com/workers-ai/models/deepseek-r1-distill-qwen-32b/) at **$0.50 per million input tokens** and **$4.88 per million output tokens**.

| Recording duration | Whisper | Estimated DeepSeek | Expected AI total |
|---|---:|---:|---:|
| 2 minutes | $0.00102 | $0.010–$0.020 | **$0.011–$0.022** |
| 30 minutes | $0.01530 | $0.013–$0.023 | **$0.028–$0.038** |
| 2 hours | $0.06120 | $0.018–$0.028 | **$0.079–$0.089** |
| 3 hours | $0.09180 | $0.018–$0.028 | **$0.109–$0.120** |

The 2-hour and 3-hour DeepSeek estimates are similar because the current app caps cumulative generation context at 60,000 characters. This lower cost is a side effect of incomplete material coverage, not an optimization to preserve.

The application currently parses the generated response but does not persist provider token usage. Therefore, the DeepSeek range is an engineering estimate; the Cloudflare billing dashboard remains the source of truth. Persisting input tokens, output tokens, provider latency, model, and request ID would make future reports exact.

## Generated material size

The two real runs produced approximately **6.4–7.4 KB** of persisted material content per generation, excluding PostgreSQL row and index overhead.

Observed material structure:

- summary and structured key points;
- 3–5 flashcards;
- exactly 3 exercises;
- exactly 10 quiz questions.

The persisted material payload remains approximately constant as audio duration grows because the requested output schema and maximum output-token budget are fixed. Content coverage and quality, rather than material storage size, are the concern for long recordings.

## R2 free tier and storage projection

[Cloudflare R2 Standard pricing](https://developers.cloudflare.com/r2/pricing/) currently includes each month:

- 10 GB-month of storage;
- 1 million Class A operations;
- 10 million Class B operations;
- free egress.

Gross storage cost beyond included usage is $0.015 per GB-month. The following per-recording amounts show the underlying storage value before account-wide free-tier deductions.

| Recording duration | Gross R2 storage/month at 48 kbps | Approximate recordings within 10 GB |
|---|---:|---:|
| 2 minutes | $0.000011 | 13,800 |
| 30 minutes | $0.000162 | 925 |
| 2 hours | $0.000648 | 231 |
| 3 hours | $0.000972 | 154 |

The free tier is shared across the Cloudflare account and is not granted separately per user. The recording counts also assume the 10 GB is used only for audio.

The normal BuddyWize processing path performs approximately one Class A operation for the audio `PutObject` and one Class B operation when the pipeline reads it. At current volume, storage and operation usage should remain inside the R2 free tier.

The mobile application retains the original local recording after sync, so the system holds one audio copy on the device and one in R2 unless a future retention or cleanup feature removes the local copy.

## Current long-audio limitations

### 1. Material context is incomplete after approximately 76–89 minutes

`MAX_CUMULATIVE_CONTEXT_CHARS` is currently 60,000 characters in `backend/crates/buddywize-ai/src/pipeline.rs`.

For a single oversized recording, the generated material receives only the bounded beginning of that session. The full transcript still exists, but a 2-hour or 3-hour summary, flashcards, exercises, and quiz cannot represent the complete lecture.

### 2. Whisper segments are sequential

`backend/crates/buddywize-ai/src/cloudflare_whisper.rs` slices long audio into at most 15-minute / 20-MiB pieces and processes them in a sequential loop. This is predictable and rate-limit friendly, but its latency grows nearly linearly with recording duration.

### 3. Full audio is buffered in API memory

The current R2 storage backend receives 256 KiB mobile chunks into an in-memory buffer and performs a single `PutObject` at completion. Processing later reads the complete R2 object into memory again.

A 3-hour recording is projected at approximately 61.8 MiB with the 48 kbps profile (the measured 129.7 kbps baseline was approximately 167 MiB). Temporary segment bytes, Base64 encoding, HTTP JSON, and buffer copies can raise peak memory materially above the audio size. Multiple simultaneous long uploads or processing jobs scale that memory requirement linearly.

### 4. DeepSeek is close to its application timeout

The DeepSeek HTTP client has a 120-second timeout. Real generation took 76–88 seconds for short source material. Larger context, provider load, or slower output can exhaust the remaining headroom.

### 5. Retries repeat expensive completed work

Provider timeouts are retryable and the queue allows up to six attempts. A new attempt currently restarts the pipeline from R2 download and Whisper transcription even if the transcript was already saved before the material generator failed.

Consequences for a 3-hour recording:

- each repeated Whisper pass adds approximately $0.0918;
- each pass may add another 14–24 minutes;
- the user can wait much longer even though transcription had already succeeded.

## Recommended production changes for 2–3-hour support

1. Persist pipeline checkpoints and resume from the latest valid artifact. If the transcript exists, retry only material generation.
2. Generate section summaries per 15–30 minutes, then consolidate those section summaries into the chapter pack.
3. Ensure the final pack explicitly covers every section and records its source recording and time range.
4. Replace full-file upload buffering with durable multipart/direct-to-R2 upload or durable temporary storage.
5. Bound per-worker concurrency based on memory, not only job availability.
6. Store provider request ID, model, input/output usage, latency, attempt, and cost estimate for every AI call.
7. Run real 30-minute, 2-hour, and 3-hour soak recordings before declaring those durations supported.
8. Add regression tests proving that the final materials include concepts introduced near both the beginning and end of a long transcript.

## Current support recommendation

| Recording duration | Recommendation |
|---|---|
| Up to 30 minutes | Suitable for the current implementation, subject to normal network/provider variance. |
| 30–90 minutes | Expected to process, but monitor timeout, memory, and context size closely. |
| More than 90 minutes | Full transcript should complete, but generated materials are currently incomplete. Do not advertise as fully supported yet. |
