# BuddyWize Admin (Svelte)

Internal dashboard for managing users, monitoring the recording pipeline, and
moderating AI-generated content before it reaches students. Consumes the same
Swagger-documented API as the mobile app, using an admin-scoped JWT.

## Develop

```bash
npm install
npm run dev        # http://localhost:5173
```

Point it at a specific API with `VITE_API_URL`:

```bash
VITE_API_URL=http://localhost:7878/api npm run dev
```

## Build

```bash
npm run build      # outputs to dist/
```

## Default dev credentials

The backend seeds an admin account at boot:

- email: `admin@buddywize.local`
- password: `admin-buddywize`

Override with `ADMIN_EMAIL` / `ADMIN_PASSWORD` in the backend environment.

## Views

- **Dashboard** — recording counts by status + pipeline health.
- **Content review** — approve/reject pending summaries, exercises, quizzes.
- **Recordings** — filter by processing status, inspect failures.
- **Users** — search, promote/demote roles.
