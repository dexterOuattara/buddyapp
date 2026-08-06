<script>
  import { api, recordingAudioBlobUrl, revokeBlobUrl } from '../api.js';
  import { renderMarkdown } from '../lib/markdown.js';

  let recordings = $state([]);
  let filter = $state('');
  let error = $state('');
  let loading = $state(true);

  // Per-recording detail cache (mirrors Moderation.svelte).
  let details = $state({});
  let audioUrls = $state({});
  let audioBusy = $state({});
  let expandedFor = $state(null);

  const badgeClass = {
    ready: 'ok',
    uploaded: 'info',
    processing: 'warn',
    failed: 'bad',
    blocked: 'bad',
  };

  async function load() {
    loading = true;
    error = '';
    try {
      recordings = await api.recordings(filter || undefined);
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  function toggleRow(id) {
    if (expandedFor === id) {
      collapseRow();
      return;
    }
    if (expandedFor && audioUrls[expandedFor]) {
      revokeBlobUrl(audioUrls[expandedFor]);
    }
    expandedFor = id;
    if (!details[id] && !audioBusy[id]) {
      loadDetail(id);
    }
  }

  function collapseRow() {
    if (expandedFor && audioUrls[expandedFor]) {
      revokeBlobUrl(audioUrls[expandedFor]);
      audioUrls[expandedFor] = null;
    }
    expandedFor = null;
  }

  async function loadDetail(id) {
    audioBusy[id] = true;
    try {
      details[id] = await api.recordingDetail(id);
      audioUrls[id] = await recordingAudioBlobUrl(id);
    } catch (e) {
      details[id] = { error: e.message };
    } finally {
      audioBusy[id] = false;
    }
  }

  load();
</script>

<h1>Recordings</h1>
<p class="sub">
  Monitor upload + processing status and spot sync problems. Click any row
  to play the audio, read the transcript, and inspect the generated
  study material.
</p>

<div class="card row">
  <select bind:value={filter} onchange={load} style="max-width:220px">
    <option value="">All statuses</option>
    <option value="uploaded">uploaded</option>
    <option value="processing">processing</option>
    <option value="ready">ready</option>
    <option value="failed">failed</option>
    <option value="blocked">blocked</option>
  </select>
  <div class="spacer"></div>
  <button class="ghost" onclick={load}>Refresh</button>
</div>

{#if error}<div class="card error">{error}</div>{/if}

<div class="card">
  {#if loading}
    Loading…
  {:else if recordings.length === 0}
    No recordings match this filter.
  {:else}
    <table>
      <thead>
        <tr>
          <th style="width:24px"></th>
          <th>Recording</th>
          <th>User</th>
          <th>Status</th>
          <th>Duration</th>
          <th>Updated</th>
        </tr>
      </thead>
      <tbody>
        {#each recordings as r}
          {@const isOpen = expandedFor === r.id}
          <tr
            class="expandable"
            onclick={(e) => {
              if (e.target.closest('button')) return;
              toggleRow(r.id);
            }}
          >
            <td><span class="expand-toggle">{isOpen ? '▾' : '▸'}</span></td>
            <td style="font-family:monospace;font-size:12px">{r.id}</td>
            <td style="font-family:monospace;font-size:12px">{r.user_id}</td>
            <td>
              <span class="badge {badgeClass[r.status] || 'info'}">{r.status}</span>
              {#if r.error}
                <div style="color:var(--bad);font-size:12px;margin-top:4px">{r.error}</div>
              {/if}
            </td>
            <td>{r.duration_secs != null ? `${r.duration_secs}s` : '—'}</td>
            <td>{new Date(r.updated_at).toLocaleString()}</td>
          </tr>

          {#if isOpen}
            {@const d = details[r.id]}
            <tr class="detail-row">
              <td colspan="6">
                <div class="detail-panel">
                  <div class="detail-header">
                    <span>Recording:</span>
                    <code>{r.id}</code>
                    <span>· storage:</span>
                    <code>{r.storage_path || '—'}</code>
                  </div>

                  {#if !d}
                    <div class="empty-state">Loading details…</div>
                  {:else if d.error}
                    <div class="detail-error">Failed to load details: {d.error}</div>
                  {:else}
                    <div class="detail-section">
                      <h4>Audio</h4>
                      {#if audioUrls[r.id]}
                        <div class="audio-block">
                          <audio controls preload="metadata" src={audioUrls[r.id]}></audio>
                          <div class="audio-meta">
                            <span>{d.audio.mime}</span>
                            <span>{(d.audio.size / 1024).toFixed(1)} KB</span>
                            {#if d.user_email}<span>by {d.user_email}</span>{/if}
                            {#if d.chapter_title}<span>· {d.chapter_title}</span>{/if}
                          </div>
                        </div>
                      {:else}
                        <div class="empty-state">Audio unavailable.</div>
                      {/if}
                    </div>

                    <div class="detail-section">
                      <h4>Transcript</h4>
                      {#if d.transcript}
                        <div class="detail-header" style="margin-bottom:6px">
                          <span>provider:</span>
                          <code>{d.transcript.provider}</code>
                          <span>· {d.transcript.content.length} chars</span>
                        </div>
                        <pre class="transcript">{d.transcript.content || '(empty)'}</pre>
                      {:else}
                        <div class="transcript-empty">No transcript yet (recording may still be processing).</div>
                      {/if}
                    </div>

                    <div class="detail-section">
                      <h4>Generated content</h4>
                      {#if d.summary}
                        <h4 style="margin-top:0">Summary</h4>
                        <div class="md-content">{@html renderMarkdown(d.summary.content_md)}</div>
                      {/if}
                      {#if d.exercises && (d.exercises.items || []).length}
                        <h4>Exercises</h4>
                        {#each d.exercises.items as ex, i}
                          <div class="exercise-card">
                            <div class="prompt">{i + 1}. {ex.prompt}</div>
                            {#if ex.guidance}<div class="guidance">{ex.guidance}</div>{/if}
                            {#if ex.answer}
                              <div class="answer"><strong>Answer:</strong> {ex.answer}</div>
                            {/if}
                          </div>
                        {/each}
                      {/if}
                      {#if d.quizzes && (d.quizzes.questions || []).length}
                        <h4>Quiz</h4>
                        {#each d.quizzes.questions as q, i}
                          <div class="quiz-card">
                            <div class="prompt">{i + 1}. {q.prompt}</div>
                            {#each q.choices as choice, ci}
                              <div class="choice {ci === q.correct_index ? 'correct' : ''}">
                                {String.fromCharCode(65 + ci)}. {choice}{ci === q.correct_index ? ' ✓' : ''}
                              </div>
                            {/each}
                            {#if q.explanation}<div class="explanation">{q.explanation}</div>{/if}
                          </div>
                        {/each}
                      {/if}
                      {#if !d.summary && !d.exercises && !d.quizzes}
                        <div class="empty-state">No study material generated yet.</div>
                      {/if}
                    </div>
                  {/if}
                </div>
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>
  {/if}
</div>
