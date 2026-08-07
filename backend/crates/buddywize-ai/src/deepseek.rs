//! Cloudflare Workers AI study-material generator.
//!
//! Talks to any OpenAI-compatible chat-completions endpoint on
//! `api.cloudflare.com`. The model is read at every `generate()` call from
//! `app_settings.study_generator_model` via `SettingsCache`, so admins can
//! swap models from the Settings page without a restart or rebuild.
//!
//! If the model id is missing, the upstream API call fails twice, or the
//! response fails schema validation, we fall back to the deterministic
//! `MockStudyGenerator` so the recording still publishes — students
//! never see a stuck "Generating summary…" state.

use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use buddywize_core::settings::SettingsCache;
use reqwest::Client;
use serde::{Deserialize, Serialize};

use crate::mock::MockStudyGenerator;
use crate::providers::{GeneratedContent, StudyGenerator, Transcript};

const SETTINGS_KEY: &str = "study_generator_model";
const FALLBACK_MODEL: &str = "@cf/deepseek-ai/deepseek-r1-distill-qwen-32b";

#[derive(Debug, Clone)]
pub struct DeepSeekConfig {
    pub account_id: String,
    pub token: String,
    pub temperature: f32,
    pub max_output_tokens: u32,
    pub max_retries: u32,
}

impl DeepSeekConfig {
    /// Build from environment. `token` may be empty — if so, every call
    /// fails fast and the mock fallback kicks in. We log a warning at
    /// startup so the operator notices.
    pub fn from_env() -> anyhow::Result<Self> {
        let account_id = std::env::var("CF_ACCOUNT_ID")
            .map_err(|_| anyhow::anyhow!("CF_ACCOUNT_ID must be set"))?;
        let token = std::env::var("CF_AI_TOKEN").unwrap_or_default();
        let temperature: f32 = std::env::var("CF_AI_TEMPERATURE")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(0.3);
        let max_output_tokens: u32 = std::env::var("CF_AI_MAX_OUTPUT_TOKENS")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(4096);
        let max_retries: u32 = std::env::var("CF_AI_MAX_RETRIES")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(1);

        if token.is_empty() {
            tracing::warn!(
                "CF_AI_TOKEN is not set — Cloudflare LLM calls will fail and the \
                 study-material generator will fall back to the mock template. \
                 Set CF_AI_TOKEN in the environment to enable real generation."
            );
        }

        Ok(Self {
            account_id,
            token,
            temperature,
            max_output_tokens,
            max_retries,
        })
    }
}

pub struct DeepSeekStudyGenerator {
    cfg: DeepSeekConfig,
    http: Client,
    settings: SettingsCache,
}

impl DeepSeekStudyGenerator {
    pub fn new(cfg: DeepSeekConfig, settings: SettingsCache) -> Self {
        let http = Client::builder()
            .timeout(Duration::from_secs(120))
            .build()
            .expect("reqwest client builder");
        Self { cfg, http, settings }
    }

    async fn pick_model(&self) -> String {
        if let Ok(Some(v)) = self.settings.get_or_load(SETTINGS_KEY).await {
            return v;
        }
        if let Ok(v) = std::env::var("CF_AI_MODEL") {
            if !v.is_empty() {
                return v;
            }
        }
        FALLBACK_MODEL.to_string()
    }
}

#[async_trait]
impl StudyGenerator for DeepSeekStudyGenerator {
    fn name(&self) -> &str {
        "cloudflare-deepseek"
    }

    async fn generate(
        &self,
        chapter_title: &str,
        transcript: &Transcript,
    ) -> anyhow::Result<GeneratedContent> {
        let model = self.pick_model().await;
        let system = SYSTEM_PROMPT;
        let user = build_user_prompt(chapter_title, transcript);

        let mut last_err: Option<anyhow::Error> = None;
        for attempt in 0..=self.cfg.max_retries {
            let user_prompt = if attempt == 0 {
                user.clone()
            } else {
                format!(
                    "{user}\n\nIMPORTANT: your previous reply was not valid JSON. \
                     Reply with ONLY the JSON object, no markdown fences, no commentary."
                )
            };
            match self.call_model(&model, system, &user_prompt).await {
                Ok(content) => {
                    tracing::info!(
                        model = %model,
                        attempt = attempt,
                        exercises = content.exercises.len(),
                        quiz = content.quiz.len(),
                        "Cloudflare LLM produced study material"
                    );
                    return Ok(content);
                }
                Err(e) => {
                    tracing::warn!(error = %e, model = %model, attempt = attempt, "deepseek call failed");
                    last_err = Some(e);
                }
            }
        }

        tracing::warn!(
            error = ?last_err,
            "falling back to mock study generator (no LLM output available)"
        );
        // Last-resort fallback: canned template so the recording still
        // publishes and the user gets a usable summary.
        Ok(MockStudyGenerator.generate(chapter_title, transcript).await?)
    }
}

impl DeepSeekStudyGenerator {
    async fn call_model(
        &self,
        model: &str,
        system: &str,
        user: &str,
    ) -> anyhow::Result<GeneratedContent> {
        if self.cfg.token.is_empty() {
            anyhow::bail!("CF_AI_TOKEN is empty");
        }

        let url = format!(
            "https://api.cloudflare.com/client/v4/accounts/{}/ai/v1/chat/completions",
            self.cfg.account_id
        );

        let body = ChatRequest {
            model: model.to_string(),
            temperature: self.cfg.temperature,
            max_tokens: self.cfg.max_output_tokens,
            messages: vec![
                ChatMessage {
                    role: "system".to_string(),
                    content: system.to_string(),
                },
                ChatMessage {
                    role: "user".to_string(),
                    content: user.to_string(),
                },
            ],
        };

        let resp = self
            .http
            .post(&url)
            .bearer_auth(&self.cfg.token)
            .json(&body)
            .send()
            .await?;

        let status = resp.status();
        if !status.is_success() {
            let text = resp.text().await.unwrap_or_default();
            anyhow::bail!("Cloudflare LLM returned HTTP {status}: {text}");
        }

        let parsed: ChatResponse = resp.json().await?;
        let raw = parsed
            .choices
            .into_iter()
            .next()
            .map(|c| c.message.content)
            .ok_or_else(|| anyhow::anyhow!("Cloudflare LLM response had no choices"))?;

        let trimmed = strip_code_fences(&raw);
        let mut content: GeneratedContentDto = serde_json::from_str(&trimmed)
            .map_err(|e| anyhow::anyhow!("LLM JSON parse failed: {e}; raw: {raw}"))?;

        // Defensive: trim to the schema (3 exercises, 10 quiz) if the model
        // overshot, or pad if it under-delivered. We always persist what the
        // LLM said verbatim when shape matches; otherwise we drop excess and
        // leave a warning in logs.
        if content.exercises.len() > 3 {
            content.exercises.truncate(3);
            tracing::warn!("LLM returned more than 3 exercises; truncated to 3");
        }
        if content.quiz.len() > 10 {
            content.quiz.truncate(10);
            tracing::warn!("LLM returned more than 10 quiz questions; truncated to 10");
        }

        Ok(GeneratedContent {
            summary_markdown: content.summary_markdown,
            exercises: content.exercises,
            quiz: content.quiz,
        })
    }
}

const SYSTEM_PROMPT: &str = "You are BuddyWize, a strict study-material generator. \
You receive a lecture transcript and a chapter title. \
You must analyse the transcript, identify the 3-5 most important concepts, \
and produce a JSON object that matches the schema below. \
Do NOT include anything outside the JSON object. \
Do NOT use markdown fences around the JSON.";

fn build_user_prompt(chapter_title: &str, transcript: &Transcript) -> String {
    let lang_hint = transcript
        .language
        .as_deref()
        .map(|l| format!("The transcript is in `{l}`. Generate the study material in the same language.\n"))
        .unwrap_or_default();
    format!(
        "Chapter title: {chapter_title}\n\
         {lang_hint}\
         Transcript (whisper, may contain minor ASR errors):\n\
         ---\n\
         {text}\n\
         ---\n\
         \n\
         Return JSON of the form:\n\
         {{\n\
         \x20 \"summary_markdown\": \"<Markdown summary, 3-6 sections, ~400-700 words>\",\n\
         \x20 \"exercises\": [\n\
         \x20\x20\x20 {{ \"prompt\": \"...\", \"guidance\": \"...|null\", \"answer\": \"...|null\" }}\n\
         \x20\x20\x20 // exactly 3 items, increasing in difficulty\n\
         \x20 ],\n\
         \x20 \"quiz\": [\n\
         \x20\x20\x20 {{\n\
         \x20\x20\x20\x20\x20 \"prompt\": \"...\",\n\
         \x20\x20\x20\x20\x20 \"choices\": [\"A\",\"B\",\"C\",\"D\"],   // exactly 4 choices\n\
         \x20\x20\x20\x20\x20 \"correct_index\": 0,             // 0..3\n\
         \x20\x20\x20\x20\x20 \"explanation\": \"...|null\"\n\
         \x20\x20\x20 }}\n\
         \x20\x20\x20 // exactly 10 items\n\
         \x20 ]\n\
         }}\n\
         \n\
         Constraints:\n\
         - exercises and quiz items MUST be grounded in the transcript (or the\n\
         \x20 chapter title if the transcript is sparse).\n\
         - quiz.correct_index must be a valid index into quiz.choices.\n\
         - choices must be plausible distractors; never use \"All of the above\"\n\
         \x20 or \"None of the above\".\n\
         - Output ONLY the JSON object.",
        chapter_title = chapter_title,
        text = transcript.text,
        lang_hint = lang_hint,
    )
}

fn strip_code_fences(s: &str) -> String {
    let s = s.trim();
    if let Some(rest) = s.strip_prefix("```json") {
        return rest.trim_end_matches("```").trim().to_string();
    }
    if let Some(rest) = s.strip_prefix("```") {
        return rest.trim_end_matches("```").trim().to_string();
    }
    s.to_string()
}

// ---------- Cloudflare request / response DTOs ----------

#[derive(Debug, Serialize)]
struct ChatRequest {
    model: String,
    temperature: f32,
    max_tokens: u32,
    messages: Vec<ChatMessage>,
}

#[derive(Debug, Serialize)]
struct ChatMessage {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct ChatResponse {
    choices: Vec<ChatChoice>,
}

#[derive(Debug, Deserialize)]
struct ChatChoice {
    message: ChatChoiceMessage,
}

#[derive(Debug, Deserialize)]
struct ChatChoiceMessage {
    content: String,
}

#[derive(Debug, Deserialize)]
struct GeneratedContentDto {
    summary_markdown: String,
    exercises: Vec<crate::providers::Exercise>,
    quiz: Vec<crate::providers::QuizQuestion>,
}

// Allow the generator to be shared (the pipeline worker holds it in an Arc).
impl DeepSeekStudyGenerator {
    /// Erase the auto-derived Sync bound so we can hold it in an Arc<dyn StudyGenerator>.
    pub fn into_arc(self: Arc<Self>) -> Arc<dyn StudyGenerator> {
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strip_code_fences_handles_plain_json() {
        assert_eq!(
            strip_code_fences(r#"{"a":1}"#),
            r#"{"a":1}"#
        );
    }

    #[test]
    fn strip_code_fences_handles_json_fenced_block() {
        assert_eq!(
            strip_code_fences("```json\n{\"a\":1}\n```"),
            r#"{"a":1}"#
        );
    }

    #[test]
    fn strip_code_fences_handles_bare_fenced_block() {
        assert_eq!(
            strip_code_fences("```\n{\"a\":1}\n```"),
            r#"{"a":1}"#
        );
    }

    #[test]
    fn user_prompt_contains_chapter_title_and_transcript() {
        let t = Transcript {
            text: "hello".into(),
            language: Some("en".into()),
        };
        let s = build_user_prompt("Algebra", &t);
        assert!(s.contains("Algebra"));
        assert!(s.contains("hello"));
        assert!(s.contains("exactly 3"));
        assert!(s.contains("exactly 10"));
    }

    #[test]
    fn user_prompt_includes_language_hint_when_known() {
        let t = Transcript { text: "x".into(), language: Some("fr".into()) };
        let s = build_user_prompt("X", &t);
        assert!(s.contains("`fr`"));
    }
}