//! Cloudflare Workers AI speech-to-text provider.
//!
//! Implements `SttProvider` on top of `@cf/openai/whisper-large-v3-turbo`
//! (or any other Cloudflare-hosted Whisper model). The audio is sent as a
//! multipart `audio` field; the JSON response is parsed for the `text`
//! field.
//!
//! Long audio is sliced into ≤20 MiB / ≤15-min segments with `ffmpeg -c
//! copy` (no re-encode), transcribed segment by segment, and stitched
//! into a single transcript. The Cloudflare per-request audio limit is
//! roughly 25 MiB; we stay under 20 to leave headroom for the request
//! envelope.

use std::path::PathBuf;
use std::process::Stdio;
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use serde::Deserialize;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

use crate::providers::{SttProvider, Transcript};

/// Cloudflare's per-request audio payload cap. We stay safely under it.
const MAX_BYTES_PER_SEGMENT: u64 = 20 * 1024 * 1024;
/// And a time-based cap, so a single ~20 MiB slice isn't 4 hours long.
const MAX_SECONDS_PER_SEGMENT: f64 = 15.0 * 60.0;

#[derive(Debug, Clone)]
pub struct CloudflareWhisperConfig {
    pub account_id: String,
    pub token: String,
    pub model: String,
}

impl CloudflareWhisperConfig {
    pub fn from_env() -> anyhow::Result<Self> {
        let account_id = std::env::var("CF_ACCOUNT_ID")
            .map_err(|_| anyhow::anyhow!("CF_ACCOUNT_ID must be set"))?;
        let token = std::env::var("CF_AI_TOKEN")
            .ok()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| anyhow::anyhow!(
                "CF_AI_TOKEN must be set to a non-empty Cloudflare API token (Workers AI:Read)"
            ))?;
        let model = std::env::var("CF_WHISPER_MODEL")
            .ok()
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "@cf/openai/whisper-large-v3-turbo".to_string());
        Ok(Self { account_id, token, model })
    }
}

pub struct CloudflareWhisperStt {
    cfg: CloudflareWhisperConfig,
    http: Client,
}

impl CloudflareWhisperStt {
    pub fn new(cfg: CloudflareWhisperConfig) -> Self {
        let http = Client::builder()
            .timeout(Duration::from_secs(300))
            .build()
            .expect("reqwest client builder");
        Self { cfg, http }
    }

    /// Probe audio duration with ffprobe (seconds, 1 decimal).
    async fn probe_duration(&self, audio_path: &std::path::Path) -> anyhow::Result<f64> {
        let out = Command::new("ffprobe")
            .arg("-v")
            .arg("quiet")
            .arg("-show_entries")
            .arg("format=duration")
            .arg("-of")
            .arg("csv=p=0")
            .arg(audio_path)
            .output()
            .await?;
        if !out.status.success() {
            anyhow::bail!(
                "ffprobe failed: {}",
                String::from_utf8_lossy(&out.stderr)
            );
        }
        let s = String::from_utf8_lossy(&out.stdout);
        let trimmed = s.trim();
        trimmed
            .parse::<f64>()
            .map_err(|e| anyhow::anyhow!("invalid duration '{trimmed}': {e}"))
    }

    /// Slice audio into segments using ffmpeg stream copy. Each segment
    /// is at most `MAX_SECONDS_PER_SEGMENT` long. Returns the list of
    /// segment file paths.
    async fn slice_audio(
        &self,
        audio_path: &std::path::Path,
        out_dir: &std::path::Path,
    ) -> anyhow::Result<Vec<PathBuf>> {
        let duration = self.probe_duration(audio_path).await?;
        if duration <= MAX_SECONDS_PER_SEGMENT + 0.5 {
            // Single segment — just return the input path unchanged.
            return Ok(vec![audio_path.to_path_buf()]);
        }

        let mut segments = Vec::new();
        let mut t = 0.0_f64;
        let mut idx = 0;
        while t < duration {
            let remaining = duration - t;
            let seg_len = remaining.min(MAX_SECONDS_PER_SEGMENT);
            let out_path = out_dir.join(format!("seg-{idx:03}.m4a"));
            let status = Command::new("ffmpeg")
                .arg("-y")
                .arg("-loglevel")
                .arg("error")
                .arg("-ss")
                .arg(format!("{t:.3}"))
                .arg("-t")
                .arg(format!("{seg_len:.3}"))
                .arg("-i")
                .arg(audio_path)
                .arg("-c")
                .arg("copy")
                .arg(&out_path)
                .output()
                .await?;
            if !status.status.success() {
                anyhow::bail!(
                    "ffmpeg slice failed at t={t}: {}",
                    String::from_utf8_lossy(&status.stderr)
                );
            }
            segments.push(out_path);
            t += seg_len;
            idx += 1;
        }
        Ok(segments)
    }

    /// Call Cloudflare Whisper on one audio segment. Cloudflare's
    /// `/ai/run` endpoint takes JSON with the audio as an array of
    /// byte values (not base64, not multipart).
    async fn transcribe_segment(
        &self,
        audio_path: &std::path::Path,
    ) -> anyhow::Result<String> {
        let bytes = tokio::fs::read(audio_path).await?;
        if bytes.is_empty() {
            anyhow::bail!("audio segment is empty: {}", audio_path.display());
        }
        if bytes.len() as u64 > MAX_BYTES_PER_SEGMENT + 1024 * 1024 {
            anyhow::bail!(
                "segment {} is {} bytes; exceeds {} byte cap",
                audio_path.display(),
                bytes.len(),
                MAX_BYTES_PER_SEGMENT
            );
        }

        // Cloudflare's /ai/run endpoint takes JSON with `audio` as a
        // base64-encoded string. The endpoint URL already includes the
        // model name; the body is just the input fields.
        let url = format!(
            "https://api.cloudflare.com/client/v4/accounts/{}/ai/run/{}",
            self.cfg.account_id, self.cfg.model
        );
        let encoded = base64_encode(&bytes);
        let body = serde_json::json!({
            "audio": encoded,
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
                "Cloudflare Whisper returned HTTP {status}: {}",
                text.chars().take(500).collect::<String>()
            );
        }

        let parsed: WhisperResponse = resp.json().await?;
        // Cloudflare v4 envelope: `{success, result: {text, ...}}`. Some
        // endpoints put fields at the top level; both shapes are handled.
        Ok(parsed.into_text())
    }
}

#[async_trait]
impl SttProvider for CloudflareWhisperStt {
    fn name(&self) -> &str {
        "cloudflare-whisper-large-v3-turbo"
    }

    async fn transcribe(&self, audio: &[u8]) -> anyhow::Result<Transcript> {
        if audio.is_empty() {
            anyhow::bail!("audio is empty; nothing to transcribe");
        }

        // Write the audio to a temp file once; ffmpeg and reqwest both
        // need a file path. Per-recording dir keeps segments together
        // for cleanup.
        let tmp_dir = std::env::temp_dir().join(format!(
            "buddywize-stt-cf-{}-{}",
            std::process::id(),
            uuid::Uuid::new_v4()
        ));
        tokio::fs::create_dir_all(&tmp_dir).await?;
        let audio_path = tmp_dir.join("input.m4a");
        tokio::fs::File::create(&audio_path)
            .await?
            .write_all(audio)
            .await?;

        let slices = self.slice_audio(&audio_path, &tmp_dir).await?;
        tracing::info!(
            segments = slices.len(),
            "Cloudflare Whisper: audio sliced"
        );

        let mut texts = Vec::with_capacity(slices.len());
        for (i, slice) in slices.iter().enumerate() {
            match self.transcribe_segment(slice).await {
                Ok(t) => {
                    tracing::info!(
                        segment = i + 1,
                        of = slices.len(),
                        chars = t.len(),
                        "Cloudflare Whisper: segment transcribed"
                    );
                    texts.push(t);
                }
                Err(e) => {
                    // Best-effort cleanup before propagating.
                    let _ = tokio::fs::remove_dir_all(&tmp_dir).await;
                    return Err(e);
                }
            }
        }

        // Stitch with a single space — segments are contiguous in time.
        let combined = texts
            .into_iter()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join(" ");

        let _ = tokio::fs::remove_dir_all(&tmp_dir).await;

        Ok(Transcript {
            text: combined,
            language: None, // Cloudflare's response includes `detected_language` but we keep the field None for compatibility.
        })
    }
}

#[derive(Debug, Deserialize)]
struct WhisperResponse {
    /// Cloudflare v4 envelope wraps the model output under `result`.
    #[serde(default)]
    result: Option<WhisperResult>,
    /// Some endpoints return the fields at the top level; tolerate that too.
    #[serde(default)]
    text: Option<String>,
}

#[derive(Debug, Deserialize)]
struct WhisperResult {
    #[serde(default)]
    text: Option<String>,
    #[serde(default)]
    word_count: Option<u32>,
    #[serde(default)]
    transcription_info: Option<serde_json::Value>,
}

impl WhisperResponse {
    /// Extract the transcribed text from either envelope shape.
    fn into_text(self) -> String {
        if let Some(r) = self.result {
            r.text.unwrap_or_default()
        } else {
            self.text.unwrap_or_default()
        }
    }
}

/// RFC 4648 base64 encoder. Avoids pulling in the `base64` crate for one
/// call site.
fn base64_encode(input: &[u8]) -> String {
    const ALPHABET: &[u8; 64] =
        b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
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

    /// The provider name is stable and exposed in the transcripts row.
    #[test]
    fn provider_name_is_stable() {
        let cfg = CloudflareWhisperConfig {
            account_id: "x".into(),
            token: "y".into(),
            model: "@cf/openai/whisper-large-v3-turbo".into(),
        };
        let stt = CloudflareWhisperStt::new(cfg);
        assert_eq!(stt.name(), "cloudflare-whisper-large-v3-turbo");
    }

    #[test]
    fn config_from_env_requires_token() {
        // Empty token must surface as an Err (fail-fast at startup).
        // SAFETY: tests that read env can race; serialise here trivially.
        let saved = std::env::var("CF_AI_TOKEN").ok();
        let saved_id = std::env::var("CF_ACCOUNT_ID").ok();
        std::env::set_var("CF_ACCOUNT_ID", "test-account");
        std::env::set_var("CF_AI_TOKEN", "");
        let r = CloudflareWhisperConfig::from_env();
        assert!(r.is_err(), "expected error for empty CF_AI_TOKEN");
        match saved {
            Some(v) => std::env::set_var("CF_AI_TOKEN", v),
            None => std::env::remove_var("CF_AI_TOKEN"),
        }
        match saved_id {
            Some(v) => std::env::set_var("CF_ACCOUNT_ID", v),
            None => std::env::remove_var("CF_ACCOUNT_ID"),
        }
    }

    #[test]
    fn config_from_env_uses_default_model() {
        let saved = std::env::var("CF_AI_TOKEN").ok();
        let saved_id = std::env::var("CF_ACCOUNT_ID").ok();
        let saved_model = std::env::var("CF_WHISPER_MODEL").ok();
        std::env::set_var("CF_ACCOUNT_ID", "test-account");
        std::env::set_var("CF_AI_TOKEN", "test-token");
        std::env::remove_var("CF_WHISPER_MODEL");
        let cfg = CloudflareWhisperConfig::from_env().unwrap();
        assert_eq!(cfg.model, "@cf/openai/whisper-large-v3-turbo");
        for (k, v) in [
            ("CF_AI_TOKEN", saved),
            ("CF_ACCOUNT_ID", saved_id),
            ("CF_WHISPER_MODEL", saved_model),
        ] {
            match v {
                Some(s) => std::env::set_var(k, s),
                None => std::env::remove_var(k),
            }
        }
    }

    #[test]
    fn parses_v4_envelope_with_result_wrapper() {
        let body = r#"{
            "success": true,
            "errors": [],
            "messages": [],
            "result": {
                "text": "Hello world",
                "word_count": 2,
                "transcription_info": {"language": "en", "duration": 1.0}
            }
        }"#;
        let parsed: WhisperResponse = serde_json::from_str(body).unwrap();
        assert_eq!(parsed.into_text(), "Hello world");
    }

    #[test]
    fn parses_top_level_text_fallback() {
        let body = r#"{"text": "fallback", "word_count": 1}"#;
        let parsed: WhisperResponse = serde_json::from_str(body).unwrap();
        assert_eq!(parsed.into_text(), "fallback");
    }

    #[test]
    fn empty_response_yields_empty_text() {
        let body = r#"{"success": true, "result": {}}"#;
        let parsed: WhisperResponse = serde_json::from_str(body).unwrap();
        assert_eq!(parsed.into_text(), "");
    }
}