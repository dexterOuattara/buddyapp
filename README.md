# BuddyWize

Offline-first course companion for students: plan courses in an agenda, record lessons,
and automatically receive AI-generated summaries, exercises, and quizzes per chapter.

Built from the BuddyWize technical document (see `docs/TECH_SPEC.md`).

## Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (offline-first, drift/SQLite, Riverpod) |
| Backend | Rust — Axum 0.7, SQLx (PostgreSQL), utoipa (OpenAPI/Swagger) |
| Admin panel | Svelte 5 (Vite SPA) |
| Infra | Docker Compose (PostgreSQL 16 + services), local-FS object storage with an S3-ready trait |
| AI pipeline | Provider-agnostic traits (STT → summary → exercises → quiz) with a mock provider |

## Repository layout

```
buddywize/
├── backend/                 # Rust workspace (modular monolith, one deployable per service later)
│   ├── crates/
│   │   ├── buddywize-core/        # shared domain types, errors, DB rows
│   │   ├── buddywize-auth/        # JWT auth, refresh rotation, RBAC
│   │   ├── buddywize-courses/     # agenda / courses / lessons / chapters + delta sync
│   │   ├── buddywize-recordings/  # resumable chunked uploads + storage backend
│   │   ├── buddywize-ai/          # STT/summary/quiz traits, mock provider, pipeline worker
│   │   ├── buddywize-admin/       # admin-scoped endpoints (users, moderation, health)
│   │   └── buddywize-api/         # Axum binary wiring everything together + OpenAPI
│   └── migrations/          # SQLx migrations (embedded, run at startup)
├── mobile/                  # Flutter app (offline-first)
└── admin/                   # Svelte admin panel
```

### Architecture notes vs. the spec

- **Modular monolith first.** The spec draws separate Auth / Course / Recording+AI services.
  They are implemented as separate crates with clean boundaries behind a single Axum binary,
  so each can be split into its own container later without refactoring business logic.
- **Object storage.** `StorageBackend` trait with two implementations:
  - `LocalFsStorage` — volume-mounted filesystem (default for dev / single-node).
  - `R2Storage` — Cloudflare R2 over the S3 API (production). Selected at boot
    by setting `R2_BUCKET` + `R2_ACCOUNT_ID` + `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY`.
    The upload chunk is created via `CreateMultipartUpload` / `UploadPart` /
    `CompleteMultipartUpload` so partial uploads survive app restarts.
- **AI providers.** `SttProvider` / `StudyMaterialGenerator` traits; `MockProvider` is wired
  by default. Real providers (Whisper-class STT, LLM summarization) implement the same traits.

## Quick start

Prereqs: Docker, Rust (stable), Flutter, Node.js.

```bash
# 1. Infrastructure (PostgreSQL)
docker compose up -d postgres

# 2. Backend (runs migrations at startup, serves API + Swagger UI)
cd backend
cp .env.example .env
cargo run -p buddywize-api
# API: http://localhost:7878/api   |   Swagger UI: http://localhost:7878/docs

# 3. Admin panel
cd admin
npm install
npm run dev          # http://localhost:5173

# 4. Mobile app
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter create . --platforms android,ios   # once, to materialize platform folders
flutter run
```

Everything except Postgres also runs without Docker (see `backend/.env.example`).

## Key behaviors implemented in this scaffold

**Offline-first sync contract**
- Client-generated UUIDs on every entity; write endpoints are idempotent
  (`ON CONFLICT (client_uuid) DO UPDATE`).
- Global monotonically increasing `sync_version` (Postgres sequence); all list endpoints
  accept `?since=<cursor>` for delta sync, and deleted rows are soft-deleted so deltas
  carry deletions.
- `GET /api/sync/status?since=` for a cheap "what changed" probe.

**Recording pipeline**
- Resumable chunked upload: create upload session → PUT chunks at offsets → complete.
- On completion a job is enqueued: entitlement check → STT → summary + exercises + quiz.
- Generated content lands as `pending_review` and is published via admin approval
  (moderation step from the spec).

**Subscription / entitlements**
- 7-day trial started on registration; `monthly` / `annual` plans and discount-code table.
- Lapsed entitlement blocks *new AI processing*, never access to already-owned content.

## Open decisions carried over from the spec

Billing rails (App Store / Play Billing vs. Stripe), discount-code mechanics, institutional
pricing, trial-abuse prevention, push-notification provider, production orchestrator, and the
object-storage provider. See `docs/TECH_SPEC.md` §11.
