<script>
  import { api } from '../api.js';

  let model = $state('');
  let available = $state([]);
  let error = $state('');
  let saving = $state(false);
  let loading = $state(true);

  async function load() {
    loading = true;
    error = '';
    try {
      const state = await api.studyGenerator();
      model = state.model;
      available = state.available;
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function save() {
    if (!model || saving) return;
    saving = true;
    error = '';
    try {
      const next = await api.setStudyGenerator(model);
      model = next.model;
      available = next.available;
    } catch (e) {
      error = e.message;
    } finally {
      saving = false;
    }
  }

  load();

  const currentLabel = $derived(
    available.find((m) => m.id === model)?.label ?? model
  );
</script>

<h1>Settings</h1>
<p class="sub">
  Tune the AI that generates the summary, exercises, and quizzes for
  every recording. Changes apply to the next pipeline job — already-finished
  recordings keep their original provider tag.
</p>

{#if error}<div class="card error">{error}</div>{/if}

<div class="card">
  <h3 style="margin-top:0">Study material generator</h3>

  {#if loading}
    Loading…
  {:else}
    <p style="color:var(--muted);font-size:14px;margin-top:0">
      Currently active: <strong>{currentLabel}</strong> <code>{model}</code>
    </p>

    <div class="row" style="align-items:center;gap:12px;flex-wrap:wrap">
      <select bind:value={model} disabled={saving} style="min-width:380px">
        {#each available as m}
          <option value={m.id}>
            {m.label}{m.free_tier ? '  ★ free tier' : ''}
          </option>
        {/each}
      </select>
      <button class="primary" onclick={save} disabled={saving}>
        {saving ? 'Saving…' : 'Save'}
      </button>
    </div>

    <p style="color:var(--muted);font-size:13px;margin-top:14px">
      Pricing shown reflects Cloudflare's published rates where available.
      Partner-model rates (DeepSeek V4 Pro) are visible on your Cloudflare
      dashboard under AI → Models.
    </p>
  {/if}
</div>