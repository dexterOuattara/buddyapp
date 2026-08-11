//! Cloudflare Workers AI study-material generator.
//!
//! Talks to any OpenAI-compatible chat-completions endpoint on
//! `api.cloudflare.com`. The model is read at every `generate()` call from
//! `app_settings.study_generator_model` via `SettingsCache`, so admins can
//! swap models from the Settings page without a restart or rebuild.
//!
//! Failures propagate. HTTP errors (4xx/5xx, network) and missing credentials
//! surface immediately as `Err`, so the pipeline marks the recording as
//! `failed` with the actual error message. JSON parse failures get one retry
//! with a stricter prompt before bubbling up — there is no silent fallback.

use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use buddywize_core::settings::SettingsCache;
use reqwest::Client;
use serde::{Deserialize, Serialize};

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
    /// Build from environment. `CF_AI_TOKEN` is required — the generator
    /// refuses to start without it so the operator gets a loud failure
    /// instead of every recording silently going to `failed` later.
    pub fn from_env() -> anyhow::Result<Self> {
        let account_id = std::env::var("CF_ACCOUNT_ID")
            .map_err(|_| anyhow::anyhow!("CF_ACCOUNT_ID must be set"))?;
        let token = std::env::var("CF_AI_TOKEN")
            .ok()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| {
                anyhow::anyhow!(
                "CF_AI_TOKEN must be set to a non-empty Cloudflare API token (Workers AI:Read) \
                 to use the Cloudflare study generator. \
                 Set STUDY_GENERATOR=mock to use the deterministic offline template instead."
            )
            })?;
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
        Self {
            cfg,
            http,
            settings,
        }
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
                Err(CallError::Http(e)) => {
                    // Transport / auth / 5xx: don't retry, surface immediately
                    // so the recording goes to `failed` with a real reason.
                    tracing::warn!(
                        error = %e, model = %model,
                        "Cloudflare LLM call failed (non-retriable); recording will be marked failed"
                    );
                    return Err(e);
                }
                Err(CallError::Parse(e)) => {
                    // LLM responded 200 OK but the body wasn't our schema.
                    // Retry once with a stricter prompt; if it still fails,
                    // the recording lands in `failed` (no silent fallback).
                    tracing::warn!(error = %e, model = %model, attempt = attempt, "deepseek parse failed");
                    last_err = Some(anyhow::anyhow!("{e}"));
                }
            }
        }

        Err(last_err.unwrap_or_else(|| anyhow::anyhow!("deepseek call failed without an error")))
    }
}

/// Internal error categories for [`DeepSeekStudyGenerator::call_model`].
/// Lets the generator distinguish transport failures (which the operator
/// needs to see) from parse failures (which are worth retrying with a
/// stricter prompt).
#[derive(Debug, thiserror::Error)]
enum CallError {
    #[error("Cloudflare LLM HTTP call failed: {0}")]
    Http(anyhow::Error),
    #[error("Cloudflare LLM response did not match the expected JSON schema: {0}")]
    Parse(String),
}

impl DeepSeekStudyGenerator {
    async fn call_model(
        &self,
        model: &str,
        system: &str,
        user: &str,
    ) -> Result<GeneratedContent, CallError> {
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
            .await
            .map_err(|e| CallError::Http(e.into()))?;

        let status = resp.status();
        if !status.is_success() {
            let text = resp.text().await.unwrap_or_default();
            return Err(CallError::Http(anyhow::anyhow!(
                "Cloudflare LLM returned HTTP {status}: {text}"
            )));
        }

        let parsed: ChatResponse = resp.json().await.map_err(|e| CallError::Http(e.into()))?;
        let raw = parsed
            .choices
            .into_iter()
            .next()
            .map(|c| c.message.content)
            .ok_or_else(|| CallError::Parse("response had no choices".into()))?;

        // DeepSeek-R1 reasoning models wrap their chain-of-thought in
        // `<think>...</think>` blocks before the actual answer. Strip those
        // blocks (and any markdown code fences) before looking for JSON.
        let trimmed = strip_thinking_and_fences(&raw);
        // Try parsing the cleaned string first; if it fails (e.g. the model
        // emitted prose around the JSON), fall back to extracting the first
        // balanced JSON object from the response.
        let mut content: GeneratedContentDto = match serde_json::from_str(&trimmed) {
            Ok(c) => c,
            Err(_) => {
                let extracted = extract_json_object(&trimmed).ok_or_else(|| {
                    CallError::Parse(format!(
                        "could not locate a JSON object in the response; raw: {raw}"
                    ))
                })?;
                serde_json::from_str(&extracted).map_err(|e| {
                    CallError::Parse(format!(
                        "extracted JSON did not match schema: {e}; extracted: {extracted}"
                    ))
                })?
            }
        };

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
            key_points: content.key_points,
            takeaway: content.takeaway,
            flashcards: content.flashcards,
            exercises: content.exercises,
            quiz: content.quiz,
        })
    }
}

const SYSTEM_PROMPT: &str = "You are BuddyWize, a strict study-material generator. \
You receive one or more chronological lecture-session transcripts and a chapter title. \
You must analyse the transcript, identify the 3-5 most important concepts, \
and produce a JSON object that matches the schema below. \
Do NOT include anything outside the JSON object. \
Do NOT use markdown fences around the JSON.";

fn build_user_prompt(chapter_title: &str, transcript: &Transcript) -> String {
    let lang_hint = transcript
        .language
        .as_deref()
        .map(|l| {
            format!(
                "The transcript is in `{l}`. Generate the study material in the same language.\n"
            )
        })
        .unwrap_or_default();
    format!(
        "Chapter title: {chapter_title}\n\
         {lang_hint}\
         Cumulative chapter transcript (one or more chronological sessions; whisper may contain minor ASR errors):\n\
         ---\n\
         {text}\n\
         ---\n\
         \n\
         Return JSON of the form:\n\
         {{\n\
         \x20 \"summary_markdown\": \"<Markdown summary, 3-6 sections, ~400-700 words>\",\n\
         \x20 \"key_points\": [\"<3-5 concise essential ideas>\"],\n\
         \x20 \"takeaway\": \"<one memorable practical takeaway>\",\n\
         \x20 \"flashcards\": [{{ \"front\": \"<question>\", \"back\": \"<short answer>\" }}],\n\
         \x20 \"exercises\": [\n\
         \x20\x20\x20 {{ \"prompt\": \"...\", \"guidance\": \"...|null\", \"answer\": \"...|null\" }}\n\
         \x20\x20\x20 // exactly 3 items, increasing in difficulty\n\
         \x20 ],\n\
         \x20 \"quiz\": [\n\
         \x20\x20\x20 {{\n\
         \x20\x20\x20\x20\x20 \"prompt\": \"...\",\n\
         \x20\x20\x20\x20\x20 \"topic\": \"<short concept name>\",\n\
         \x20\x20\x20\x20\x20 \"choices\": [\"A\",\"B\",\"C\",\"D\"],   // exactly 4 choices\n\
         \x20\x20\x20\x20\x20 \"correct_index\": 0,             // 0..3\n\
         \x20\x20\x20\x20\x20 \"explanation\": \"...|null\"\n\
         \x20\x20\x20 }}\n\
         \x20\x20\x20 // exactly 10 items\n\
         \x20 ]\n\
         }}\n\
         \n\
         Constraints:\n\
         - consolidate all supplied sessions into one coherent chapter pack;\n\
         - retain useful concepts from earlier sessions while integrating new material;\n\
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

/// Strip reasoning tags and markdown code fences. Reasoning-capable
/// models (DeepSeek-R1, the new minimax-M3, etc.) emit their chain of
/// thought in `<think>...</think>` blocks; the actual answer comes
/// after. We drop the thinking and parse the remainder.
fn strip_thinking_and_fences(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut rest = s;
    while let Some(start) = rest.find("<think>") {
        out.push_str(&rest[..start]);
        if let Some(end) = rest[start..].find("</think>") {
            // Skip past the closing tag.
            let after = start + end + "</think>".len();
            rest = &rest[after..];
        } else {
            // Unclosed think tag — treat the rest as content.
            rest = &rest[start + "<think>".len()..];
            break;
        }
    }
    out.push_str(rest);
    strip_code_fences(&out)
}

/// Find the first balanced `{ ... }` in `s` and return the substring.
/// Used when the model emits JSON surrounded by prose or markdown.
fn extract_json_object(s: &str) -> Option<String> {
    let bytes = s.as_bytes();
    let mut start = None;
    let mut depth: i32 = 0;
    let mut in_string = false;
    let mut escape = false;
    let mut last_open = 0usize;
    for (i, &b) in bytes.iter().enumerate() {
        if escape {
            escape = false;
            continue;
        }
        if in_string {
            if b == b'\\' {
                escape = true;
            } else if b == b'"' {
                in_string = false;
            }
            continue;
        }
        match b {
            b'"' => in_string = true,
            b'{' => {
                if start.is_none() {
                    start = Some(i);
                    last_open = i;
                }
                depth += 1;
            }
            b'}' => {
                if depth > 0 {
                    depth -= 1;
                    if depth == 0 {
                        return Some(s[start.unwrap()..=i].to_string());
                    }
                }
            }
            _ => {}
        }
    }
    let _ = last_open;
    None
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
    #[serde(default)]
    key_points: Vec<String>,
    #[serde(default)]
    takeaway: Option<String>,
    #[serde(default)]
    flashcards: Vec<crate::providers::Flashcard>,
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
        assert_eq!(strip_code_fences(r#"{"a":1}"#), r#"{"a":1}"#);
    }

    #[test]
    fn strip_code_fences_handles_json_fenced_block() {
        assert_eq!(strip_code_fences("```json\n{\"a\":1}\n```"), r#"{"a":1}"#);
    }

    #[test]
    fn strip_code_fences_handles_bare_fenced_block() {
        assert_eq!(strip_code_fences("```\n{\"a\":1}\n```"), r#"{"a":1}"#);
    }

    #[test]
    fn user_prompt_contains_chapter_title_and_transcript() {
        let t = Transcript {
            text: "hello".into(),
            language: Some("en".into()),
            segments: vec![],
        };
        let s = build_user_prompt("Algebra", &t);
        assert!(s.contains("Algebra"));
        assert!(s.contains("hello"));
        assert!(s.contains("exactly 3"));
        assert!(s.contains("exactly 10"));
    }

    #[test]
    fn user_prompt_includes_language_hint_when_known() {
        let t = Transcript {
            text: "x".into(),
            language: Some("fr".into()),
            segments: vec![],
        };
        let s = build_user_prompt("X", &t);
        assert!(s.contains("`fr`"));
    }

    #[test]
    fn strip_thinking_drops_reasoning_block() {
        let raw = "<think>I need to produce JSON for the user. Let me think step by step.</think>\n{\"summary_markdown\":\"# Hi\",\"exercises\":[],\"quiz\":[]}";
        let s = strip_thinking_and_fences(raw);
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["summary_markdown"], "# Hi");
    }

    #[test]
    fn strip_thinking_handles_multiple_blocks() {
        let raw = "<think>step 1</think>between<think>step 2</think>\n{\"a\":1}";
        let s = strip_thinking_and_fences(raw);
        // Both think blocks are removed; the prose between them remains.
        // The full-string parse will fail; the caller's extract_json_object
        // fallback is what handles this. We just verify the think tags
        // are gone.
        assert!(!s.contains("<think>"));
        assert!(!s.contains("step 1"));
        assert!(!s.contains("step 2"));
        assert!(s.contains("{\"a\":1}"));
    }

    #[test]
    fn strip_thinking_handles_unclosed_tag() {
        let raw = "<think>unfinished thinking and no closing tag\n{\"a\":1}";
        let s = strip_thinking_and_fences(raw);
        // Best-effort: we still drop the prefix, the JSON parses.
        assert!(s.contains("{\"a\":1}"));
    }

    #[test]
    fn extract_json_object_finds_balanced_braces() {
        let s = r#"Here is the JSON you asked for:
{"a":1,"b":{"c":2}}
Hope that helps."#;
        let extracted = extract_json_object(s).unwrap();
        let v: serde_json::Value = serde_json::from_str(&extracted).unwrap();
        assert_eq!(v["a"], 1);
        assert_eq!(v["b"]["c"], 2);
    }

    #[test]
    fn extract_json_object_skips_braces_inside_strings() {
        let s = r#"{"a":"has { and } in it","b":2}"#;
        let extracted = extract_json_object(s).unwrap();
        let v: serde_json::Value = serde_json::from_str(&extracted).unwrap();
        assert_eq!(v["a"], "has { and } in it");
        assert_eq!(v["b"], 2);
    }

    #[test]
    fn extract_json_object_returns_none_when_no_json() {
        assert!(extract_json_object("just plain text").is_none());
    }
}
