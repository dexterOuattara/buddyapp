# ---- build stage ----
FROM rust:1.94-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y pkg-config libssl-dev curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy workspace manifest + crates. Migrations are embedded at compile time
# by sqlx::migrate!, so they must be present during the build.
COPY Cargo.toml ./
COPY Cargo.lock ./
COPY migrations ./migrations
COPY crates ./crates
COPY bin ./bin
RUN cargo build --release -p buddywize-api --locked

# ---- runtime stage ----
# Debian 13 (trixie) ships glibc 2.41, which is required by Rust 1.94 binaries.
FROM debian:trixie-slim
WORKDIR /app

# System deps for the Rust binary + faster-whisper + ffmpeg (which faster-whisper
# shells out to when reading audio that isn't a format ctranslate2 can decode itself).
RUN apt-get update && apt-get install -y \
    ca-certificates \
    python3 python3-pip python3-venv \
    ffmpeg \
    libgomp1 \
  && rm -rf /var/lib/apt/lists/*

# Python deps in an isolated venv so the system Python stays clean.
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
 && /opt/venv/bin/pip install --no-cache-dir faster-whisper

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    WHISPER_PYTHON=/opt/venv/bin/python3 \
    WHISPER_SCRIPT=/app/bin/transcribe.py

COPY --from=build /app/target/release/buddywize-api /usr/local/bin/buddywize-api
COPY --from=build /app/bin /app/bin

ENV HOST=0.0.0.0 PORT=7878
EXPOSE 7878
CMD ["buddywize-api"]
