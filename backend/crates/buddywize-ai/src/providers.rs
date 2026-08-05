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
