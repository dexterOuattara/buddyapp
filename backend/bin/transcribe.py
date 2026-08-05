#!/usr/bin/env python3
"""
faster-whisper transcription worker.

Reads an audio file path from argv[1], transcribes it with faster-whisper, and
prints a JSON document to stdout:

    {
      "language": "en",
      "language_probability": 0.998,
      "duration": 12.4,
      "segments": [
        {"start": 0.0, "end": 4.2, "text": " Hello class.", "no_speech_prob": 0.001},
        ...
      ],
      "text": "Hello class. Today we will talk about..."
    }

The model is loaded once per process (the Rust pipeline spawns this script
per recording, so the warm-up cost is paid per recording).

Configuration via env (set by the Rust supervisor):
    WHISPER_MODEL        default: "large-v3"  (best open-source ASR as of 2026)
    WHISPER_DEVICE       default: "cpu"       (also: "cuda")
    WHISPER_COMPUTE_TYPE default: "int8"      (int8 / float16 / float32)
    WHISPER_BEAM_SIZE    default: 5
"""

import json
import os
import sys
import time
import traceback


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: transcribe.py <audio_path>"}), file=sys.stderr)
        return 2

    audio_path = sys.argv[1]
    if not os.path.exists(audio_path):
        print(json.dumps({"error": f"audio file not found: {audio_path}"}), file=sys.stderr)
        return 2

    model_name = os.environ.get("WHISPER_MODEL", "large-v3")
    device = os.environ.get("WHISPER_DEVICE", "cpu")
    compute_type = os.environ.get("WHISPER_COMPUTE_TYPE", "int8")
    beam_size = int(os.environ.get("WHISPER_BEAM_SIZE", "5"))

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print(
            json.dumps({
                "error": "faster-whisper is not installed. "
                         "Run: pip install faster-whisper"
            }),
            file=sys.stderr,
        )
        return 3

    started = time.time()
    model = WhisperModel(
        model_name,
        device=device,
        compute_type=compute_type,
    )

    segments_iter, info = model.transcribe(
        audio_path,
        beam_size=beam_size,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
        condition_on_previous_text=False,
    )

    segments = []
    text_parts = []
    for seg in segments_iter:
        segments.append({
            "start": float(seg.start),
            "end": float(seg.end),
            "text": seg.text,
            "no_speech_prob": float(seg.no_speech_prob),
        })
        text_parts.append(seg.text)

    duration = time.time() - started
    full_text = "".join(text_parts).strip()

    out = {
        "language": info.language,
        "language_probability": float(info.language_probability),
        "duration": float(info.duration),
        "wall_time_sec": duration,
        "model": model_name,
        "device": device,
        "compute_type": compute_type,
        "segments": segments,
        "text": full_text,
    }
    json.dump(out, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # last-resort guard so the Rust side gets a JSON error
        err = {"error": str(e), "traceback": traceback.format_exc()}
        sys.stderr.write(json.dumps(err) + "\n")
        sys.exit(1)
