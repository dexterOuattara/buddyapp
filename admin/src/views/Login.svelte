<script>
  import { login } from '../api.js';

  let { onDone } = $props();

  let email = $state('');
  let password = $state('');
  let error = $state('');
  let busy = $state(false);

  async function submit() {
    busy = true;
    error = '';
    try {
      await login(email, password);
      onDone();
    } catch (e) {
      error = e.message;
    } finally {
      busy = false;
    }
  }
</script>

<div class="login-wrap">
  <form class="login-card" onsubmit={(e) => { e.preventDefault(); submit(); }}>
    <h2>🎓 BuddyWize Admin</h2>
    <div class="field">
      <label for="email">Email</label>
      <input id="email" type="email" bind:value={email} autocomplete="username" required />
    </div>
    <div class="field">
      <label for="password">Password</label>
      <input id="password" type="password" bind:value={password} autocomplete="current-password" required />
    </div>
    {#if error}<div class="error">{error}</div>{/if}
    <button class="primary" disabled={busy} style="width:100%">
      {busy ? 'Signing in…' : 'Sign in'}
    </button>
    <p style="color:var(--muted);font-size:12px;margin-top:14px">
      Default dev admin: admin@buddywize.local / admin-buddywize
    </p>
  </form>
</div>
