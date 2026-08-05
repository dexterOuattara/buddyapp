# BuddyWize — Technical Document

*Note: this document assumes "Svelte" for the admin panel (referred to as "slevte" in the brief). Adjust if a different framework was intended.*

## 1. Purpose

This document describes the technical architecture, stack, and system design for BuddyWize, a mobile application that lets students plan courses, record lessons, and automatically receive summaries, exercises, and quizzes generated from those recordings.

## 2. User Stories

**Agenda & Planning**
- As a student, I want to add my courses and schedule to an agenda, so that I know what to prepare for and when.
- As a student, I want to see my agenda offline, so that I can check my schedule without needing a connection.

**Course & Content Structure**
- As a student, I want to organize a course into lessons and chapters, so that my recordings and study material stay structured and easy to navigate.
- As a student, I want to browse my existing courses, lessons, and chapters offline, so that I can review structure and past content anytime.

**Recording**
- As a student, I want to start recording a lesson from within a specific chapter, so that the recording is automatically linked to the right context.
- As a student, I want recording to work with no internet connection, so that I never miss capturing a class because of poor connectivity.
- As a student, I want to see whether a recording has been uploaded/synced or is still pending, so that I know what's safely backed up.

**Summary Generation**
- As a student, I want a summary automatically generated at the end of my recording, so that I don't have to write my own notes from scratch.
- As a student, I want to be told when I need to go online to generate a summary, so that I understand why it isn't ready yet.
- As a student, I want to review a generated summary once it's synced, so that I can study from it even later while offline.

**Exercises & Quizzes**
- As a student, I want to practice with exercises tailored to a specific chapter, so that I reinforce what was just taught.
- As a student, I want to generate a quiz for a chapter on demand, so that I can test my retention before an exam.
- As a student, I want to retake quizzes and see my results over time, so that I can track my progress on a chapter.

**Account & Subscription**
- As a new user, I want a 7-day free trial with full access, so that I can evaluate the app before paying.
- As a user, I want to choose between a monthly or a discounted annual plan, so that I can pick what fits my budget.
- As a user, I want to see clearly what happens to my access when my trial or subscription ends, so that there are no surprises.
- As a user, I want to apply a discount code at checkout, so that I can benefit from available promotions.

**Admin**
- As an admin, I want to manage users, courses, and institutions from a dashboard, so that I can support the platform at scale.
- As an admin, I want to review AI-generated summaries and quizzes before they're finalized, so that I can catch quality issues.
- As an admin, I want to monitor recording processing status and sync health, so that I can spot and resolve issues quickly.

## 3. Technology Stack

| Layer | Technology | Notes |
|---|---|---|
| Mobile App | **Flutter** (Dart) | Single codebase for iOS & Android; **offline-first** — fully usable with no connectivity |
| Local Storage | **SQLite** (via `drift` or `sqflite`) | Source of truth on-device; app reads/writes locally, syncs opportunistically |
| Backend / API | **Rust** | High-performance, memory-safe API and processing layer; acts as sync target, not a runtime dependency |
| Admin Panel | **Svelte** | Internal dashboard for content, user, and course management |
| API Documentation | **Swagger / OpenAPI** | Auto-generated, versioned API contract |
| Containerization | **Docker** | All services containerized; Docker Compose for local dev |
| Database | PostgreSQL *(proposed)* | Relational store for users, courses, chapters, transcripts |
| Object Storage | S3-compatible *(proposed)* | Audio recordings, generated summary/quiz assets |
| AI Services | Speech-to-text + LLM summarization/quiz engine *(build vs. API partner — to be decided)* | Triggered post-recording |

## 4. High-Level Architecture

**Design principle: offline-first.** The app must be fully usable with no internet connection — planning the agenda, browsing courses, recording lessons, and reviewing previously-synced summaries/exercises/quizzes all work offline. Internet connectivity is used strictly to **sync** state with the backend and to run cloud-dependent AI processing; it is never a blocker for core in-app actions.

```
┌────────────────────────────────────────┐
│           Flutter Mobile App            │
│  ┌────────────────────────────────┐    │
│  │   Local SQLite (source of truth) │    │        HTTPS/REST (sync only)
│  │   agenda, courses, recordings,   │───┼─────────────────────────────▶  ┌───────────────────────┐
│  │   summaries, exercises, quizzes  │◀──┼───────────────────────────────│   Rust API Gateway    │
│  └────────────────────────────────┘    │        when connectivity        │   (Swagger/OpenAPI)   │
│  ┌────────────────────────────────┐    │        is available             └──────────┬────────────┘
│  │   Sync Engine (queue + diff)     │    │                                            │
│  └────────────────────────────────┘    │                        ┌───────────────────────┼───────────────────────────────┐
└────────────────────────────────────────┘                        ▼                       ▼                                ▼
                                                          ┌──────────────────┐   ┌──────────────────────┐         ┌──────────────────────┐
                                                          │  Auth & User Svc │   │  Course/Content Svc  │         │  Recording & AI Svc   │
                                                          │  (Rust)          │   │  (Rust)              │         │  (Rust + STT/LLM API) │
                                                          └──────────────────┘   └──────────────────────┘         └──────────────────────┘
                                                                    │                       │                                │
                                                                    └───────────────────────┼────────────────────────────────┘
                                                                                              ▼
                                                                                   ┌───────────────────────┐
                                                                                   │   PostgreSQL + S3     │
                                                                                   └───────────────────────┘
                                                                                              ▲
                                                                                              │
                                                                                   ┌───────────────────────┐
                                                                                   │   Svelte Admin Panel  │
                                                                                   └───────────────────────┘
```

All backend services run as Docker containers, orchestrated via Docker Compose (dev) and a container orchestrator such as Kubernetes or Docker Swarm (production — to be confirmed based on scale).

## 5. Core Modules

### 5.1 Mobile App (Flutter)
- **Agenda module** — calendar view, course scheduling, reminders. Reads/writes local SQLite; works fully offline.
- **Course module** — course/lesson/chapter hierarchy, progress tracking. All navigable offline once synced at least once.
- **Recording module** — in-app audio capture, saved to local storage first; upload to backend is queued and happens opportunistically when online.
- **Summary & Study module** — displays AI-generated summaries, exercises, and quizzes per chapter, once results have synced back to the device; last-synced content remains available offline.
- **State management**: Riverpod or Bloc *(to be decided)*.
- **Local data layer**: SQLite (via `drift` or `sqflite`) as the on-device source of truth — the app always reads/writes locally first, never blocking on network calls.
- **Sync engine**: background component responsible for detecting connectivity, queuing outbound changes, pulling remote updates, and resolving conflicts (see §5.4).

### 5.2 Backend (Rust)
- **Framework**: **Axum** (see *Framework Decision* below).
- **Auth service**: JWT-based authentication, refresh tokens, role-based access (student / admin).
- **Course service**: CRUD for agenda, courses, lessons, chapters.
- **Recording service**: handles audio ingestion, storage, and triggers the processing pipeline.
- **AI orchestration service**: sends recordings to a speech-to-text engine, then to a summarization/quiz-generation model; stores structured results (summary text, exercise set, quiz bank).
- **API layer**: exposed via REST, documented and versioned with **Swagger/OpenAPI**; spec published at `/api/docs`.

#### Framework Decision: Axum vs. Actix-web

BuddyWize will use **Axum**.

| Criterion | Axum | Actix-web |
|---|---|---|
| Raw throughput | Slightly lower (~10-15% less than Actix under heavy load) | Highest raw throughput of the two, via a pinned-thread-per-core runtime |
| Learning curve / onboarding | Gentle — built directly on Tokio/Hyper by the Tokio team, so async code reads naturally | Steeper — the actor model adds a secondary abstraction layer that takes teams real time to internalize |
| Long-term maintainability | Strong — composable Tower middleware, modular nested routers stay organized as the API grows | Good, but more complexity to carry as the team and codebase scale |
| Ecosystem fit | Native alignment with Tokio/Tower/Hyper/Tonic — useful if BuddyWize later adds gRPC or splits into more microservices | Mature and battle-tested, but a separate ecosystem from Tokio-native tooling |
| Best suited for | Standard REST/CRUD APIs, microservices, teams that value clean structure | Performance-critical, high-throughput systems (e.g., ad serving, real-time trading) |

**Rationale**: BuddyWize's workload (agenda, course/lesson CRUD, recording uploads, periodic AI-processing calls) is not a raw-throughput-bound system — it's a typical product API. Axum's easier onboarding, cleaner long-term maintenance, and native Tokio/Tower integration outweigh Actix-web's raw performance edge, which mainly matters at a scale and latency-sensitivity BuddyWize is not targeting today. This can be revisited if a specific service (e.g., real-time transcription streaming) later proves genuinely throughput-bound.

### 5.3 Admin Panel (Svelte)
- Manage users, institutions, and course catalogs.
- Review/edit AI-generated summaries and quizzes before publishing (moderation step).
- Monitor recording processing status and system health.
- Consumes the same Swagger-documented API as the mobile app, via an admin-scoped role.

### 5.4 Offline-First Architecture & Sync Strategy

**Principle**: the mobile app is the source of truth for the user's own device state at any given moment; the backend is the source of truth for the account across devices. Internet is only required to reconcile the two.

**Local data layer**
- SQLite on-device (via `drift`, which gives type-safe queries and built-in migration support) stores the full working set: agenda, course/lesson/chapter structure, recordings metadata, transcripts, summaries, exercises, and quiz content already synced to the device.
- Audio files are written to local device storage immediately on recording stop — never held only in memory.
- Every locally created/edited record gets a client-generated UUID and a `dirty`/`pending_sync` flag.

**Sync engine**
- Runs as a background task in the Flutter app, triggered by (a) connectivity regained, (b) app foregrounded, (c) periodic timer while online, and (d) manual "sync now" action.
- **Push phase**: uploads queued changes (agenda edits, course structure edits, new recordings) in dependency order — e.g., a chapter must exist server-side before a recording referencing it is pushed.
- **Pull phase**: fetches server-side changes since the last sync cursor (timestamp or incrementing version per resource) — new/updated summaries, exercises, quizzes, or content pushed from the admin panel.
- **Large file handling**: recordings sync as a separate, resumable/chunked upload (so a poor or interrupted connection doesn't force a full re-upload), decoupled from the lightweight JSON sync of structured data.
- **Sync status is visible to the user**: pending upload / synced / sync failed indicators per recording and per chapter, so a student always knows what's safely backed up vs. only local.

**Conflict resolution**
- Most entities (agenda items, course structure) are single-user, single-writer in practice, so a simple **last-write-wins by updated-at timestamp** is sufficient for v1.
- Recordings and their derived content (summary/exercises/quiz) are immutable once generated — no conflict scenario, only "generated" vs. "not yet generated."
- If multi-device editing of the same agenda/course becomes a real use case later, this can be upgraded to field-level merge or a CRDT-based approach — flagged as a future enhancement, not a v1 requirement.

**AI processing while offline (confirmed design)**
- Recording, browsing courses/agenda, and reviewing already-synced summaries/exercises/quizzes all work fully offline.
- AI generation (transcription → summary → exercises → quiz) always requires internet — there is no on-device fallback. A recording made offline is marked "pending processing," uploaded automatically once online, and processed server-side; results sync back down to the device on the next sync.
- The user must go online at least once per new recording to get it summarized and turned into study material. This is communicated to the user via clear sync-status indicators (§5.4) — e.g. "Recorded — go online to generate summary."

**Backend implications**
- API endpoints must support **incremental/delta sync** (e.g., `GET /courses?since=<cursor>`) rather than assuming the client always fetches full state.
- Idempotent write endpoints (accepting client-generated UUIDs) so a retried push after a dropped connection doesn't create duplicates.
- Resumable upload support for the recording endpoint (e.g., chunked upload with an offset/resume token).

## 6. Data Flow: Recording → Summary → Quiz

1. User selects a lesson/chapter in the Flutter app and starts recording — works fully offline.
2. On stop, the audio is saved to local storage immediately and marked `pending_sync`; if online, the sync engine begins a resumable upload to the Recording Service (Rust) in the background.
3. Recording Service stores the raw audio in object storage and enqueues a processing job once the upload completes.
4. AI Orchestration Service runs speech-to-text, then passes the transcript to the summarization/quiz-generation model.
5. Results (summary, exercises, quiz questions) are persisted and linked to the chapter server-side.
6. On the app's next sync (foreground, connectivity regained, or periodic check), the pull phase fetches the new summary/exercises/quiz into local SQLite; the mobile app displays them and unlocks study mode for that chapter — all subsequently available offline.

## 7. API Design (Swagger/OpenAPI)

- Single source of truth: OpenAPI spec versioned in the repo, auto-generated from Rust route definitions where possible (e.g., via `utoipa` or `paperclip`).
- Swagger UI exposed on a non-production-facing path for internal/admin use; locked behind auth in production.
- Suggested top-level resource groups:
  - `/auth`
  - `/agenda` *(supports `?since=<cursor>` for delta sync)*
  - `/courses`, `/courses/{id}/lessons`, `/lessons/{id}/chapters` *(delta sync)*
  - `/recordings` *(resumable/chunked upload)*
  - `/chapters/{id}/summary`
  - `/chapters/{id}/exercises`
  - `/chapters/{id}/quiz`
  - `/sync/status` (lightweight endpoint to check what's changed before pulling full resources)
  - `/admin/*` (Svelte panel only, role-restricted)

## 8. Infrastructure & Deployment

- **Containerization**: each service (API gateway, auth, course, recording/AI, admin frontend) has its own Dockerfile; `docker-compose.yml` for local development.
- **CI/CD**: build and test Rust services and Flutter app on each push; build/push Docker images; deploy via a pipeline (GitHub Actions or GitLab CI — to be confirmed).
- **Environments**: dev, staging, production, each with isolated database and storage.
- **Secrets management**: environment variables via a secrets manager (not committed to source).

## 9. Security Considerations

- HTTPS everywhere; TLS termination at the gateway/load balancer.
- JWT with short-lived access tokens + refresh token rotation.
- Role-based access control (student vs. admin) enforced at the API layer.
- Audio recordings and transcripts treated as sensitive user data — encrypted at rest, access-logged.
- Rate limiting on recording upload and AI processing endpoints to control cost and abuse.

## 10. Pricing & Monetization

BuddyWize uses a freemium-trial → subscription model.

| Plan | Price | Notes |
|---|---|---|
| Free Trial | $0 for 7 days | Full feature access; no restrictions during trial |
| Monthly | $5 / month | Billed monthly, cancel anytime |
| Annual | $50 / year | Equivalent to ~$4.17/month — roughly 2 months free vs. paying monthly (a ~17% discount) |
| Promotional discounts | Variable | Discount codes supported (e.g., student/institutional partnerships, seasonal promos, referral rewards) |

**Product implications**
- **Trial-to-paid conversion**: the app must track trial start/end per account server-side (not just on-device, to prevent trial reset via reinstall) and clearly surface remaining trial days in the UI.
- **Offline + subscription interaction**: since AI generation requires connectivity anyway, subscription/entitlement checks can happen server-side at the point of sync/processing rather than blocking offline actions like recording or browsing — a lapsed subscription should not lock a student out of their already-synced local content, but should block *new* AI processing until renewed.
- **Discount codes**: applied at checkout (in-app purchase flow or web checkout, depending on platform billing strategy — see below).
- **Billing implementation**: mobile subscriptions on iOS/Android typically must go through Apple/Google in-app purchase APIs (App Store/Play Billing) for compliance; a server-side entitlement service (Rust) validates purchase receipts/tokens and stores subscription status, independent of the app store used.
- **Institutional/team pricing**: not defined yet — flagged as an open decision below if BuddyWize plans to sell to schools/training centers (per the target users in the executive summary).

## 11. Open Decisions

- [ ] Billing implementation: native App Store/Play Billing vs. web-based checkout (e.g., Stripe) vs. hybrid
- [ ] Discount code mechanism: fixed codes, referral-based, institutional bulk codes, or a combination
- [ ] Institutional/team pricing tier (relevant if selling to schools/training centers)
- [ ] Trial abuse prevention (e.g., device/account fingerprinting to prevent repeated trial resets)
- [ ] Mobile state management: Riverpod vs. Bloc
- [ ] Local DB library: `drift` vs. `sqflite` vs. `Isar`
- [ ] Conflict resolution beyond v1 last-write-wins (needed if multi-device editing becomes a real use case)
- [ ] Database: confirm PostgreSQL
- [ ] Object storage provider (S3, MinIO self-hosted, etc.)
- [ ] Build vs. buy for speech-to-text and summarization/quiz-generation
- [ ] Orchestration for production: Kubernetes vs. Docker Swarm vs. managed container service
- [ ] Push notification provider for processing-complete alerts

## 12. Next Steps

1. Confirm open decisions above.
2. Design the local SQLite schema and sync-cursor strategy before writing any backend endpoints — the API contract must be delta-sync-friendly from day one.
3. Define the OpenAPI spec skeleton for core resources (courses, recordings, summaries), including `since`/cursor parameters and resumable upload semantics.
4. Stand up Docker Compose dev environment (API + Postgres + storage + Svelte admin).
5. Build the offline recording → local storage → queued upload → transcription → summary pipeline as a proof of concept (this is the highest-risk path given the offline-first requirement).
6. Wire the Flutter app's sync engine to the API for the core agenda → record → summary flow, testing explicitly with airplane-mode and flaky-connection scenarios.