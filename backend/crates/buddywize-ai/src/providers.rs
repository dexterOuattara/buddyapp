//! Provider contracts + data types for the AI pipeline.

use async_trait::async_trait;
use serde::{Deserialize, Serialize};

/// Result of speech-to-text over a lesson recording.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transcript {
    pub text: String,
    /// Detected language (BCP-47) if the provider reports it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
}

/// A single practice exercise.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Exercise {
    pub prompt: String,
    /// Optional hint or worked guidance.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub guidance: Option<String>,
    /// Reference answer, if the exercise is answerable.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub answer: Option<String>,
}

/// A multiple-choice quiz question.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuizQuestion {
    pub prompt: String,
    pub choices: Vec<String>,
    /// Index into `choices` of the correct answer.
    pub correct_index: i32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub explanation: Option<String>,
}

/// Everything the study-material stage produces for a chapter.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeneratedContent {
    pub summary_markdown: String,
    pub exercises: Vec<Exercise>,
    pub quiz: Vec<QuizQuestion>,
}

/// Speech-to-text provider.
#[async_trait]
pub trait SttProvider: Send + Sync {
    /// Stable provider name, stored alongside transcripts.
    fn name(&self) -> &str;
    /// Transcribe raw audio bytes.
    async fn transcribe(&self, audio: &[u8]) -> anyhow::Result<Transcript>;
}

/// Summarization / exercise / quiz generator.
#[async_trait]
pub trait StudyGenerator: Send + Sync {
    /// Stable provider name, for observability.
    fn name(&self) -> &str;
    /// Produce study material for a chapter given its transcript.
    async fn generate(
        &self,
        chapter_title: &str,
        transcript: &Transcript,
    ) -> anyhow::Result<GeneratedContent>;
}

/// One agenda item extracted from a photo (OCR) or an iCal feed.
///
/// The mobile app shows a confirmation screen with a list of these;
/// the user edits and confirms, then we upsert each into
/// `agenda_items` via the existing `POST /api/agenda` endpoint.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, utoipa::ToSchema)]
pub struct AgendaItemDraft {
    pub title: String,
    /// ISO 8601 / RFC 3339 timestamp, if the source had a clear date+time.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub starts_at: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ends_at: Option<String>,
    /// Free-form annotation: room number, teacher, etc.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
}

impl AgendaItemDraft {
    /// Sanity-check a draft before we hand it to the mobile. Drops items
    /// with empty / absurdly long titles; truncates notes; drops items
    /// whose date fields look like garbage.
    pub fn sanitized(self) -> Option<Self> {
        let title = self.title.trim();
        if title.is_empty() || title.len() > 200 {
            return None;
        }
        let starts_at = self
            .starts_at
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string);
        let ends_at = self
            .ends_at
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string);
        let notes = self
            .notes
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty() && s.len() <= 500)
            .map(str::to_string);
        Some(Self {
            title: title.to_string(),
            starts_at,
            ends_at,
            notes,
        })
    }
}

/// Agenda parser (OCR photo or iCal feed).
#[async_trait]
pub trait AgendaParser: Send + Sync {
    /// Stable provider name, for observability.
    fn name(&self) -> &str;
    /// Extract agenda item drafts from the given bytes. The bytes are
    /// either a JPEG/PNG image of a paper agenda (OCR path) or an
    /// iCal/ICS text (calendar path) — the caller decides which.
    async fn parse(&self, input: &[u8]) -> anyhow::Result<Vec<AgendaItemDraft>>;
}
