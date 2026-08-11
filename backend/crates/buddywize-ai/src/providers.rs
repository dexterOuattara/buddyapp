//! Provider contracts + data types for the AI pipeline.

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::{future::Future, pin::Pin};

pub type SttProgressFuture<'a> = Pin<Box<dyn Future<Output = ()> + Send + 'a>>;
pub type SttProgressCallback<'a> = dyn FnMut(usize, usize) -> SttProgressFuture<'a> + Send + 'a;

/// A single spoken word aligned with the recording timeline.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TranscriptWord {
    pub start_ms: i64,
    pub end_ms: i64,
    pub text: String,
}

/// A sentence-sized transcript cue aligned with the recording timeline.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TranscriptSegment {
    pub start_ms: i64,
    pub end_ms: i64,
    pub text: String,
    /// Word-level cues used for karaoke-style playback. Older providers may
    /// omit these; clients can fall back to the enclosing segment.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub words: Vec<TranscriptWord>,
}

/// Produce a deterministic word progression when a provider only returns a
/// sentence-level timestamp. Durations are weighted by character count so
/// longer words remain highlighted for slightly longer.
pub fn estimate_word_timings(text: &str, start_ms: i64, end_ms: i64) -> Vec<TranscriptWord> {
    if end_ms <= start_ms {
        return Vec::new();
    }
    let words = text
        .split_whitespace()
        .map(str::trim)
        .filter(|word| !word.is_empty())
        .collect::<Vec<_>>();
    if words.is_empty() {
        return Vec::new();
    }

    let weights = words
        .iter()
        .map(|word| word.chars().count().max(1) as i64)
        .collect::<Vec<_>>();
    let word_count = words.len();
    let total_weight = weights.iter().sum::<i64>().max(1);
    let duration = end_ms - start_ms;
    let mut elapsed_weight = 0_i64;

    words
        .into_iter()
        .zip(weights)
        .enumerate()
        .map(|(index, (word, weight))| {
            let word_start =
                (start_ms + duration * elapsed_weight / total_weight).clamp(start_ms, end_ms - 1);
            elapsed_weight += weight;
            let word_end = if index + 1 == word_count {
                end_ms
            } else {
                start_ms + duration * elapsed_weight / total_weight
            };
            TranscriptWord {
                start_ms: word_start,
                end_ms: word_end.max(word_start + 1).min(end_ms),
                text: word.to_string(),
            }
        })
        .collect()
}

/// Result of speech-to-text over a lesson recording.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transcript {
    pub text: String,
    /// Detected language (BCP-47) if the provider reports it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    /// Sentence-sized cues used by the mobile player for synchronized text.
    #[serde(default)]
    pub segments: Vec<TranscriptSegment>,
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
    /// Concept used to group the result breakdown in the mobile app.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub topic: Option<String>,
    pub choices: Vec<String>,
    /// Index into `choices` of the correct answer.
    pub correct_index: i32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub explanation: Option<String>,
}

/// A short active-recall card displayed next to the generated summary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Flashcard {
    pub front: String,
    pub back: String,
}

/// Everything the study-material stage produces for a chapter.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeneratedContent {
    pub summary_markdown: String,
    #[serde(default)]
    pub key_points: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub takeaway: Option<String>,
    #[serde(default)]
    pub flashcards: Vec<Flashcard>,
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

    /// Report completed/total audio chunks while transcribing. Providers that
    /// do not split audio still expose the honest 0/1 → 1/1 lifecycle.
    async fn transcribe_with_progress(
        &self,
        audio: &[u8],
        progress: &mut SttProgressCallback<'_>,
    ) -> anyhow::Result<Transcript> {
        progress(0, 1).await;
        let transcript = self.transcribe(audio).await?;
        progress(1, 1).await;
        Ok(transcript)
    }
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
