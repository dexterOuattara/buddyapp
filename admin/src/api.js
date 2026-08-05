// Thin fetch wrapper over the BuddyWize admin API.
const API = import.meta.env.VITE_API_URL || 'http://localhost:7878/api';

let accessToken = localStorage.getItem('bw.access') || null;
let refreshToken = localStorage.getItem('bw.refresh') || null;

// Coalesces a burst of 401s into a single /auth/refresh call.
let refreshInFlight = null;

export function isAuthenticated() {
  return Boolean(accessToken);
}

export async function login(email, password) {
  const body = await fetchJson(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  applyAuthResponse(body);
  return body;
}

export function logout() {
  accessToken = null;
  refreshToken = null;
  localStorage.removeItem('bw.access');
  localStorage.removeItem('bw.refresh');
}

function applyAuthResponse(body) {
  accessToken = body.access_token || null;
  refreshToken = body.refresh_token || null;
  if (accessToken) localStorage.setItem('bw.access', accessToken);
  if (refreshToken) localStorage.setItem('bw.refresh', refreshToken);
}

async function postRefresh() {
  if (!refreshToken) throw new Error('No refresh token');
  const res = await fetch(`${API}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
  const body = await parseBody(res);
  if (!res.ok) throw new Error(body.error || `Refresh failed (${res.status})`);
  applyAuthResponse(body);
}

function ensureRefresh() {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = postRefresh().finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

function authHeaders() {
  return accessToken ? { Authorization: `Bearer ${accessToken}` } : {};
}

async function parseBody(res) {
  const text = await res.text();
  return text ? JSON.parse(text) : {};
}

async function fetchJson(url, options = {}) {
  const res = await fetch(url, options);
  if (res.status !== 401) {
    const body = await parseBody(res);
    if (!res.ok) throw new Error(body.error || `Request failed (${res.status})`);
    return body;
  }
  // 401 — try to refresh once, then retry the original request.
  await parseBody(res); // drain the body so the socket is reusable
  try {
    await ensureRefresh();
  } catch {
    logout();
    throw new Error('Session expired — please log in again.');
  }
  const retried = await fetch(url, {
    ...options,
    headers: {
      ...(options.headers || {}),
      ...authHeaders(),
    },
  });
  if (retried.status === 401) {
    logout();
    throw new Error('Session expired — please log in again.');
  }
  const body = await parseBody(retried);
  if (!retried.ok) throw new Error(body.error || `Request failed (${retried.status})`);
  return body;
}

async function request(path, options = {}) {
  return fetchJson(`${API}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders(),
      ...(options.headers || {}),
    },
  });
}

export const api = {
  users: (q = '') => request(`/admin/users?q=${encodeURIComponent(q)}`),
  setUserRole: (id, role) =>
    request(`/admin/users/${id}/role`, {
      method: 'POST',
      body: JSON.stringify({ role }),
    }),
  recordings: (status) =>
    request(`/admin/recordings${status ? `?status=${status}` : ''}`),
  moderation: () => request('/admin/moderation'),
  decide: (kind, id, decision) =>
    request(`/admin/moderation/${kind}/${id}`, {
      method: 'POST',
      body: JSON.stringify({ decision }),
    }),
};
