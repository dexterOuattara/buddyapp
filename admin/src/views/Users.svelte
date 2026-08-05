<script>
  import { api } from '../api.js';

  let users = $state([]);
  let query = $state('');
  let error = $state('');
  let loading = $state(true);

  async function load() {
    loading = true;
    error = '';
    try {
      users = await api.users(query);
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function setRole(user, role) {
    try {
      await api.setUserRole(user.id, role);
      await load();
    } catch (e) {
      error = e.message;
    }
  }

  load();
</script>

<h1>Users</h1>
<p class="sub">Manage accounts and roles.</p>

<div class="card row">
  <input
    placeholder="Search by email…"
    bind:value={query}
    onkeydown={(e) => e.key === 'Enter' && load()}
    style="max-width:320px"
  />
  <button class="primary" onclick={load}>Search</button>
</div>

{#if error}<div class="card error">{error}</div>{/if}

<div class="card">
  {#if loading}
    Loading…
  {:else if users.length === 0}
    No users found.
  {:else}
    <table>
      <thead>
        <tr>
          <th>Email</th>
          <th>Role</th>
          <th>Joined</th>
          <th style="width:240px">Change role</th>
        </tr>
      </thead>
      <tbody>
        {#each users as u}
          <tr>
            <td>{u.email}</td>
            <td>
              <span class="badge {u.role === 'admin' ? 'warn' : 'info'}">{u.role}</span>
            </td>
            <td>{new Date(u.created_at).toLocaleDateString()}</td>
            <td>
              <div class="row">
                <button
                  class="ghost"
                  disabled={u.role === 'student'}
                  onclick={() => setRole(u, 'student')}
                >Student</button>
                <button
                  class="ghost"
                  disabled={u.role === 'admin'}
                  onclick={() => setRole(u, 'admin')}
                >Admin</button>
              </div>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>
