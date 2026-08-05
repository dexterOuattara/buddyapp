<script>
  import { api } from '../api.js';

  let items = $state([]);
  let error = $state('');
  let loading = $state(true);

  // Moderation item kind -> backend route segment.
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

  async function decide(item, decision) {
    try {
      await api.decide(kindRoute[item.kind], item.id, decision);
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
  students receive them.
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
          <th>Type</th>
          <th>Recording</th>
          <th>Created</th>
          <th style="width:220px">Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each items as item}
          <tr>
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
        {/each}
      </tbody>
    </table>
  {/if}
</div>
