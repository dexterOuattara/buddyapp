//! BuddyWize API gateway: wires auth, courses, recordings, admin, the AI
//! pipeline worker, delta-sync status, and the OpenAPI/Swagger UI.

mod sync;

use std::sync::Arc;

use axum::{routing::get, Router};
use buddywize_admin::AdminState;
use buddywize_ai::mock::{MockStt, MockStudyGenerator};
use buddywize_ai::pipeline::Pipeline;
use buddywize_ai::providers::SttProvider;
use buddywize_ai::{WhisperConfig, WhisperStt};
use buddywize_auth::{AuthState, JwtConfig};
use buddywize_core::{job_channel, storage};
use buddywize_courses::CourseState;
use buddywize_recordings::RecordingState;
use sqlx::postgres::PgPoolOptions;
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

#[derive(OpenApi)]
#[openapi(
    info(
        title = "BuddyWize API",
        version = "0.1.0",
        description = "Offline-first course companion: agenda, courses, recordings, AI study material.",
    ),
    paths(
        // auth
        buddywize_auth::handlers::register,
        buddywize_auth::handlers::login,
        buddywize_auth::handlers::refresh,
        buddywize_auth::handlers::me,
        // agenda / structure
        buddywize_courses::handlers::list_agenda,
        buddywize_courses::handlers::upsert_agenda,
        buddywize_courses::handlers::delete_agenda,
        buddywize_courses::handlers::list_courses,
        buddywize_courses::handlers::upsert_course,
        buddywize_courses::handlers::delete_course,
        buddywize_courses::handlers::list_lessons,
        buddywize_courses::handlers::upsert_lesson,
        buddywize_courses::handlers::delete_lesson,
        buddywize_courses::handlers::list_chapters,
        buddywize_courses::handlers::upsert_chapter,
        buddywize_courses::handlers::delete_chapter,
        // study material
        buddywize_courses::study::delta,
        buddywize_courses::study::record_attempt,
        buddywize_courses::study::list_attempts,
        // recordings
        buddywize_recordings::handlers::list_recordings,
        buddywize_recordings::handlers::create_upload,
        buddywize_recordings::handlers::upload_chunk,
        buddywize_recordings::handlers::complete_upload,
        buddywize_recordings::handlers::reprocess,
        // sync
        sync::status,
        // admin
        buddywize_admin::list_users,
        buddywize_admin::set_user_role,
        buddywize_admin::list_recordings,
        buddywize_admin::recording_detail,
        buddywize_admin::recording_audio,
        buddywize_admin::list_pending_moderation,
        buddywize_admin::decide_summary,
        buddywize_admin::decide_exercises,
        buddywize_admin::decide_quiz,
    ),
    components(schemas(
        // auth
        buddywize_auth::handlers::CredentialsRequest,
        buddywize_auth::handlers::UserDto,
        buddywize_auth::handlers::SubscriptionDto,
        buddywize_auth::handlers::AuthResponse,
        buddywize_auth::handlers::MeResponse,
        buddywize_auth::handlers::RefreshRequest,
        // structure
        buddywize_courses::AgendaRow,
        buddywize_courses::CourseRow,
        buddywize_courses::LessonRow,
        buddywize_courses::ChapterRow,
        buddywize_courses::handlers::AgendaUpsert,
        buddywize_courses::handlers::CourseUpsert,
        buddywize_courses::handlers::LessonUpsert,
        buddywize_courses::handlers::ChapterUpsert,
        // study
        buddywize_courses::study::SummaryDto,
        buddywize_courses::study::ExercisesDto,
        buddywize_courses::study::QuizDto,
        buddywize_courses::study::StudyDelta,
        buddywize_courses::study::AttemptRequest,
        buddywize_courses::study::AttemptRow,
        // recordings
        buddywize_recordings::handlers::RecordingDto,
        buddywize_recordings::handlers::CreateUploadRequest,
        buddywize_recordings::handlers::UploadSessionDto,
        buddywize_recordings::handlers::ReprocessResponse,
        // sync
        sync::SyncStatusResponse,
        // admin
        buddywize_admin::AdminUserRow,
        buddywize_admin::SetRoleRequest,
        buddywize_admin::AdminRecordingRow,
        buddywize_admin::AudioMeta,
        buddywize_admin::RecordingDetailDto,
        buddywize_admin::PendingItem,
        buddywize_admin::ModerationDecision,
    ))
)]
struct ApiDoc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "buddywize=debug,tower_http=info".into()),
        )
        .init();

    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://buddywize:buddywize_dev@localhost:5432/buddywize".into());
    let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".into());
    let port: u16 = std::env::var("PORT").unwrap_or_else(|_| "7878".into()).parse()?;
    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "dev-secret-change-me".into());
    let admin_email = std::env::var("ADMIN_EMAIL").unwrap_or_else(|_| "admin@buddywize.local".into());
    let admin_password = std::env::var("ADMIN_PASSWORD").unwrap_or_else(|_| "admin-buddywize".into());

    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;

    sqlx::migrate!("../../migrations").run(&db).await?;
    tracing::info!("migrations applied");

    // Seed a default admin (idempotent).
    buddywize_auth::handlers::seed_admin(&db, &admin_email, &admin_password).await?;

    // Object storage: R2 if `R2_BUCKET` is set, otherwise local filesystem.
    let storage = storage::from_env().await?;

    // Speech-to-text provider. `WHISPER_MODEL=disabled` keeps the mock;
    // any other value (or unset) defaults to `faster-whisper` with `large-v3`.
    let stt: Arc<dyn SttProvider> = match std::env::var("WHISPER_MODEL").as_deref() {
        Ok("disabled") | Ok("mock") | Ok("off") => {
            tracing::info!("using mock STT provider");
            Arc::new(MockStt)
        }
        _ => {
            let cfg = WhisperConfig::from_env()?;
            tracing::info!(
                model = %cfg.model,
                device = %cfg.device,
                compute_type = %cfg.compute_type,
                script = %cfg.script.display(),
                "using faster-whisper STT provider"
            );
            Arc::new(WhisperStt::new(cfg))
        }
    };

    let (jobs_tx, jobs_rx) = job_channel(100);
    let pipeline = Pipeline::new(
        db.clone(),
        storage.clone(),
        stt,
        Arc::new(MockStudyGenerator),
    );
    tokio::spawn(pipeline.run(jobs_rx));

    let jwt = JwtConfig {
        secret: jwt_secret.clone(),
        access_ttl_secs: 15 * 60,
        refresh_ttl_days: 30,
    };

    let auth_state = AuthState { db: db.clone(), jwt };
    let course_state = CourseState { db: db.clone() };
    let recording_state = RecordingState { db: db.clone(), storage: storage.clone(), jobs: jobs_tx };
    let admin_state = AdminState { db: db.clone(), storage: storage.clone() };
    let sync_state = sync::SyncState { db: db.clone() };

    // Sub-routers each own their state; everything merged below is Router<()>.
    let sync_router = Router::new()
        .route("/sync/status", get(sync::status))
        .with_state(sync_state);

    // Admin routes additionally require the admin role (runs after require_auth).
    let admin_router = buddywize_admin::router(admin_state)
        .layer(axum::middleware::from_fn(
            buddywize_auth::middleware::require_admin,
        ));

    // Protected API: everything except register/login/refresh needs a Bearer token.
    let protected = Router::new()
        .merge(buddywize_auth::protected_router(auth_state.clone()))
        .merge(buddywize_courses::router(course_state))
        .merge(buddywize_recordings::router(recording_state))
        .merge(sync_router)
        .merge(admin_router)
        .layer(axum::middleware::from_fn_with_state(
            auth_state.clone(),
            buddywize_auth::middleware::require_auth,
        ));

    let api = Router::new()
        .merge(buddywize_auth::public_router(auth_state.clone()))
        .merge(protected);

    let app = Router::new()
        .nest("/api", api)
        .route("/health", get(|| async { "ok" }))
        .merge(SwaggerUi::new("/docs").url("/api-docs/openapi.json", ApiDoc::openapi()))
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .layer(
            tower_http::cors::CorsLayer::new()
                .allow_origin(tower_http::cors::Any)
                .allow_methods(tower_http::cors::Any)
                .allow_headers(tower_http::cors::Any),
        );

    let addr: std::net::SocketAddr = format!("{host}:{port}").parse()?;
    tracing::info!(%addr, "BuddyWize API listening");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
