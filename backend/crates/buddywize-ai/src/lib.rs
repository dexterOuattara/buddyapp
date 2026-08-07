//! AI orchestration: speech-to-text, then summarization / exercise / quiz
//! generation. Providers are abstracted behind traits; a deterministic mock
//! provider is wired by default so the pipeline runs end-to-end with no
//! external API keys. Real providers (e.g. a hosted STT + an LLM) implement
//! the same traits.

pub mod cloudflare_whisper;
pub mod deepseek;
pub mod mock;
pub mod pipeline;
pub mod providers;
pub mod whisper;

pub use cloudflare_whisper::{CloudflareWhisperConfig, CloudflareWhisperStt};
pub use deepseek::{DeepSeekConfig, DeepSeekStudyGenerator};
pub use providers::{
    Exercise, GeneratedContent, QuizQuestion, SttProvider, StudyGenerator, Transcript,
};
pub use whisper::{WhisperConfig, WhisperStt};