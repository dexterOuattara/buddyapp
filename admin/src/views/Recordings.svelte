<script>
  import { api } from '../api.js';

  let recordings = $state([]);
  let filter = $state('');
  let error = $state('');
  let loading = $state(true);

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

  load();
</script>

<h1>Recordings</h1>
<p class="sub">Monitor upload + processing status and spot sync problems.</p>

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
          <th>Recording</th>
          <th>User</th>
          <th>Status</th>
          <th>Duration</th>
          <th>Updated</th>
        </tr>
      </thead>
      <tbody>
        {#each recordings as r}
          <tr>
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
        {/each}
      </tbody>
    </table>
  {/if}
</div>
