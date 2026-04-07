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

# MediNotes Pro — Healthcare Consultation Assistant

Full-stack app on **Vercel**: doctors enter consultation notes (patient name, visit date, free-text notes) and receive **streaming** AI output with three sections—**record summary**, **next steps for the clinician**, and a **patient-friendly email draft**. Auth and paid access use **Clerk**; the API is **FastAPI** behind the same deployment.

This branch is **`healthcare`** (e.g. commit: _feat: migrate to healthcare app_), building on earlier work: streaming Markdown UI, Clerk sign-in, and **Clerk Billing** with plan key `premium_subscription`.

---

## What this branch adds

| Area | Change |
| --- | --- |
| **Product** | `/product` is a **consultation form** (`react-datepicker`, validated fields) instead of a one-click idea generator. |
| **API** | `POST /api` with JSON body `{ patient_name, date_of_visit, notes }` and a **Pydantic** `Visit` model; **SSE** response (`text/event-stream`). |
| **Prompts** | System + user prompts request fixed markdown headings for records, next steps, and patient email. |
| **UI copy** | Landing **MediNotes Pro**, healthcare hero and feature grid; document title _Healthcare Consultation Assistant_. |
| **Global CSS** | `react-datepicker/dist/react-datepicker.css` imported in `pages/_app.tsx`. |

Underlying stack: **Next.js 16** (Pages Router), **TypeScript**, **Tailwind 4**, **`@clerk/nextjs` ~6.39**, **`@microsoft/fetch-event-source`** for POST + SSE.

---

## Repository layout (relevant files)

```
├── pages/
│   ├── _app.tsx           # ClerkProvider, datepicker CSS, globals
│   ├── _document.tsx      # Title / meta for healthcare app
│   ├── index.tsx          # MediNotes Pro landing
│   └── product.tsx        # Protect + PricingTable; ConsultationForm → POST /api
├── api/
│   └── index.py           # FastAPI: consultation_summary, Clerk JWT, streaming
├── styles/globals.css     # Tailwind + .markdown-content (markdown output)
├── requirements.txt
└── package.json
```

Vercel is expected to **auto-detect** Next.js and the Python app under `api/` (no `vercel.json` required for that pattern).
# SaaS AI Production — Business Idea Generator (Vercel)

Full-stack **Business Idea Generator**: Next.js (Pages Router) + FastAPI on **Vercel**, with **Clerk** auth, **SSE streaming**, Markdown UI, and **Clerk Billing** (`premium_subscription`). This README describes the **`idea-generation`** branch, layout, environment variables, and typical CLI workflow.

---

## What this branch contains (vs `main`)

Git history on **`idea-generation`** (newest first):

1. **`feat: add billing`** — Clerk Billing: `Protect` + `plan="premium_subscription"`, `PricingTable`, landing copy (“IdeaGen Pro”, pricing preview).
2. **`feat: add cler user authentication`** — `ClerkProvider`, landing vs `/product`, `@microsoft/fetch-event-source` with `Authorization: Bearer <jwt>`, FastAPI verifies JWT via **`fastapi-clerk-auth`** and **`CLERK_JWKS_URL`**.
3. **`feat: add streaming and improve styling`** — SSE from `GET /api`, `react-markdown` + `remark-gfm` / `remark-breaks`, `@tailwindcss/typography`, gradient layout, `.markdown-content` rules in `styles/globals.css`.

**Stack**

- **Frontend:** Next.js **16** (Pages Router), TypeScript, Tailwind **4**, **`@clerk/nextjs` ~6.39** (v6 keeps `SignedIn`, `SignedOut`, and related patterns used in this codebase).
- **Backend:** `api/index.py` — FastAPI, **streaming** `text/event-stream`, Clerk bearer auth, **OpenAI-compatible** client via **OpenRouter** (`OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`).

> **OpenAI instead of OpenRouter:** This repo’s Python code expects OpenRouter env vars. To use OpenAI directly, set `OPENAI_API_KEY` on Vercel and change `api/index.py` to use `OpenAI()` without a custom `base_url`.

---

## Repository layout

```
├── pages/
│   ├── _app.tsx          # ClerkProvider + global CSS
│   ├── index.tsx         # Landing: sign-in, link to /product
│   └── product.tsx       # Protect + PricingTable; SSE to /api
├── api/
│   └── index.py          # FastAPI app (Vercel Python function)
├── styles/globals.css    # Tailwind + .markdown-content overrides
├── requirements.txt      # fastapi, uvicorn, openai, python-dotenv, fastapi-clerk-auth
└── package.json
```

There is **no `vercel.json`**: Vercel **auto-detects** Next.js and the Python app under `api/`.

---

## Environment variables

**Local:** `.env.local` (do not commit)
**Local (`.env.local` — do not commit)**

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
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
**Deployed (Vercel CLI example):**
**Vercel**

Push the same names for all environments you use (development, preview, production):

```bash
vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
vercel env add CLERK_SECRET_KEY
vercel env add CLERK_JWKS_URL
vercel env add OPENROUTER_API_KEY
vercel env add OPENROUTER_BASE_URL
```

The Python client uses the **OpenAI SDK** against **OpenRouter** (`base_url` + key). To use OpenAI directly instead, set `OPENAI_API_KEY` on Vercel and change `api/index.py` to call `OpenAI()` without a custom `base_url`.

---

## Commands

**Install dependencies** (includes date picker):

```bash
npm install
```

If you are setting up from scratch, the consultation UI also needs:

```bash
npm install react-datepicker
npm install --save-dev @types/react-datepicker
```

**Link and deploy:**

```bash
vercel link
vercel .
vercel --prod
```

**Local Next dev:**
---

## Terminal commands (setup → deploy)

**Prerequisites:** Node.js, [Vercel CLI](https://vercel.com/docs/cli) (`npm i -g vercel`), `vercel login`.

### Dependencies

```bash
npm install
npm install @clerk/nextjs@6.39.0
npm install @microsoft/fetch-event-source
npm install react-markdown remark-gfm remark-breaks
npm install @tailwindcss/typography
```

### Link project and secrets

```bash
vercel link
```

Then add environment variables (see above). If you switch the backend to OpenAI-only, add `OPENAI_API_KEY` instead of the OpenRouter pair.

### Deploy

Preview:

```bash
vercel .
```

Production:

```bash
vercel --prod
```

End-to-end behavior (same origin for Next.js and `/api`) is easiest to verify on a **deployed** preview or production URL rather than only `localhost`.

### Local dev

```bash
npm run dev
```

Full-stack behavior matches production most reliably on a **deployed** Vercel URL (same origin for the Next app and `/api`).

---

## Clerk Billing

- Dashboard plan key must be **`premium_subscription`** to match `Protect` in `pages/product.tsx`.
- Non-subscribers see **`PricingTable`**; subscribers get the consultation form.

---

## Manual test flow

1. Open the deployed site, sign in.
2. Go to **Go to App** / `/product`.
3. Submit sample data (patient name, date, notes).
4. Confirm streamed markdown shows the three intended sections.

---

## Security note

This project is a **demonstration**. Real clinical use needs proper regulatory, privacy, and security controls (e.g. HIPAA-style programs where applicable), audit logging, retention policy, and explicit patient consent workflows—not provided here.

---

## Extended walkthrough (local notes)

Step-by-step narrative that aligns with this feature set—including example inputs, architecture notes, and troubleshooting—is in a separate notes file on your machine:

`/Users/mac/Developer/andela-ai/production/week1/day4.md`

If that folder sits next to this repo, the equivalent relative path is `../production/week1/day4.md`. That file is **not** part of this git repository.
Optional, closer to Vercel’s dev proxy:

```bash
vercel dev
```

The Python function may not behave identically to production under `vercel dev`; use a deployed preview when debugging `/api`.

---

## Clerk Billing

- In the Clerk Dashboard, create a plan whose key is **`premium_subscription`** — it must match the `Protect` `plan` prop in `pages/product.tsx`.
- After UI or config changes: `vercel --prod` (or your usual deploy flow).
- Users without a subscription see **`PricingTable`**; subscribed users get the streaming idea generator.

---

## NPM scripts

| Script | Command         |
| ------ | --------------- |
| Dev    | `npm run dev`   |
| Build  | `npm run build` |
| Start  | `npm run start` |
| Lint   | `npm run lint`  |

---

## Troubleshooting

- **405 / Method not allowed:** Backend must expose **`POST /api`**; the client must use `method: 'POST'` and `Content-Type: application/json`.
- **Date picker unstyled:** Ensure `react-datepicker/dist/react-datepicker.css` is imported in `pages/_app.tsx`.
- **Empty or broken markdown output:** Check `styles/globals.css` for `.markdown-content` rules and that `ReactMarkdown` uses `remarkGfm` / `remarkBreaks` as in `pages/product.tsx`.

---

## Links
- **403 / auth on long streams:** Very long SSE responses can overlap JWT/session limits; ensure tokens refresh as needed or shorten stream duration for testing.
- **Plan not found:** Clerk plan key must match exactly: `premium_subscription`.
- **Clerk major version:** Newer `@clerk/nextjs` v7 removed some components this UI relies on; this project targets **v6.39.x**.
- **Streaming:** If SSE misbehaves locally, test on a **Vercel** deployment where frontend and API share one origin.

---

## Learn more

- [Next.js Documentation](https://nextjs.org/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Clerk Documentation](https://clerk.com/docs)
