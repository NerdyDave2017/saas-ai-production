# Healthcare Consultation Assistant — AWS deployment branch

This repository is a full-stack SaaS demo: a Next.js (Pages Router) frontend with Clerk authentication and a FastAPI backend that streams AI-generated visit summaries. The **`aws-deployment`** branch refactors the app so it can run as **one Docker container** on **AWS App Runner** (and Amazon ECR), instead of relying on Vercel-hosted Next.js and separate API routing.

For the full step-by-step AWS narrative (account setup, IAM, budgets, App Runner UI, troubleshooting), see **[`day5.md`](./day5.md)**. This README summarizes **what changed on this branch** and the **commands you run in the terminal**.

---

## Branch: `aws-deployment`

| Item | Notes |
| --- | --- |
| Latest migration commit | `refactor: migrate to aws` |
| Base history | Healthcare app features merged from `main` / prior PRs (Clerk, billing, streaming UI, etc.) |

---

## What changed (high level)

1. **Static Next.js export** — The UI is built to static HTML/JS/CSS (`next build` → `out/`) so it does not need a Node server in production.
2. **Single process in production** — **FastAPI** (`api/server.py`) serves:
   - `POST /api/consultation` — streaming consultation (SSE), Clerk-protected
   - `GET /health` — health check for App Runner
   - **Static site** — `out/` is copied into the image as `static/` and served from the same origin
3. **Frontend API URL** — `pages/product.tsx` calls `fetchEventSource("/api/consultation", …)` so the browser hits the same host/port as the app (critical once everything is behind one container URL).
4. **Docker** — Multi-stage **`Dockerfile`**: Node 22 builds the frontend; Python 3.12 runs `uvicorn` on port **8000**.
5. **`.dockerignore`** — Keeps secrets and heavy dirs (e.g. `node_modules`, `.env`) out of the build context.

### Vercel vs this branch

| Aspect | Vercel-style setup | This branch (AWS container) |
| --- | --- | --- |
| Frontend | Next.js on Vercel | Static files served by FastAPI |
| API | e.g. Vercel Python function (`api/index.py` style) | `api/server.py` in the same container |
| Deploy | Git push to Vercel | Build image → push ECR → App Runner |

`api/index.py` remains in the repo as the older **Vercel serverless** handler shape (`POST /api`); **production in Docker uses `api/server.py`** only.

---

## LLM configuration (this repo)

`api/server.py` uses the **OpenAI-compatible client** with **OpenRouter**:

- `OPENROUTER_API_KEY`
- `OPENROUTER_BASE_URL`

Clerk:

- `CLERK_JWKS_URL` (and the usual `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` / `CLERK_SECRET_KEY` for the app)

The [`day5.md`](./day5.md) lab text often shows `OPENAI_API_KEY` only; align your **runtime env** with what `server.py` actually reads (OpenRouter variables above).

---

## Environment variables

**Build-time (Docker ARG):**

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` — baked into the static export.

**Runtime (container / App Runner):**

- `CLERK_SECRET_KEY`
- `CLERK_JWKS_URL`
- `OPENROUTER_API_KEY`
- `OPENROUTER_BASE_URL`

Optional for AWS CLI / ECR tag commands (from `day5.md`):

- `DEFAULT_AWS_REGION` (e.g. `us-east-1`)
- `AWS_ACCOUNT_ID` (12-digit account id)

Keep secrets in `.env` / `.env.local` and **never commit** them. `.dockerignore` excludes `.env`.

---

## Project layout (relevant paths)

```
├── pages/              # Next.js Pages Router (includes product UI)
├── api/
│   ├── server.py       # FastAPI app used in Docker / App Runner
│   └── index.py        # Legacy Vercel-style handler (not used by Dockerfile)
├── public/
├── next.config.ts      # output: "export", unoptimized images
├── Dockerfile          # build static site + run uvicorn
├── .dockerignore
├── requirements.txt    # Python deps for the API
└── day5.md             # Full AWS migration guide (course reference)
```

---

## Terminal commands

### Verify Docker

```bash
docker --version
docker run hello-world
```

### Load env vars into your shell (macOS / Linux)

```bash
export $(cat .env | grep -v '^#' | xargs)
```

_(Adjust if your secrets live in `.env.local` instead.)_

### Build the image (local test)

```bash
docker build \
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" \
  -t consultation-app .
```

### Run the container locally

```bash
docker run -p 8000:8000 \
  -e CLERK_SECRET_KEY="$CLERK_SECRET_KEY" \
  -e CLERK_JWKS_URL="$CLERK_JWKS_URL" \
  -e OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  -e OPENROUTER_BASE_URL="$OPENROUTER_BASE_URL" \
  consultation-app
```

Open **http://localhost:8000** — same origin for UI and `/api/consultation`.

### AWS: ECR login, build for App Runner, tag, push

Apple Silicon: use **`--platform linux/amd64`** so the image runs on App Runner.

```bash
aws ecr get-login-password --region "$DEFAULT_AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$DEFAULT_AWS_REGION.amazonaws.com"

docker build \
  --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" \
  -t consultation-app .

docker tag consultation-app:latest "$AWS_ACCOUNT_ID.dkr.ecr.$DEFAULT_AWS_REGION.amazonaws.com/consultation-app:latest"

docker push "$AWS_ACCOUNT_ID.dkr.ecr.$DEFAULT_AWS_REGION.amazonaws.com/consultation-app:latest"
```

### After code changes

Repeat the **build → tag → push** steps, then trigger a **Deploy** on the App Runner service (if using manual deployments).

---

## App Runner checklist (short)

- **Container port:** `8000`
- **Health check path:** `/health`
- **Environment variables:** `CLERK_SECRET_KEY`, `CLERK_JWKS_URL`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`
- **ECR image:** e.g. `consultation-app:latest`

Full console walkthrough, IAM policies, budgets, and debugging: **[`day5.md`](./day5.md)**.

---

## Local Next.js dev (`npm run dev`)

```bash
npm install
npm run dev
```

The app is configured for **`output: "export"`** for production builds. Local `next dev` is still useful for UI work; **`/api/consultation` is implemented in FastAPI**, not in Next API routes, so end-to-end streaming is easiest to verify with **Docker on port 8000** unless you add your own proxy to a local `uvicorn` process.

---

## Useful npm scripts

| Script                  | Command                         |
| ----------------------- | ------------------------------- |
| Dev server              | `npm run dev`                   |
| Production static build | `npm run build` (writes `out/`) |
| Lint                    | `npm run lint`                  |

---

## References

- **[`day5.md`](./day5.md)** — AWS account setup, ECR, App Runner, cost notes, troubleshooting
- [AWS App Runner documentation](https://docs.aws.amazon.com/apprunner/)
- [Docker documentation](https://docs.docker.com/)
