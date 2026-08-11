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
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use serde::Deserialize;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

use crate::providers::{
    estimate_word_timings, SttProgressCallback, SttProgressFuture, SttProvider, Transcript,
    TranscriptSegment, TranscriptWord,
};

/// Cloudflare's per-request audio payload cap. We stay safely under it.
const MAX_BYTES_PER_SEGMENT: u64 = 20 * 1024 * 1024;
/// And a time-based cap, so a single ~20 MiB slice isn't 4 hours long.
const MAX_SECONDS_PER_SEGMENT: f64 = 15.0 * 60.0;

#[derive(Debug, Clone)]
pub struct CloudflareWhisperConfig {
    pub account_id: String,
    pub token: String,
    pub model: String,
    pub ffprobe_path: PathBuf,
    pub ffmpeg_path: PathBuf,
}

impl CloudflareWhisperConfig {
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
        let model = std::env::var("CF_WHISPER_MODEL")
            .ok()
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "@cf/openai/whisper-large-v3-turbo".to_string());
        let ffprobe_path = resolve_media_binary("FFPROBE_PATH", "ffprobe")?;
        let ffmpeg_path = resolve_media_binary("FFMPEG_PATH", "ffmpeg")?;
        Ok(Self {
            account_id,
            token,
            model,
            ffprobe_path,
            ffmpeg_path,
        })
    }
}

fn resolve_media_binary(env_key: &str, name: &str) -> anyhow::Result<PathBuf> {
    if let Ok(explicit) = std::env::var(env_key) {
        let path = PathBuf::from(explicit);
        if path.is_file() {
            return Ok(path);
        }
        anyhow::bail!(
            "{env_key} points to a missing executable: {}",
            path.display()
        );
    }

    let mut candidates = std::env::var_os("PATH")
        .into_iter()
        .flat_map(|paths| std::env::split_paths(&paths).collect::<Vec<_>>())
        .map(|dir| dir.join(name))
        .collect::<Vec<_>>();
    candidates.extend([
        PathBuf::from(format!("/opt/homebrew/bin/{name}")),
        PathBuf::from(format!("/usr/local/bin/{name}")),
        PathBuf::from(format!("/usr/bin/{name}")),
    ]);
    if let Some(path) = candidates.into_iter().find(|path| path.is_file()) {
        return Ok(path);
    }
    anyhow::bail!(
        "{name} is required by the Cloudflare Whisper pipeline but was not found; install ffmpeg or set {env_key}"
    )
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
        let out = Command::new(&self.cfg.ffprobe_path)
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
            anyhow::bail!("ffprobe failed: {}", String::from_utf8_lossy(&out.stderr));
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
            let status = Command::new(&self.cfg.ffmpeg_path)
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
    ) -> anyhow::Result<CloudflareTranscript> {
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
        Ok(parsed.into_transcript())
    }
}

#[async_trait]
impl SttProvider for CloudflareWhisperStt {
    fn name(&self) -> &str {
        "cloudflare-whisper-large-v3-turbo"
    }

    async fn transcribe(&self, audio: &[u8]) -> anyhow::Result<Transcript> {
        let mut noop = |_: usize, _: usize| -> SttProgressFuture<'_> { Box::pin(async {}) };
        self.transcribe_with_progress(audio, &mut noop).await
    }

    async fn transcribe_with_progress(
        &self,
        audio: &[u8],
        progress: &mut SttProgressCallback<'_>,
    ) -> anyhow::Result<Transcript> {
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
        tracing::info!(segments = slices.len(), "Cloudflare Whisper: audio sliced");
        progress(0, slices.len()).await;

        let mut texts = Vec::with_capacity(slices.len());
        let mut segments = Vec::new();
        let mut language = None;
        let mut offset_ms = 0_i64;
        for (i, slice) in slices.iter().enumerate() {
            match self.transcribe_segment(slice).await {
                Ok(chunk) => {
                    let slice_duration_ms = (self.probe_duration(slice).await? * 1000.0)
                        .round()
                        .max(1.0) as i64;
                    tracing::info!(
                        segment = i + 1,
                        of = slices.len(),
                        chars = chunk.text.len(),
                        cues = chunk.segments.len(),
                        "Cloudflare Whisper: segment transcribed"
                    );
                    if language.is_none() {
                        language = chunk.language;
                    }
                    if chunk.segments.is_empty() && !chunk.text.trim().is_empty() {
                        segments.push(TranscriptSegment {
                            start_ms: offset_ms,
                            end_ms: offset_ms + slice_duration_ms,
                            words: estimate_word_timings(
                                chunk.text.trim(),
                                offset_ms,
                                offset_ms + slice_duration_ms,
                            ),
                            text: chunk.text.trim().to_string(),
                        });
                    } else {
                        segments.extend(chunk.segments.into_iter().map(|cue| {
                            TranscriptSegment {
                                start_ms: cue.start_ms + offset_ms,
                                end_ms: cue.end_ms + offset_ms,
                                text: cue.text,
                                words: cue
                                    .words
                                    .into_iter()
                                    .map(|word| TranscriptWord {
                                        start_ms: word.start_ms + offset_ms,
                                        end_ms: word.end_ms + offset_ms,
                                        text: word.text,
                                    })
                                    .collect(),
                            }
                        }));
                    }
                    texts.push(chunk.text);
                    offset_ms += slice_duration_ms;
                    progress(i + 1, slices.len()).await;
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
            language,
            segments,
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
    #[serde(default)]
    segments: Vec<CloudflareSegment>,
    #[serde(default)]
    transcription_info: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
struct WhisperResult {
    #[serde(default)]
    text: Option<String>,
    #[serde(default)]
    #[serde(rename = "word_count")]
    _word_count: Option<u32>,
    #[serde(default)]
    transcription_info: Option<serde_json::Value>,
    #[serde(default)]
    segments: Vec<CloudflareSegment>,
}

#[derive(Debug, Deserialize)]
struct CloudflareSegment {
    start: f64,
    end: f64,
    text: String,
    #[serde(default)]
    words: Vec<CloudflareWord>,
}

#[derive(Debug, Deserialize)]
struct CloudflareWord {
    start: f64,
    end: f64,
    #[serde(default)]
    word: Option<String>,
    #[serde(default)]
    text: Option<String>,
}

#[derive(Debug)]
struct CloudflareTranscript {
    text: String,
    language: Option<String>,
    segments: Vec<TranscriptSegment>,
}

impl WhisperResponse {
    /// Extract text, language and time-aligned cues from either response shape.
    fn into_transcript(self) -> CloudflareTranscript {
        let (text, segments, info) = if let Some(result) = self.result {
            (
                result.text.unwrap_or_default(),
                result.segments,
                result.transcription_info,
            )
        } else {
            (
                self.text.unwrap_or_default(),
                self.segments,
                self.transcription_info,
            )
        };
        let language = info.as_ref().and_then(|value| {
            value
                .get("language")
                .or_else(|| value.get("detected_language"))
                .and_then(serde_json::Value::as_str)
                .map(str::to_string)
        });
        let segments = segments
            .into_iter()
            .filter_map(|segment| {
                let text = segment.text.trim().to_string();
                let start_ms = (segment.start.max(0.0) * 1000.0).round() as i64;
                let end_ms = (segment.end.max(0.0) * 1000.0).round() as i64;
                let mut words = segment
                    .words
                    .into_iter()
                    .filter_map(|word| {
                        let text = word.word.or(word.text)?.trim().to_string();
                        let word_start_ms =
                            (word.start.max(segment.start).max(0.0) * 1000.0).round() as i64;
                        let word_end_ms =
                            (word.end.min(segment.end).max(0.0) * 1000.0).round() as i64;
                        (!text.is_empty() && word_end_ms > word_start_ms).then_some(
                            TranscriptWord {
                                start_ms: word_start_ms,
                                end_ms: word_end_ms,
                                text,
                            },
                        )
                    })
                    .collect::<Vec<_>>();
                if words.is_empty() {
                    words = estimate_word_timings(&text, start_ms, end_ms);
                }
                (!text.is_empty() && end_ms > start_ms).then_some(TranscriptSegment {
                    start_ms,
                    end_ms,
                    text,
                    words,
                })
            })
            .collect();
        CloudflareTranscript {
            text,
            language,
            segments,
        }
    }
}

/// RFC 4648 base64 encoder. Avoids pulling in the `base64` crate for one
/// call site.
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

    /// The provider name is stable and exposed in the transcripts row.
    #[test]
    fn provider_name_is_stable() {
        let cfg = CloudflareWhisperConfig {
            account_id: "x".into(),
            token: "y".into(),
            model: "@cf/openai/whisper-large-v3-turbo".into(),
            ffprobe_path: PathBuf::from("/usr/bin/true"),
            ffmpeg_path: PathBuf::from("/usr/bin/true"),
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
        let saved_probe = std::env::var("FFPROBE_PATH").ok();
        let saved_mpeg = std::env::var("FFMPEG_PATH").ok();
        let executable = std::env::current_exe().unwrap();
        std::env::set_var("CF_ACCOUNT_ID", "test-account");
        std::env::set_var("CF_AI_TOKEN", "test-token");
        std::env::set_var("FFPROBE_PATH", &executable);
        std::env::set_var("FFMPEG_PATH", &executable);
        std::env::remove_var("CF_WHISPER_MODEL");
        let cfg = CloudflareWhisperConfig::from_env().unwrap();
        assert_eq!(cfg.model, "@cf/openai/whisper-large-v3-turbo");
        for (k, v) in [
            ("CF_AI_TOKEN", saved),
            ("CF_ACCOUNT_ID", saved_id),
            ("CF_WHISPER_MODEL", saved_model),
            ("FFPROBE_PATH", saved_probe),
            ("FFMPEG_PATH", saved_mpeg),
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
        let transcript = parsed.into_transcript();
        assert_eq!(transcript.text, "Hello world");
        assert_eq!(transcript.language.as_deref(), Some("en"));
    }

    #[test]
    fn parses_top_level_text_fallback() {
        let body = r#"{"text": "fallback", "word_count": 1}"#;
        let parsed: WhisperResponse = serde_json::from_str(body).unwrap();
        assert_eq!(parsed.into_transcript().text, "fallback");
    }

    #[test]
    fn empty_response_yields_empty_text() {
        let body = r#"{"success": true, "result": {}}"#;
        let parsed: WhisperResponse = serde_json::from_str(body).unwrap();
        assert_eq!(parsed.into_transcript().text, "");
    }

    #[test]
    fn parses_timed_segments() {
        let body = r#"{
            "result": {
                "text": "Bonjour le monde",
                "segments": [
                    {"start": 0.1, "end": 1.4, "text": " Bonjour"},
                    {"start": 1.4, "end": 2.8, "text": "le monde"}
                ]
            }
        }"#;
        let transcript = serde_json::from_str::<WhisperResponse>(body)
            .unwrap()
            .into_transcript();
        assert_eq!(transcript.segments.len(), 2);
        assert_eq!(transcript.segments[0].start_ms, 100);
        assert_eq!(transcript.segments[1].end_ms, 2800);
        assert_eq!(transcript.segments[0].words.len(), 1);
        assert_eq!(transcript.segments[1].words.len(), 2);
    }

    #[test]
    fn preserves_provider_word_timestamps_when_present() {
        let body = r#"{
            "result": {
                "text": "Bonjour monde",
                "segments": [{
                    "start": 0.0,
                    "end": 1.0,
                    "text": "Bonjour monde",
                    "words": [
                        {"start": 0.0, "end": 0.4, "word": "Bonjour"},
                        {"start": 0.4, "end": 1.0, "word": "monde"}
                    ]
                }]
            }
        }"#;
        let transcript = serde_json::from_str::<WhisperResponse>(body)
            .unwrap()
            .into_transcript();
        assert_eq!(transcript.segments[0].words[1].start_ms, 400);
        assert_eq!(transcript.segments[0].words[1].text, "monde");
    }
}
