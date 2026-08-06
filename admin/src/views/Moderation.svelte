<script>
  import { api, recordingAudioBlobUrl, revokeBlobUrl } from '../api.js';
  import { renderMarkdown } from '../lib/markdown.js';

  let items = $state([]);
  let error = $state('');
  let loading = $state(true);

  // Per-recording detail cache. Keyed by recording_id so expanding different
  // pending items from the same recording reuses the same fetch.
  let details = $state({});      // { [recordingId]: RecordingDetailDto | { error } }
  let audioUrls = $state({});    // { [recordingId]: blob: URL | null }
  let audioBusy = $state({});    // { [recordingId]: bool }
  let expandedFor = $state(null); // recordingId currently expanded

  const kindRoute = { summary: 'summaries', exercises: 'exercises', quiz: 'quizzes' };

  async function load() {
    loading = true;
    error = '';
    try {
      items = await api.moderation();
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  function toggleRow(recordingId) {
    if (expandedFor === recordingId) {
      collapseRow();
      return;
    }
    // Don't revoke the previous audio's Blob URL here — the audio element
    // may still be playing in another row's element. We let GC reclaim
    // them when the page reloads or the audio element is destroyed.
    expandedFor = recordingId;
    if (!details[recordingId] && !audioBusy[recordingId]) {
      loadDetail(recordingId);
    }
  }

  function collapseRow() {
    // Keep audioUrls[expandedFor] alive — the audio element instance gets
    // unmounted by Svelte but the underlying Blob URL stays valid until the
    // page is unloaded. Revoking here would race with any in-flight playback.
    expandedFor = null;
  }

  async function loadDetail(recordingId) {
    audioBusy[recordingId] = true;
    try {
      details[recordingId] = await api.recordingDetail(recordingId);
      audioUrls[recordingId] = await recordingAudioBlobUrl(recordingId);
    } catch (e) {
      details[recordingId] = { error: e.message };
    } finally {
      audioBusy[recordingId] = false;
    }
  }

  async function decide(item, decision) {
    try {
      await api.decide(kindRoute[item.kind], item.id, decision);
      // Drop cached audio/details for this recording so reopening shows fresh data.
      const recId = item.recording_id;
      if (audioUrls[recId]) {
        revokeBlobUrl(audioUrls[recId]);
        delete audioUrls[recId];
      }
      delete details[recId];
      if (expandedFor === recId) expandedFor = null;
      await load();
    } catch (e) {
      error = e.message;
    }
  }

  load();
</script>

<h1>Content review</h1>
<p class="sub">
  Approve or reject AI-generated summaries, exercises, and quizzes before
  students receive them. Click any row to preview the audio, transcript,
  and full content before deciding.
</p>

{#if error}<div class="card error">{error}</div>{/if}

<div class="card">
  {#if loading}
    Loading…
  {:else if items.length === 0}
    Nothing is waiting for review. 🎉
  {:else}
    <table>
      <thead>
        <tr>
          <th style="width:24px"></th>
          <th>Type</th>
          <th>Recording</th>
          <th>Created</th>
          <th style="width:220px">Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each items as item}
          {@const isOpen = expandedFor === item.recording_id}
          <tr
            class="expandable"
            onclick={(e) => {
              if (e.target.closest('button')) return;
              toggleRow(item.recording_id);
            }}
          >
            <td><span class="expand-toggle">{isOpen ? '▾' : '▸'}</span></td>
            <td><span class="badge info">{item.kind}</span></td>
            <td style="font-family:monospace;font-size:12px">{item.recording_id}</td>
            <td>{new Date(item.created_at).toLocaleString()}</td>
            <td>
              <div class="row">
                <button class="primary" onclick={() => decide(item, 'approved')}>Approve</button>
                <button class="ghost" onclick={() => decide(item, 'rejected')}>Reject</button>
              </div>
            </td>
          </tr>

          {#if isOpen}
            {@const d = details[item.recording_id]}
            <tr class="detail-row">
              <td colspan="5">
                <div class="detail-panel">
                  <div class="detail-header">
                    <span>Recording:</span>
                    <code>{item.recording_id}</code>
                    <span>· kind: <strong>{item.kind}</strong></span>
                  </div>

                  {#if !d}
                    <div class="empty-state">Loading details…</div>
                  {:else if d.error}
                    <div class="detail-error">Failed to load details: {d.error}</div>
                  {:else}
                    <!-- Audio player -->
                    <div class="detail-section">
                      <h4>Audio</h4>
                      {#if audioUrls[item.recording_id]}
                        <div class="audio-block">
                          <audio controls preload="metadata" src={audioUrls[item.recording_id]}></audio>
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

                    <!-- Transcript -->
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

                    <!-- The piece under moderation -->
                    <div class="detail-section">
                      <h4>{item.kind} preview</h4>
                      {#if item.kind === 'summary' && d.summary}
                        <div class="md-content">{@html renderMarkdown(d.summary.content_md)}</div>
                      {:else if item.kind === 'exercises' && d.exercises}
                        {#each (d.exercises.items || []) as ex, i}
                          <div class="exercise-card">
                            <div class="prompt">{i + 1}. {ex.prompt}</div>
                            {#if ex.guidance}<div class="guidance">{ex.guidance}</div>{/if}
                            {#if ex.answer}
                              <div class="answer"><strong>Answer:</strong> {ex.answer}</div>
                            {/if}
                          </div>
                        {/each}
                      {:else if item.kind === 'quiz' && d.quizzes}
                        {#each (d.quizzes.questions || []) as q, i}
                          <div class="quiz-card">
                            <div class="prompt">{i + 1}. {q.prompt}</div>
                            {#each (q.choices || []) as choice, ci}
                              <div class="choice {ci === q.correct_index ? 'correct' : ''}">
                                {String.fromCharCode(65 + ci)}. {choice}{ci === q.correct_index ? ' ✓' : ''}
                              </div>
                            {/each}
                            {#if q.explanation}<div class="explanation">{q.explanation}</div>{/if}
                          </div>
                        {/each}
                      {:else}
                        <div class="empty-state">
                          {item.kind} content has not been generated yet.
                        </div>
                      {/if}
                    </div>

                    <!-- Approve / Reject in the panel too -->
                    <div class="row" style="justify-content:flex-end;padding-top:4px">
                      <button class="ghost" onclick={() => decide(item, 'rejected')}>Reject</button>
                      <button class="primary" onclick={() => decide(item, 'approved')}>Approve</button>
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
