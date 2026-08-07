<script>
  import { api } from '../api.js';

  let recordings = $state([]);
  let users = $state([]);
  let error = $state('');
  let loading = $state(true);

  async function load() {
    loading = true;
    error = '';
    try {
      const [recs, usrs] = await Promise.all([
        api.recordings(),
        api.users(),
      ]);
      recordings = recs;
      users = usrs;
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  load();

  const statusCounts = $derived(
    recordings.reduce((acc, r) => {
      acc[r.status] = (acc[r.status] || 0) + 1;
      return acc;
    }, {})
  );
</script>

<h1>Dashboard</h1>
<p class="sub">Recording processing status and content pipeline health.</p>

{#if error}<div class="card error">{error}</div>{/if}
{#if loading}
  <div class="card">Loading…</div>
{:else}
  <div class="stats">
    <div class="stat">
      <div class="num">{recordings.length}</div>
      <div class="lbl">Total recordings</div>
    </div>
    <div class="stat">
      <div class="num">{statusCounts['processing'] || 0}</div>
      <div class="lbl">Processing now</div>
    </div>
    <div class="stat">
      <div class="num">{statusCounts['ready'] || 0}</div>
      <div class="lbl">Ready</div>
    </div>
    <div class="stat">
      <div class="num">{statusCounts['failed'] || 0}</div>
      <div class="lbl">Failed</div>
    </div>
    <div class="stat">
      <div class="num">{users.length}</div>
      <div class="lbl">Registered users</div>
    </div>
  </div>

  <div class="card">
    <h3 style="margin-top:0">Pipeline health</h3>
    <p style="color:var(--muted);font-size:14px">
      A recording moves through <strong>uploaded → processing → ready</strong>.
      Anything stuck in <em>processing</em> for a long time or in <em>failed</em>
      should be investigated. Generated study material is published to the
      student as soon as it is ready.
    </p>
  </div>
{/if}
