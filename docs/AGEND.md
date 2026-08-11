# AGEND.md — BuddyWize project notebook

> Required reading before any PR that touches the AI pipeline, storage,
> sync, the status enums, or the boundaries between crates. This is the single
> source of truth for what we built, why we built it, and what must
> not change.
>
> Style: candid, internal, scannable. No fluff. Every claim points at
> `file:line` or a `commit hash` so you can verify in seconds.

---

## 0. Elevator pitch

BuddyWize is an offline-first course companion: students record
lectures on their phone and automatically receive an AI-generated
summary, 3 exercises, and 10 quiz questions per chapter. The mobile
app works without connectivity; audio is uploaded chunk-by-chunk to
Cloudflare R2 when the network is back, then transcribed and
processed by Cloudflare Workers AI (Whisper large-v3-turbo for STT,
DeepSeek-R1-Distill-Qwen-32B for the study pack).

Three user states: **student** (default, 7-day trial then paid),
**admin** (synthetic unlimited entitlement, moderation tools), and
**mock** (deterministic offline template used for dev only).

Production rig: Rust API on Axum, Flutter mobile with drift, Svelte 5
admin SPA, Postgres 16, Cloudflare R2, Cloudflare Workers AI. Single
git repo, modular monolith. Target device right now: a Xiaomi Redmi
Note 11 Pro.

---

## 1. Business model

### 1.1 Target user

A student recording lectures (in class or while reviewing material).
Not a teacher platform, not a content library — a personal study
companion.

### 1.2 Plans

The `subscriptions.plan` enum accepts three values:

- `trial` — 7-day free trial, started automatically on registration
  (`auth/handlers.rs:138-141`). Full access.
- `monthly` — paid, recurring. Price not yet set.
- `annual` — paid, recurring, discounted vs monthly. Price not yet set.

Status enum: `active | expired | cancelled`. Lapsed entitlement
deletes new processing, never existing content (see §1.3).

### 1.3 Lapsed subscription behaviour

The entitlement gate runs at the top of every pipeline job
(`pipeline.rs:62-67`). If `active_entitlement()` returns `None`, the
recording moves to `status='blocked'` with `error='subscription or
trial ended'`. Already-generated summaries, exercises, quizzes
remain readable forever.

### 1.4 Admin role

Admins get a synthetic unlimited entitlement built in code
(`core/src/lib.rs:148 admin_entitlement`, expires 2099). They never
hit the subscription check. Admins exist to operate the platform,
moderate content historically, and support users — see §2.

### 1.5 Open business decisions

- Real prices for monthly / annual plans (table accepts them, values not set).
- Billing rails: Stripe vs App Store / Play Billing. Currently nothing
  is wired — the trial just expires silently after 7 days.
- Discount codes (table exists, no UI).
- Institutional / multi-seat pricing.
- Trial-abuse prevention (currently none — same email gets a fresh
  7-day trial each registration).

---

## 2. Roles & auth

Two roles only. Defined in `core/src/lib.rs:69 Role::Student |
Role::Admin`, stored as `TEXT` in `users.role`, validated at the
JWT-middleware layer.

### 2.1 Student (default)

The default role assigned at registration. Holds an `auth.refresh_tokens`
row, a `subscriptions` row (trial first), and a drift DB on the phone.

### 2.2 Admin

Seeded at API startup from `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars
(`auth::handlers::seed_admin`, idempotent). Can:

- Read every user's data (`/api/admin/users`, `/api/admin/recordings`).
- Stream any recording's audio via `/api/admin/recordings/:id/audio`.
- Swap the study-material model at runtime via
  `/api/admin/study_generator`.

### 2.3 JWT chain

- Access token: 15 min TTL.
- Refresh token: 30 day TTL, rotation.
- Middleware chain (in order): `require_auth` then `require_admin`.
- Public routes: `/api/auth/{register,login,refresh}`.

The middleware extracts claims into request extensions; handlers
read them via the `AuthUser(claims)` extractor (`auth/middleware.rs:45`).

---

## 3. Core flows

### 3.1 First run + trial

1. Mobile: POST `/api/auth/register` with email + password.
2. API: creates user, seeds 7-day trial subscription, returns
   access + refresh JWT.
3. Mobile: persists tokens in local storage, enters the home shell.
4. Sync engine starts its adaptive foreground poller.

### 3.2 Offline-first sync

Every entity has a client-generated UUID (`client_uuid`). Writes are
idempotent upserts (`ON CONFLICT (client_uuid) DO UPDATE`).
A monotonic Postgres sequence (`sync_version_seq`) is bumped on every
mutation; clients send `?since=<cursor>` to get deltas. Soft delete
(`deleted_at`) carries deletions through the delta so the client
sees tombstones.

The mobile side normally polls every 45 seconds, but switches to a
2-second poll while a recording is uploading or processing. It also
runs immediately when connectivity returns, the app resumes, the user
requests a sync, or a recording stops. Foreground and WorkManager
passes share a three-minute SQLite lease so two isolates cannot mutate
the local database concurrently. A trigger received during an active
pass schedules exactly one follow-up pass instead of being dropped.

Push goes first, pull second, so local changes land before remote
changes are accepted back. Upload failures persist `next_retry_at`;
the 2-second active poll must respect that timestamp or it becomes a
tight retry storm.

### 3.3 Recording → AI pipeline → study

This is the critical flow. End to end:

```
mobile record()
  → local drift row (status='local_only')
  → mobile stop()
  → status='pending_sync'
  → sync tick: upload chunks to API via /api/recordings/uploads
  → status='uploading'
  → complete_upload: API does one R2 put_object, persists the
      recording, then enqueues recording_jobs(state='queued')
  → durable worker claims the row with FOR UPDATE SKIP LOCKED
  → recording_jobs.state='running' + a renewable worker lease
  → pipeline:
      1. entitlement check       → status='blocked' if none
      2. storage.read(audio)
      3. STT.transcribe_with_progress(audio)
      4. silent-guard (zero words → status='failed' w/ msg)
      5. persist this recording's transcript + timed segments
      6. merge every chapter-session transcript chronologically
      7. StudyGenerator.generate(chapter, cumulative transcript)
      8. append one generation-linked summary/exercises/quiz pack
      9. status='ready', progress=100, job.state='done'
  → transient error: job.state='retry_wait' with exponential backoff
  → worker death: expired lease is swept and re-queued automatically
  → mobile active poll (≈ 2 s) → recording + study deltas → material
```

Queue invariants: heartbeat every 30 seconds, lease expires after two
minutes, stale-job sweep every 30 seconds, maximum six claimed
attempts, retry delay starts at 15 seconds and caps at 15 minutes.
These values live together at the top of `pipeline.rs`; change them as
one system, never independently.

### 3.4 Studying offline

Once the delta lands locally, the mobile app renders the summary as
markdown, exercises as flashcards, and quiz as multiple-choice. Quiz
attempts are tracked client-side and pushed back to `/api/quizzes/:id/attempts`
on the next sync.

---

## 4. Architecture

### 4.1 Components

```
                 ┌─────────────────────────┐
                 │  Admin SPA (Svelte 5)    │  http://localhost:5173
                 │  → /api/* (admin routes) │
                 └────────────┬────────────┘
                              │ Bearer JWT
                 ┌────────────▼────────────┐
                 │  API (Rust + Axum 0.7)   │  http://localhost:7878
                 │  port 7878               │
                 └────────────┬────────────┘
                              │ SQLx
                 ┌────────────▼────────────┐         ┌────────────────────┐
                 │  Postgres 16            │         │  Cloudflare R2     │
                 │  port 15432              │         │  bucket:           │
                 └─────────────────────────┘         │   buddywize-audio  │
                                                     └────────────────────┘
                 ┌─────────────────────────┐         ┌────────────────────┐
                 │  Mobile (Flutter)       │  Bearer │  Cloudflare        │
                 │  drift / Riverpod        │  JWT    │  Workers AI        │
                 │  → /api/* (all routes)   │         │  STT + LLM         │
                 └─────────────────────────┘         └────────────────────┘
```

### 4.2 Rust crates

Each crate owns a tight slice of business logic. The intent is to
split into separate binaries later without rewriting.

| Crate | Purpose |
|---|---|
| `buddywize-core`     | Shared types, errors, Role enum, `SettingsStore`, `StorageBackend` trait, entitlement helpers, JWT-friendly `ApiError`. |
| `buddywize-auth`     | JWT issue/validate, password hashing, `require_auth` + `require_admin` middleware, seed-admin on startup. |
| `buddywize-courses`  | Agenda / courses / lessons / chapters CRUD + delta sync. Study material delta endpoint. Quiz attempts. |
| `buddywize-recordings` | Resumable chunked upload sessions and durable queue enqueue/reprocess operations. |
| `buddywize-ai`      | `SttProvider` + `StudyGenerator` traits, all implementations, `pipeline::Pipeline`. |
| `buddywize-admin`   | Admin-only endpoints: users, recordings, study_generator swap. |
| `buddywize-api`     | The Axum binary that wires everything together, runs migrations, starts the pipeline worker. |

### 4.3 Mobile (Flutter)

- **State**: Riverpod throughout.
- **Offline DB**: drift with code-generated schema. Tables include
  `recordings`, `transcripts`, `summaries`, `exercises`, `quizzes`,
  plus a cursor table for delta sync.
- **Audio capture**: the `record` package, AAC-LC encoder, m4a
  container, explicitly configured at 48 kbps mono, 16 kHz. Do not
  rely on the package defaults (128 kbps stereo, 44.1 kHz).
- **HTTP**: the in-house `api_client.dart` handles JWT refresh on 401.
- **Sync engine**: `lib/sync/sync_engine.dart` — leased, adaptive,
  push-local then pull-remote, with `InsertMode.insertOrReplace` for
  pulled rows and persisted retry timestamps for interrupted uploads.

### 4.4 Admin (Svelte 5)

- Vite SPA on port 5173.
- Bearer token in `localStorage`, refreshed in `api.js` on 401.
- Four tabs in the sidebar: Dashboard, Recordings, Users, Settings.
- The Recordings tab lets admins expand any row to play the audio
  (HTTP Range), read the transcript, and inspect the generated
  summary/exercises/quiz inline (rendered with `lib/markdown.js`).

---

## 5. Tech stack with the why

| Layer | Choice | Why |
|---|---|---|
| HTTP server | **Axum 0.7** | Tower ecosystem, fast, ergonomic middleware, utoipa for OpenAPI. |
| Async runtime | **Tokio (full)** | Industry standard, integrates with reqwest + sqlx. |
| DB driver | **SQLx with Postgres** | Compile-time query checks via `sqlx::query!` where used. We use `query_as` for ergonomics but the schema is in sync. |
| OpenAPI | **utoipa + swagger-ui** | Auto-generated from handler annotations. UI at `/docs`. |
| JWT | **jsonwebtoken** | Battle-tested, no surprises. |
| Password hashing | **argon2** | Default secure choice. |
| Object storage | **Cloudflare R2 over S3 API** | Cheap egress, no per-request fees. Picked because the mobile uploads chunked audio and we want the cheapest durable target. |
| STT | **Cloudflare Workers AI Whisper large-v3-turbo** | GPU-backed, $0.00051/audio-minute, ~5× real-time. Free tier covers 3.5 h/day. Local `faster-whisper medium` is the fallback for offline dev. |
| LLM | **Cloudflare Workers AI DeepSeek-R1-Distill-Qwen-32B** | Reasoning-capable, $0.50/M input, $4.88/M output. Thinking model — see §10 law #10. |
| Mobile framework | **Flutter** | Single codebase for iOS + Android, drift for offline SQL, mature `record` package for audio capture. |
| Mobile offline DB | **drift** | Code-generated schema, type-safe queries, fast. |
| Mobile state | **Riverpod** | Async-first, no global rebuild, plays nicely with drift's streams. |
| Admin framework | **Svelte 5 (Vite)** | Tiny bundle, reactive without virtual DOM. We're not building a SPA-heavy admin tool — the recording detail view is the heaviest thing. |
| Postgres | **16-alpine** | Standard. |

### What we did NOT pick, and why

- **GraphQL**: CRUD is REST-shaped. No fan-out needed. Adds complexity
  for zero benefit.
- **gRPC**: Same reasoning. Plus Rust + gRPC tooling is heavier.
- **Kubernetes**: One Postgres + one API + one admin container. K8s
  is overkill until we need horizontal scale.
- **Materialized views / event sourcing**: We're not at the scale
  where query optimization matters. A single Postgres + a few
  indexes handles our load easily.
- **Pusher / WebSocket**: The 45-second polling sync is good enough at
  our scale. WebSockets add connection state we don't need yet.

---

## 6. Data model

Nineteen tables. Migrations live in `backend/migrations/`. They are
append-only — see §10 law #8.

| Table | Purpose | Status column | Sync semantics |
|---|---|---|---|
| `users` | Account + role. | `role` (student/admin). | Server-only; mobile never writes here. |
| `refresh_tokens` | JWT refresh chain. | `revoked_at` (nullable). | Server-only. |
| `subscriptions` | Plan + expiry. | `status` (active/expired/cancelled). | Server-only; mobile reads via /me. |
| `agenda_items` | Calendar slots the student is preparing for. | — | Client UUID; soft-delete. |
| `courses` | Owned by user. | — | Client UUID; soft-delete. |
| `lessons` | Belongs to a course. | — | Client UUID; soft-delete. |
| `chapters` | Recording container. | — | Client UUID; soft-delete. |
| `recordings` | One row per uploaded recording. | `uploaded` → `processing` → `ready` (or `failed` / `blocked`). | Server-only id (UUIDv4); mobile uses `client_uuid` until upload completes. |
| `upload_sessions` | Resumable chunked upload bookkeeping. | `completed_at` (nullable). | Server-only. |
| `recording_jobs` | Durable processing queue with retry schedule and worker lease. | `queued` / `running` / `retry_wait` / `done` / `failed`. | Server-only; claimed with `FOR UPDATE SKIP LOCKED`. |
| `recording_processing_events` | Append-only operational progress timeline. | `stage` + `progress_percent`. | Server-only metadata; never stores audio or transcript text. |
| `transcripts` | STT output. | `provider` (stable string — see §10 law #9). | Server-generated; mobile pulls. |
| `summaries` | Markdown summary. | `pending_review` (legacy) / `approved` (current). | Mobile pulls. |
| `exercises` | 3 items as JSONB. | `pending_review` / `approved`. | Mobile pulls. |
| `quizzes` | 10 questions as JSONB. | `pending_review` / `approved`. | Mobile pulls. |
| `quiz_attempts` | Client-graded quiz results. | — | Client UUID; mobile pushes. |
| `discount_codes` | Future. | — | Server-only. |
| `institutions` | Future. | — | Server-only. |
| `app_settings` | Runtime-tunable values read by the pipeline. | — | Server-only; admin UI mutates. |

### Status state machine — `recordings.status`

```
   uploaded
      │ durable job is queued and claimed
      ▼
   processing
      │
      ├── entitlement lapsed ──► blocked
      │
      ├── stt produced 0 words ──► failed
      │
      ├── retryable provider/storage error ──► retry_wait ──► processing
      │
      ├── retry budget exhausted / permanent error ──► failed
      │
      └── all good ──► ready
```

Retryable failures return to `processing` automatically through the
durable queue. A terminal `failed` row moves again only through an
explicit reprocess request. `blocked` is terminal until entitlement is
restored and the recording is explicitly reprocessed.

---

## 7. Storage

### 7.1 R2 vs local

Selected at boot by env vars. `R2_BUCKET` + credentials → R2.
Otherwise local filesystem at `STORAGE_DIR` (default `.storage/`).
Same `StorageBackend` trait either way.

### 7.2 R2 single put_object (commit `f01f844`)

Why not multipart: Cloudflare R2 enforces a **5 MiB minimum** on each
multipart part, and our mobile uploads send 256 KB chunks. Stream-through
multipart would always fail at `CompleteMultipartUpload` time.

The fix: the server accumulates chunks in memory (`R2Upload::bytes`)
and does a single `put_object` on `finish_upload`. Memory budget per
in-flight upload ≈ file size; at 128 kbps AAC a 1 h recording is
57 MiB, well within reason.

Limit: 5 GiB per upload (R2's per-object cap). For a 4 h course we
hit ~220 MB — still fine.

### 7.3 Local filesystem

Used in tests and offline dev. `partial/<key>.part` while uploading,
`objects/<key>` once complete. The same `StorageBackend` trait means
no business logic cares which backend is active.

### 7.4 Admin audio endpoint (commit `63902b8`)

`GET /api/admin/recordings/:id/audio` returns `206 Partial Content`
when the client sends a `Range:` header. The `<audio>` element in
the admin SPA seeks, so without Range support seeking would
re-download the entire file on every scrub.

### 7.5 Database/storage namespace binding

The first successful API startup stores the physical storage namespace
in `app_settings.system_storage_namespace`. R2 identities include the
account and bucket; local identities include the storage directory.
Every later startup must match exactly.

`storage::bind_database_namespace` runs before any provider or worker is
started. A mismatch aborts startup with a precise error. Never bypass,
delete, or rewrite this setting to make a local test start: using a
populated R2 database with local storage creates completed database rows
whose audio exists only on one developer machine.

For an isolated local test, use an isolated database and an isolated
`STORAGE_DIR`. For a real-provider test, use the database's bound R2
configuration. R2 SDK failures use debug-formatted errors so status,
request metadata, and service error details survive into logs.

---

## 8. AI pipeline

The pipeline is the most-likely-to-regress part of the codebase. This
section is dense on purpose — read it before touching
`buddywize-ai`.

### 8.1 Provider traits

```rust
#[async_trait]
trait SttProvider: Send + Sync {
    fn name(&self) -> &str;                       // stable, persisted to DB
    async fn transcribe(&self, audio: &[u8]) -> Result<Transcript>;
}

#[async_trait]
trait StudyGenerator: Send + Sync {
    fn name(&self) -> &str;
    async fn generate(&self, chapter: &str, transcript: &Transcript)
        -> Result<GeneratedContent>;
}
```

Both are object-safe (no generic methods, no `Self` in return type),
so the pipeline holds `Arc<dyn SttProvider>` /
`Arc<dyn StudyGenerator>`. See §10 law #6.

### 8.2 Default STT — `STT_PROVIDER=cloudflare`

`CloudflareWhisperStt` (in `cloudflare_whisper.rs`) hits the
Cloudflare `/ai/run/@cf/openai/whisper-large-v3-turbo` endpoint
with JSON body `{ "audio": <base64> }`. Audio larger than 20 MiB or
15 minutes is sliced with `ffmpeg -c copy` into per-segment temp
files, each transcribed, then stitched into a single transcript.

Cost: $0.00051 per audio minute. Free tier: 10k neurons/day ≈ 3.5 h
of audio per day. Fallback: `STT_PROVIDER=local` (faster-whisper
subprocess, medium model on CPU, ~0.6× real-time). Never delete the
local path — see §10 law #2.

### 8.3 Durable queue, leases, and progress

Postgres is the queue. `complete_upload` and `reprocess` upsert one
`recording_jobs` row per recording; an in-memory channel is not an
acceptable source of truth. Workers claim due work with
`FOR UPDATE SKIP LOCKED`, write a unique `worker_id`, and renew
`locked_at` every 30 seconds.

Recovery must run both at startup and periodically. Startup-only
recovery is incorrect: after a quick process restart, the abandoned
lease is still fresh at startup and would otherwise remain `running`
forever. `Pipeline::requeue_stale_jobs` sweeps every 30 seconds and
reclaims a lease after two minutes.

Every visible stage update changes `recordings.sync_version` and appends
a `recording_processing_events` row. This lets the phone show actual
progress and guarantees a later delta replaces stale local state.

Source: `pipeline.rs::{run,recover_jobs,requeue_stale_jobs,
spawn_job_heartbeat,fail_or_retry_job}` and
`migrations/008_recording_pipeline_progress.sql`.

### 8.4 Silent-recording guard (commit `52c10f6`)

```rust
// Pipeline::process
if transcript.text.split_whitespace().count() == 0 {
    self.set_terminal_status(
        recording_id,
        "failed",
        "failed",
        50,
        Some("no speech detected — the recording is silent (check your microphone)"),
        "Aucune voix détectée dans cet enregistrement",
        false,
        Some("no_speech_detected"),
    ).await?;
    tracing::warn!(%recording_id, "pipeline rejected silent recording");
    return Ok(());
}
```

A silent recording is the user's microphone being broken. We must
surface this loudly, not produce a study pack from silence. See
§10 law #4.

### 8.5 Default LLM — `STUDY_GENERATOR=cloudflare-deepseek`

`DeepSeekStudyGenerator` (in `deepseek.rs`) hits the Cloudflare
chat-completions endpoint with the model id read live from
`app_settings.study_generator_model`. The model field in the
transcript row is set from `stt.name()` (line 97 of `pipeline.rs`).

Failure semantics (commit `5151578`):
- HTTP errors → return Err immediately from the provider; the durable
  pipeline classifies the error and decides whether to schedule a retry.
- JSON parse errors → retry once inside the provider with a stricter
  prompt, then return the real error to the durable pipeline.
- No mock fallback. Failures surface as observable `retry_wait` or
  terminal `failed` states, never fabricated study content.

### 8.6 Reasoning-token handling

Reasoning-capable models (DeepSeek-R1, o1, Claude thinking, etc.)
wrap their chain-of-thought in `<think>...</think>` blocks before
the actual answer. The parser must strip these before JSON parse.

`strip_thinking_and_fences(s)` in `deepseek.rs` removes every
`<think>...</think>` block (multiple, possibly unclosed) and then
calls `strip_code_fences` to drop any markdown code fences.
After that, the response is either valid JSON (parse) or has JSON
embedded in prose (`extract_json_object` walks braces, skipping
those inside strings).

### 8.7 Study pack shape

The user requirement: **3 exercises + 10 quiz questions**. The
prompt enforces these counts. The code truncates excess with a
warning (`deepseek.rs:240-250`) so a model that overshoots still
saves successfully. We never pad — a model that under-delivers
fails the schema check.

The system prompt is in `deepseek.rs:SYSTEM_PROMPT` and the user
prompt in `build_user_prompt(chapter, transcript)`. Both are
deterministic strings; testing them in isolation is straightforward.

### 8.8 Free tier math

- Cloudflare Workers AI free plan: 10,000 neurons/day.
- Whisper large-v3-turbo: ~46.63 neurons/audio-minute → ~3.5 h/day free.
- DeepSeek-R1-Distill-Qwen-32B: billed per token (reasoning tokens
  count as output). $0.50/M input, $4.88/M output.
- A typical 30 min lecture: ~$0.02 in Whisper + ~$0.02 in DeepSeek.
- A 4 h course: ~$0.10 in Whisper + ~$0.04 in DeepSeek.

Production ceiling without going paid: ~3.5 h of audio + ~140 LLM
calls per day.

---

## 9. Mobile sync engine

`mobile/lib/sync/sync_engine.dart`:

- **Trigger**: one-shot adaptive timer: 45 seconds while idle, 2 seconds
  while upload/processing work exists. Connectivity, resume, manual,
  recording-stop, and WorkManager triggers also run a pass.
- **Concurrency**: a three-minute lease in drift `meta` serializes
  foreground and background isolates. A concurrent trigger requests
  one rerun instead of starting a second mutation pass.
- **Push**: query drift for rows with `pendingSync=true`, POST each to the
  server's upsert endpoint, mark clean on success.
- **Pull**: GET `/api/sync/...?since=<last_cursor>`, apply each row
  with `InsertMode.insertOrReplace` (NOT `insertIgnore` — see §10
  law #5), update cursor.
- **Conflict policy**: server wins. Local edits get overwritten on
  the next sync. Acceptable for our use case (study material is
  server-generated; course structure the mobile mostly mirrors).

The engine wraps network failures in persisted retry-with-backoff and a
"Sync error" UI state surfaced in `home_shell.dart`. A completed-upload
resume handshake is authoritative: if the API finalized before the app
persisted its response, the app adopts the returned recording instead
of uploading duplicate audio.

---

## 10. ⛔ 13 ANTI-REGRESSION LAWS

These are the bugs that have already burned us, plus the structural
patterns that keep them from happening again. Treat each as a failing
review. A PR that violates a law without an accompanying
`law(amend)` commit will be rejected.

**Amendments:** Laws can change, but every amendment must be its own
commit with the message format `law(amend): #<n> — <reason>`. This
keeps the historical record greppable and prevents silent drift.

**Enforcement:** A PR that violates a law without an accompanying
`law(amend)` commit will be rejected in review.

**When to amend:** Only when the underlying constraint has actually
changed (e.g. Cloudflare ships a Whisper variant that can ingest any
chunk size — then law #3 can be retired). Never amend to "make a PR
pass" — fix the PR instead.

---

### Law 1 — Study material auto-approves

No admin moderation gate. The pipeline inserts summaries / exercises
/ quizzes with `status='approved'` directly. The legacy `pending_review`
state and the `decide_*` endpoints are deprecated; the admin UI's
"Content review" tab is gone.

Source: `pipeline.rs:131,141,151` (the three INSERT statements),
`migrations/002_auto_approve_study_material.sql` (flips any existing
`pending_review` rows). Commit `ed09b65`.

---

### Law 2 — STT_PROVIDER defaults to cloudflare; local is fallback

`STT_PROVIDER=cloudflare` is the production default, hitting
`@cf/openai/whisper-large-v3-turbo` on Cloudflare GPUs. The local
faster-whisper path (`STT_PROVIDER=local`) and the offline mock
(`STT_PROVIDER=mock`) exist for dev only — never delete them. A
developer without internet access should always be able to run the
stack.

Source: `main.rs:148-164` (the three-way match), `whisper.rs` (local
impl), `mock.rs` (offline impl).

---

### Law 3 — R2 uploads go through single put_object, not multipart

Cloudflare R2 enforces a **5 MiB minimum** on each multipart part,
and the mobile uploads send 256 KB chunks. Multipart always fails at
`CompleteMultipartUpload` time. The server accumulates chunks in
memory (`R2Upload::bytes`) and does a single `put_object` on
`finish_upload`.

Source: `core/src/storage.rs:281-294` (`R2Storage::finish_upload`).
Commit `f01f844`.

Memory budget: per in-flight upload ≈ file size. A 1 h recording at
48 kbps AAC is ~20.6 MiB. A 4 h recording is ~82.4 MiB. Both fit.

---

### Law 4 — Silent recordings fail loudly

A transcript with zero words is the user's microphone being broken.
The pipeline must not produce a study pack from silence. We surface
this as `status='failed'` with an explicit message so the mobile app
shows "check your microphone".

Source: `pipeline.rs:80-89`. Commit `52c10f6`. The same guard
applies in `CloudflareWhisperStt::transcribe` for the new default
provider — the silence detection is upstream of provider choice.

---

### Law 5 — No mock fallback in the LLM pipeline

The DeepSeek generator must return the real error when the upstream
call fails or returns non-JSON. We do NOT silently substitute
`MockStudyGenerator` output. The durable queue may put a retryable
failure in `retry_wait`; exhausted or permanent failures go to
`status='failed'`. Both retain the real error for admins and the mobile
app.

Source: `deepseek.rs:generate` — single retry on JSON parse failure,
no retry on HTTP failure, no fallback path. The `MockStudyGenerator`
remains in the codebase for the explicit `STUDY_GENERATOR=mock`
env switch, used only in offline dev. Commit `5151578`.

---

### Law 6 — Trait-bound providers, never hardcoded in pipeline.rs

`Pipeline` holds `Arc<dyn SttProvider>` and `Arc<dyn StudyGenerator>`,
never a concrete type. Adding a new provider = new file under
`backend/crates/buddywize-ai/src/<name>.rs` that implements the trait,
zero modification to `pipeline.rs`. Switching providers = one
`if/else` line in `main.rs` keyed on env var.

Source: `pipeline.rs:13-18` (the struct fields), `ai/src/providers.rs:46-66`
(the trait definitions).

This keeps the pipeline testable (use a fake provider), keeps the
provider swap a one-line operation, and prevents accidentally coupling
business logic to a vendor's API shape.

---

### Law 7 — Runtime settings via SettingsStore, never env reads in business logic

Everything runtime-configurable goes through `Arc<dyn SettingsStore>`.
The pipeline, the admin handlers, the AI generators read settings via
`settings.get_or_load("key")`. They do NOT call `std::env::var("KEY")`.

The boundary is `main.rs`: env reads happen there, the resolved
values are injected into the runtime state.

Source: `core/src/settings.rs` (`SettingsStore` trait + `SettingsCache`),
`main.rs` (the only place that reads `STT_PROVIDER` / `STUDY_GENERATOR`).

Benefits: admin UI can swap values at runtime; tests inject a fake
`SettingsStore`; startup fails loudly if a required value is missing.

---

### Law 8 — Migrations are append-only

A migration that has been deployed is never edited. Every schema
change is a new file `00X_*.sql` (next sequential number) applied on
top. A `git pull` on a deployed environment must never break
running migrations.

Source: `backend/migrations/001_init.sql` (initial), `002_*.sql` (auto-
approve), `003_app_settings.sql` (settings table). The first 16 tables
exist in `001_init.sql`; `app_settings`, `recording_jobs`, and
`recording_processing_events` were added by later append-only migrations.

---

### Law 9 — Stable identifiers in DB

`SttProvider::name()` and `StudyGenerator::name()` return stable
strings persisted to `transcripts.provider`. Renaming a provider is
a schema change, not a code refactor: it requires a migration that
backfills the column.

Known stable names (do NOT rename without a migration):
- `cloudflare-whisper-large-v3-turbo` — `cloudflare_whisper.rs:344`
- `faster-whisper-<model>` — `whisper.rs:238`
- `mock-stt` — `mock.rs:138`
- `mock-llm` — `mock.rs:175`
- `cloudflare-deepseek` — `deepseek.rs:248`

The column `transcripts.provider` is human-readable in the admin UI
and used for auditing. A silent rename breaks both.

---

### Law 10 — Reasoning-capable models are first-class

Any LLM provider that wraps a reasoning model (DeepSeek-R1,
minimax-M3, OpenAI o1, Claude with extended thinking, etc.) MUST
strip `<think>...</think>` blocks before JSON parsing. The pattern
lives in `strip_thinking_and_fences` in `deepseek.rs` and is
reusable.

This is not paranoia. Reasoning models are the norm now, not the
exception, and we already shipped a bug where every recording failed
on first attempt because DeepSeek-R1's thinking tokens leaked into
the JSON body.

Source: `deepseek.rs:strip_thinking_and_fences` + the fallback
`extract_json_object` for prose-embedded JSON. Tests:
`parses_v4_envelope_with_result_wrapper`, `strip_thinking_drops_reasoning_block`.

---

### Law 11 — Processing jobs are durable leases, not process memory

The canonical job state is `recording_jobs` in Postgres. A worker must
claim with `FOR UPDATE SKIP LOCKED`, heartbeat while processing, clear
its lease on completion/failure, and periodically reclaim expired
`running` rows. Startup-only recovery is forbidden.

Do not replace this with a Tokio channel, fire-and-forget task, or a
single startup reconciliation. Those approaches lose work or strand a
fresh lease after a quick restart.

Required regression test: force a job to `running` with `locked_at`
older than the lease timeout, leave the API running, and prove it moves
through `queued/running` to `done` without a restart or manual state
rewrite.

Source: `pipeline.rs:run`, `Pipeline::requeue_stale_jobs`,
`Pipeline::spawn_job_heartbeat`, and migration `008`.

---

### Law 12 — A database belongs to exactly one storage namespace

Every API startup calls `storage::bind_database_namespace`. The value in
`app_settings.system_storage_namespace` must match the configured R2
account/bucket or local directory. A mismatch is a startup failure, not
a warning and not an automatic migration.

Never point a local-storage API at a populated R2 database. Never remove
the guard to unblock a test. Create an isolated database instead. The
fault-injection gate is to bind a database to R2, start once with
`R2_BUCKET` empty and a local `STORAGE_DIR`, and assert the process exits
before listening.

Source: `core/src/storage.rs:bind_database_namespace` and
`api/src/main.rs` immediately after `storage::from_env`.

---

### Law 13 — Speech capture is explicit AAC-LC 48 kbps mono

Every mobile recording uses the m4a container with AAC-LC at 48,000
bits/second, 16,000 samples/second, and one channel. All four values
must remain explicit in `speechRecordingConfig`; never fall back to the
`record` package defaults of 128 kbps, 44.1 kHz stereo.

This profile preserves the existing upload and playback contract while
reducing audio bytes, mobile upload time, R2 usage, and the API's
full-object memory pressure by approximately 62.5%. Changing the codec,
container, bitrate, sample rate, or channel count requires a real-device
recording test and an amendment to this law.

Required regression test:
`mobile/test/features/recording/recorder_service_config_test.dart`.

Source: `mobile/lib/features/recording/recorder_service.dart`.

---

## 11. Dev runbook

### 11.1 Prereqs

- Docker Desktop
- Rust stable (`rustup default stable`)
- Flutter stable (`/Users/dexter/flutter/bin/flutter`)
- Node.js (for the admin SPA)

### 11.2 Bring up local stack

```bash
# 1. Bring up Postgres + API + admin
docker compose up -d

# 2. Tail logs
docker logs -f buddywize-api-1

# 3. Hit the health probe
curl http://localhost:7878/health

# 4. Login as admin
curl -s -X POST http://localhost:7878/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@buddywize.local","password":"admin-buddywize"}'
```

Ports: API `7878`, admin `5173`, Postgres `15432`.

### 11.3 Env cheat-sheet

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `DATABASE_URL` | yes | `postgres://buddywize:buddywize_dev@localhost:5432/buddywize` | Postgres connection. |
| `JWT_SECRET` | yes | `change-me-in-production` | Rotate in prod. |
| `ADMIN_EMAIL` | no | `admin@buddywize.local` | Seeded admin email. |
| `ADMIN_PASSWORD` | no | `admin-buddywize` | Seeded admin password. |
| `R2_ACCOUNT_ID` | when using R2 | — | Cloudflare account id. |
| `R2_ACCESS_KEY_ID` | when using R2 | — | R2 S3 credential. |
| `R2_SECRET_ACCESS_KEY` | when using R2 | — | R2 S3 credential. |
| `R2_BUCKET` | when using R2 | — | R2 bucket name. |
| `STT_PROVIDER` | no | `cloudflare` | `cloudflare` \| `local` \| `mock`. |
| `CF_ACCOUNT_ID` | yes when cloudflare | — | Same as `R2_ACCOUNT_ID`. |
| `CF_AI_TOKEN` | yes when cloudflare | — | API token with `Workers AI:Read`. |
| `CF_WHISPER_MODEL` | no | `@cf/openai/whisper-large-v3-turbo` | Override the STT model. |
| `STUDY_GENERATOR` | no | `cloudflare-deepseek` | `cloudflare-deepseek` \| `mock`. |

### 11.4 Mobile

```bash
# Emulator (uses localhost by default)
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run

# Physical phone (build with API URL baked in)
flutter build apk --debug --dart-define=API_BASE_URL=http://<mac-lan-ip>:7878/api
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk

# USB-only test (no Wi-Fi needed): use adb reverse
adb -s <device-id> reverse tcp:7878 tcp:7878
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:7878/api
```

### 11.5 Tests

```bash
# Backend
cd backend
cargo test --workspace --all-targets  # currently 83 tests
cargo fmt --all -- --check

# Mobile
cd mobile
flutter test                    # currently 66 tests
flutter analyze

# Admin
cd admin
npm run build

# End-to-end smoke
./smoke_admin.sh                 # hits the running stack
```

For queue/storage changes, the ordinary suites are necessary but not
sufficient. Also run both fault tests:

1. Inject an expired `running` job lease and prove the live sweeper
   reaches `done` without restarting the API.
2. Start an R2-bound database with local storage and prove startup is
   refused before the listener opens.

For a release candidate, run one explicitly authorized, non-mock pass:
R2 `get_object` → Cloudflare Whisper → Cloudflare study generator →
`recordings.ready/100` + `recording_jobs.done`, then manually sync a
physical phone and verify transcript, summary, cards, exercises, and
quiz are visible. Logs must name the Cloudflare providers; seeing
`mock-stt` or `mock-llm` invalidates the result.

### 11.6 Linting / formatting

Not enforced today (no CI). Recommended pre-commit: `cargo fmt`,
`cargo clippy`, `dart format`, `dart analyze`.

---

## 12. Accounts & infra (sensitive — internal only)

| What | Value |
|---|---|
| Cloudflare account id | `504906a809e2118d3d3aeb5ae77b7063` |
| R2 bucket | `buddywize-audio` |
| Postgres (local docker) | `buddywize:buddywize_dev@localhost:15432/buddywize` |
| Admin login | `admin@buddywize.local` / `admin-buddywize` |
| GitHub repo | `https://github.com/dexterOuattara/buddyapp` (private) |
| Mac LAN IP | `192.168.1.x` (DHCP; rotate via `ipconfig getifaddr en0`) |
| Test rig phone | Redmi Note 11 Pro (`SKCI6TU4XKRCBMTG`, model `2201116TG`) |

Treat these as low-privilege dev credentials. Rotate the Cloudflare
token and the admin password before any production deployment.

---

## 13. Git conventions

One logical change per commit. Conventional-ish prefix:

```
feat(area): short imperative summary
fix(area): short imperative summary
refactor(area): short imperative summary
test(area): ...
docs: ...
```

`area` examples: `ai`, `auth`, `admin`, `mobile`, `sync`, `storage`,
`settings`, `pipeline`. For law amendments specifically:

```
law(amend): #<n> — <one-line reason>
```

Body paragraphs (separated by blank lines) explain the *why*. Avoid
"fix bug" — name the bug.

---

## 14. Where things live (cheat-sheet)

| Adding… | Goes to |
|---|---|
| A new STT provider | `backend/crates/buddywize-ai/src/<name>.rs` implementing `SttProvider`. Re-export in `ai/src/lib.rs`. Add to the 3-way match in `api/src/main.rs:148`. Add to the admin allow-list if you want it user-selectable. |
| A new LLM provider | `backend/crates/buddywize-ai/src/<name>.rs` implementing `StudyGenerator`. Same wiring pattern as STT. |
| A new admin endpoint | `backend/crates/buddywize-admin/src/lib.rs` (handlers) + `buddywize-api/src/main.rs` (route registration + OpenAPI path). |
| A new admin UI tab | `admin/src/views/<Name>.svelte` + add to `App.svelte` `tabs` and render switch. |
| A new env var | `docker-compose.yml` (default) + `.env` (local value) + `backend/.env.example` (documented placeholder). Never commit a real token. |
| A new database table | `backend/migrations/00X_<name>.sql` (next number). Append only — see law #8. |
| A new Rust test | Co-located in `mod tests` at the bottom of the file under test. |
| A new Flutter test | `mobile/test/<feature>_test.dart`. |

---

## 15. Known gaps / roadmap

- **Root `.env.example`** — `backend/.env.example` exists, but Compose
  still relies on a gitignored root `.env`. Add a secret-free root
  example before onboarding another developer.
- **LLM summarization has no chapter-aware prompt yet.** The user prompt is just the chapter title + transcript. A future improvement: include the previous chapter's summary so the new one has continuity ("continuing from where we left off…").
- **R2 upload assembly is in process memory.** A server restart during
  chunk upload makes the resume handshake return byte zero, so the phone
  safely retransmits from the beginning. This is correct but inefficient;
  durable partial-object storage would preserve the byte offset.
- **Delta pagination is capped at 500 rows per endpoint.** The API returns
  `has_more`, but every mobile pull path must loop until it is false before
  persisting the final cursor. Treat this as mandatory before accounts can
  realistically exceed 500 rows of one entity type.
- **No AI Gateway / cost tracking.** Each pipeline run logs tokens but doesn't aggregate them. A daily dashboard would help budget.
- **Cloudflare STT long-audio chunking loses 1-2 words at segment boundaries.** No overlap between segments, no smoothing. Mostly invisible on natural speech but noticeable on tightly-cut dictation. Could fix by overlapping 1 second or by using Whisper's `condition_on_previous_text` parameter with the previous segment's text.
- **No push notifications.** Sync is adaptive polling (45 seconds idle,
  2 seconds while recording work is active). FCM could remove the active
  polling cost and notify a backgrounded phone immediately.
- **No billing rail.** Trial just expires silently after 7 days. Stripe or IAP integration needed before going paid.
- **Free tier ceiling.** 3.5 h/day of audio + ~140 LLM calls is the hard cap on free plan. Going past it requires paid Cloudflare or self-hosted inference.
