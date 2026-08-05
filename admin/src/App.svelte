<script>
  import { isAuthenticated, logout } from './api.js';
  import Login from './views/Login.svelte';
  import Dashboard from './views/Dashboard.svelte';
  import Users from './views/Users.svelte';
  import Recordings from './views/Recordings.svelte';
  import Moderation from './views/Moderation.svelte';

  let authed = $state(isAuthenticated());
  let tab = $state('dashboard');

  function handleLogout() {
    logout();
    authed = false;
  }

  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: '📊' },
    { id: 'moderation', label: 'Content review', icon: '🧐' },
    { id: 'recordings', label: 'Recordings', icon: '🎙️' },
    { id: 'users', label: 'Users', icon: '👥' },
  ];
</script>

{#if !authed}
  <Login onDone={() => (authed = true)} />
{:else}
  <div class="layout">
    <aside class="sidebar">
      <div class="brand">🎓 BuddyWize</div>
      {#each tabs as t}
        <button class:active={tab === t.id} onclick={() => (tab = t.id)}>
          {t.icon}&nbsp;&nbsp;{t.label}
        </button>
      {/each}
      <button class="logout" onclick={handleLogout}>Sign out</button>
    </aside>

    <main class="content">
      {#if tab === 'dashboard'}
        <Dashboard />
      {:else if tab === 'moderation'}
        <Moderation />
      {:else if tab === 'recordings'}
        <Recordings />
      {:else if tab === 'users'}
        <Users />
      {/if}
    </main>
  </div>
{/if}
