//! AI orchestration: speech-to-text, agenda parsing, then summarization /
//! exercise / quiz generation. Providers are abstracted behind traits;
//! deterministic mock providers exist for offline dev.

pub mod cloudflare_agenda;
pub mod cloudflare_whisper;
pub mod deepseek;
pub mod ical;
pub mod mock;
pub mod pipeline;
pub mod providers;
pub mod whisper;

pub use cloudflare_agenda::{CloudflareAgendaConfig, CloudflareAgendaParser};
pub use cloudflare_whisper::{CloudflareWhisperConfig, CloudflareWhisperStt};
pub use deepseek::{DeepSeekConfig, DeepSeekStudyGenerator};
pub use providers::{
    AgendaItemDraft, AgendaParser, Exercise, GeneratedContent, QuizQuestion, SttProvider,
    StudyGenerator, Transcript, TranscriptSegment,
};
pub use whisper::{WhisperConfig, WhisperStt};

pub use ical::parse_ical;
