//! Cloudflare Gemma 4 agenda parser.
//!
//! Single-stage OCR + structuring: the image goes to Gemma 4 with a
//! strict JSON prompt; the response is parsed, validated, sanitized,
//! and returned as `Vec<AgendaItemDraft>`.
//!
//! Failure semantics mirror the existing LLM providers (AGEND §10
//! law #5): no mock fallback. Parse failures retry once with a
//! stricter prompt; HTTP errors fail immediately so the mobile sees a
//! real error message.

use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use buddywize_core::settings::SettingsCache;
use reqwest::Client;
use serde::Deserialize;

use crate::providers::{AgendaItemDraft, AgendaParser};

const SETTINGS_KEY: &str = "agenda_parser_model";
const FALLBACK_MODEL: &str = "@cf/google/gemma-4-26b-a4b-it";
/// Hard cap on items per scan. Beyond this Gemma starts hallucinating.
const MAX_ITEMS_PER_SCAN: usize = 50;

/// Detect MIME type from the first few bytes of the image.
/// Defaults to image/jpeg — safe for the most common phone capture.
fn detect_mime(input: &[u8]) -> &'static str {
    if input.len() >= 8 && &input[..8] == b"\x89PNG\r\n\x1a\n" {
        "image/png"
    } else if input.len() >= 3 && &input[..3] == b"\xff\xd8\xff" {
        "image/jpeg"
    } else if input.len() >= 4 && &input[..4] == b"GIF8" {
        "image/gif"
    } else if input.len() >= 12 && &input[..4] == b"RIFF" && &input[8..12] == b"WEBP" {
        "image/webp"
    } else {
        "image/jpeg"
    }
}

#[derive(Debug, Clone)]
pub struct CloudflareAgendaConfig {
    pub account_id: String,
    pub token: String,
    pub model: String,
    pub temperature: f32,
    pub max_output_tokens: u32,
    pub max_retries: u32,
}

impl CloudflareAgendaConfig {
    pub fn from_env() -> anyhow::Result<Self> {
        let account_id = std::env::var("CF_ACCOUNT_ID")
            .map_err(|_| anyhow::anyhow!("CF_ACCOUNT_ID must be set"))?;
        let token = std::env::var("CF_AI_TOKEN")
            .ok()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| {
                anyhow::anyhow!(
                    "CF_AI_TOKEN must be set to a non-empty Cloudflare API token (Workers AI:Read)"
                )
            })?;
        let model = std::env::var("CF_GEMMA_MODEL")
            .ok()
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| FALLBACK_MODEL.to_string());
        let temperature: f32 = std::env::var("CF_AI_TEMPERATURE")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(0.2);
        let max_output_tokens: u32 = std::env::var("CF_AI_MAX_OUTPUT_TOKENS")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(2048);
        let max_retries: u32 = std::env::var("CF_AI_MAX_RETRIES")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(1);
        Ok(Self {
            account_id,
            token,
            model,
            temperature,
            max_output_tokens,
            max_retries,
        })
    }
}

pub struct CloudflareAgendaParser {
    cfg: CloudflareAgendaConfig,
    http: Client,
    #[allow(dead_code)] // reserved for runtime model swap (AGEND §10 law #8)
    settings: Option<Arc<SettingsCache>>,
}

impl CloudflareAgendaParser {
    pub fn new(cfg: CloudflareAgendaConfig) -> Self {
        let http = Client::builder()
            .timeout(Duration::from_secs(120))
            .build()
            .expect("reqwest client builder");
        Self {
            cfg,
            http,
            settings: None,
        }
    }

    async fn pick_model(&self) -> String {
        if let Some(s) = &self.settings {
            if let Ok(Some(v)) = s.get_or_load(SETTINGS_KEY).await {
                if !v.is_empty() {
                    return v;
                }
            }
        }
        if let Ok(v) = std::env::var("CF_GEMMA_MODEL") {
            if !v.is_empty() {
                return v;
            }
        }
        FALLBACK_MODEL.to_string()
    }

    async fn call_gemma(
        &self,
        model: &str,
        image_b64: &str,
        mime: &str,
        strict: bool,
    ) -> anyhow::Result<Vec<AgendaItemDraft>> {
        // Use the OpenAI-compatible chat-completions endpoint. It returns
        // the OpenAI shape directly (no v4 envelope to unwrap), and
        // Gemma 4 supports multimodal via the `image_url` content type.
        let url = format!(
            "https://api.cloudflare.com/client/v4/accounts/{}/ai/v1/chat/completions",
            self.cfg.account_id
        );
        let system = SYSTEM_PROMPT;
        let user = if strict {
            build_strict_user_prompt()
        } else {
            build_user_prompt()
        };

        let body = serde_json::json!({
            "model": model,
            "messages": [
                { "role": "system", "content": system },
                {
                    "role": "user",
                    "content": [
                        { "type": "text", "text": user },
                        { "type": "image_url", "image_url": { "url": format!("data:{};base64,{}", mime, image_b64) } }
                    ]
                }
            ],
            "temperature": self.cfg.temperature,
            "max_tokens": self.cfg.max_output_tokens,
        });

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
            anyhow::bail!(
                "Cloudflare Gemma returned HTTP {status}: {}",
                text.chars().take(500).collect::<String>()
            );
        }

        let parsed: ChatResponse = resp.json().await?;
        let raw = parsed
            .choices
            .into_iter()
            .next()
            .map(|c| c.message.content)
            .ok_or_else(|| anyhow::anyhow!("Cloudflare Gemma response had no choices"))?;

        parse_drafts(&raw)
    }

    pub fn with_settings(mut self, settings: Arc<SettingsCache>) -> Self {
        self.settings = Some(settings);
        self
    }
}

#[async_trait]
impl AgendaParser for CloudflareAgendaParser {
    fn name(&self) -> &str {
        "cloudflare-gemma-agenda"
    }

    async fn parse(&self, input: &[u8]) -> anyhow::Result<Vec<AgendaItemDraft>> {
        if input.is_empty() {
            anyhow::bail!("agenda input is empty");
        }
        let image_b64 = base64_encode(input);
        let mime = detect_mime(input);
        let model = self.pick_model().await;

        let mut last_err: Option<anyhow::Error> = None;
        for attempt in 0..=self.cfg.max_retries {
            let strict = attempt > 0;
            match self.call_gemma(&model, &image_b64, &mime, strict).await {
                Ok(items) => {
                    let trimmed = trim_items(items);
                    tracing::info!(
                        model = %model,
                        attempt = attempt,
                        items = trimmed.len(),
                        "Cloudflare Gemma produced agenda drafts"
                    );
                    return Ok(trimmed);
                }
                Err(e) => {
                    tracing::warn!(error = %e, model = %model, attempt = attempt, "gemma agenda call failed");
                    last_err = Some(e);
                }
            }
        }
        Err(last_err
            .unwrap_or_else(|| anyhow::anyhow!("gemma agenda call failed without an error")))
    }
}

// ---------- prompt + parsing helpers ----------

const SYSTEM_PROMPT: &str = "You are an agenda extraction assistant. You receive a photo of a paper agenda or schedule and must extract every schedule entry into strict JSON. Match the schema exactly. Do not invent entries. If a field is unclear, leave it out rather than guess. Respond in the same language as the agenda.";

fn build_user_prompt() -> String {
    "Extract every schedule entry from this agenda image. \
     Return JSON of the form: \
     {\"items\": [{\"title\": \"<subject or activity>\", \"starts_at\": \"<ISO 8601 or empty>\", \"ends_at\": \"<ISO 8601 or empty>\", \"notes\": \"<room, teacher, or empty>\"}]}. \
     \
     Rules: \
     - title is required, short, plain text. \
     - starts_at / ends_at are RFC 3339 (e.g. 2026-08-25T09:00:00Z) when both date and time are visible, otherwise leave empty. \
     - Do NOT include explanations, prose, or markdown fences. \
     - Output ONLY the JSON object."
        .to_string()
}

fn build_strict_user_prompt() -> String {
    "Your previous response was not valid JSON. Return ONLY the JSON object now. \
     Schema: {\"items\": [{\"title\": \"...\", \"starts_at\": \"ISO8601 or empty\", \"ends_at\": \"ISO8601 or empty\", \"notes\": \"... or empty\"}]}. \
     No markdown fences, no commentary."
        .to_string()
}

/// Parse the raw text from Gemma. Handles cases where the model
/// wraps JSON in code fences or includes a brief preamble.
fn parse_drafts(raw: &str) -> anyhow::Result<Vec<AgendaItemDraft>> {
    let trimmed = raw.trim();
    // Try direct parse first.
    if let Ok(parsed) = serde_json::from_str::<DraftsEnvelope>(trimmed) {
        return Ok(parsed.items);
    }
    // Strip code fences and try again.
    let stripped = strip_code_fences(trimmed);
    if let Ok(parsed) = serde_json::from_str::<DraftsEnvelope>(&stripped) {
        return Ok(parsed.items);
    }
    // Extract the first balanced JSON object from the response.
    if let Some(sub) = extract_json_object(&stripped) {
        if let Ok(parsed) = serde_json::from_str::<DraftsEnvelope>(&sub) {
            return Ok(parsed.items);
        }
    }
    anyhow::bail!(
        "Gemma response did not contain parseable JSON: {}",
        raw.chars().take(200).collect::<String>()
    )
}

fn trim_items(items: Vec<AgendaItemDraft>) -> Vec<AgendaItemDraft> {
    let mut out: Vec<AgendaItemDraft> = items.into_iter().filter_map(|d| d.sanitized()).collect();
    if out.len() > MAX_ITEMS_PER_SCAN {
        tracing::warn!(
            items = out.len(),
            "Gemma returned more than {} items; truncating",
            MAX_ITEMS_PER_SCAN
        );
        out.truncate(MAX_ITEMS_PER_SCAN);
    }
    out
}

// ---------- request / response DTOs ----------

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
struct DraftsEnvelope {
    items: Vec<AgendaItemDraft>,
}

// ---------- tiny helpers (mirror deepseek.rs for consistency) ----------

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

fn extract_json_object(s: &str) -> Option<String> {
    let bytes = s.as_bytes();
    let mut start: Option<usize> = None;
    let mut depth: i32 = 0;
    let mut in_string = false;
    let mut escape = false;
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
    None
}

fn base64_encode(input: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity((input.len() + 2) / 3 * 4);
    let mut i = 0;
    while i + 3 <= input.len() {
        let n = ((input[i] as u32) << 16) | ((input[i + 1] as u32) << 8) | (input[i + 2] as u32);
        out.push(ALPHABET[((n >> 18) & 0x3f) as usize] as char);
        out.push(ALPHABET[((n >> 12) & 0x3f) as usize] as char);
        out.push(ALPHABET[((n >> 6) & 0x3f) as usize] as char);
        out.push(ALPHABET[(n & 0x3f) as usize] as char);
        i += 3;
    }
    let rem = input.len() - i;
    if rem == 1 {
        let n = (input[i] as u32) << 16;
        out.push(ALPHABET[((n >> 18) & 0x3f) as usize] as char);
        out.push(ALPHABET[((n >> 12) & 0x3f) as usize] as char);
        out.push('=');
        out.push('=');
    } else if rem == 2 {
        let n = ((input[i] as u32) << 16) | ((input[i + 1] as u32) << 8);
        out.push(ALPHABET[((n >> 18) & 0x3f) as usize] as char);
        out.push(ALPHABET[((n >> 12) & 0x3f) as usize] as char);
        out.push(ALPHABET[((n >> 6) & 0x3f) as usize] as char);
        out.push('=');
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitized_drops_empty_titles() {
        let d = AgendaItemDraft {
            title: "  ".into(),
            starts_at: None,
            ends_at: None,
            notes: None,
        };
        assert!(d.sanitized().is_none());
    }

    #[test]
    fn sanitized_trims_titles_and_drops_long_notes() {
        let long_note = "x".repeat(600);
        let d = AgendaItemDraft {
            title: "  Mathématiques  ".into(),
            starts_at: Some("2026-08-25T09:00:00Z".into()),
            ends_at: Some("".into()), // empty string -> None after trim
            notes: Some(long_note),
        };
        let s = d.sanitized().unwrap();
        assert_eq!(s.title, "Mathématiques");
        assert_eq!(s.starts_at.as_deref(), Some("2026-08-25T09:00:00Z"));
        assert_eq!(s.ends_at, None);
        assert_eq!(s.notes, None);
    }

    #[test]
    fn parse_drafts_handles_code_fenced_json() {
        let raw = "```json\n{\"items\":[{\"title\":\"Algèbre\",\"starts_at\":\"2026-08-25T09:00:00Z\",\"ends_at\":null,\"notes\":null}]}\n```";
        let items = parse_drafts(raw).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].title, "Algèbre");
    }

    #[test]
    fn parse_drafts_handles_prose_wrapped_json() {
        let raw = r#"Here is the JSON:
{"items":[{"title":"Algèbre","starts_at":"","ends_at":"","notes":""}]}
"#;
        let items = parse_drafts(raw).unwrap();
        assert_eq!(items[0].title, "Algèbre");
    }

    #[test]
    fn parse_drafts_rejects_garbage() {
        let r = parse_drafts("totally not json");
        assert!(r.is_err());
    }

    #[test]
    fn trim_items_caps_at_max() {
        let items: Vec<AgendaItemDraft> = (0..60)
            .map(|i| AgendaItemDraft {
                title: format!("Item {i}"),
                starts_at: None,
                ends_at: None,
                notes: None,
            })
            .collect();
        let trimmed = trim_items(items);
        assert_eq!(trimmed.len(), MAX_ITEMS_PER_SCAN);
    }

    #[test]
    fn base64_roundtrip_known_vector() {
        // Standard test vector: "Man" -> "TWFu"
        assert_eq!(base64_encode(b"Man"), "TWFu");
        // "Ma" -> "TWE=" (with padding)
        assert_eq!(base64_encode(b"Ma"), "TWE=");
        // "M" -> "TQ==" (single byte)
        assert_eq!(base64_encode(b"M"), "TQ==");
    }
}
