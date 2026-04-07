# SaaS AI Production — MediNotes Pro

Full-stack **healthcare consultation assistant**: Next.js (Pages Router) + **FastAPI**, **Clerk** auth and **Clerk Billing**, and **SSE** streaming markdown. Doctors enter visit notes (patient name, date, free text) and get three sections—**record summary**, **next steps for the clinician**, and a **patient-friendly email draft**.

This README is the **single entry point** for **`main`**. It merges what used to live across feature branches (`idea-generation`, `healthcare`, `aws-deployment`) so you have one place for history, layout, env vars, and deploy paths.

---

## How the branches relate

| Branch | Role (historical / optional checkouts) |
| --- | --- |
| **`main`** | Current integrated codebase: consultation UI, static export, `api/index.py` (Vercel) + `api/server.py` (Docker / App Runner). |
| **`idea-generation`** | Earlier **Business Idea Generator** on Vercel: streaming ideas, same Clerk + billing + FastAPI stack; evolved into the product you see now. |
| **`healthcare`** | **MediNotes Pro** pivot: consultation form (`react-datepicker`), `POST /api` + `Visit` model, healthcare landing and prompts. |
| **`aws-deployment`** | Same app packaged as **one Docker image**: Next static `out/` + FastAPI on port **8000**, ECR + **AWS App Runner**. |

---

## Product features (current)

- **`/product`** — `Protect` + **`premium_subscription`** + `PricingTable`; subscribed users see **ConsultationForm** with validated fields.
- **Streaming** — `@microsoft/fetch-event-source` POST + **SSE** (`text/event-stream`); `react-markdown` + `remark-gfm` / `remark-breaks` and `.markdown-content` in `styles/globals.css`.
- **Backend** — OpenAI SDK pointed at **OpenRouter** (`OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`); JWT verification via **`fastapi-clerk-auth`** and **`CLERK_JWKS_URL`**.

**Stack:** Next.js **16** (Pages Router), TypeScript, Tailwind **4**, **`@clerk/nextjs` ~6.39.x** (v7 removed APIs this UI still uses).

---

## Architecture: Vercel vs Docker

| Aspect | Vercel (default Python integration) | Docker / AWS App Runner |
| --- | --- | --- |
| Frontend | Next.js build (this repo uses **`output: "export"`** for static output) | Static files from `out/` copied into the image as **`static/`**, served by FastAPI |
| API module | **`api/index.py`** | **`api/server.py`** (`uvicorn`, port **8000**) |
| Typical API path | **`POST /api`** (FastAPI app mounted at `/api` on Vercel) | **`POST /api/consultation`** (as implemented in `server.py`) |
| Health | Platform | **`GET /health`** |
| Deploy | `vercel link` / `vercel --prod` | `docker build` → ECR → App Runner (see **Docker** below) |

**Route alignment:** `pages/product.tsx` calls **`fetchEventSource("/api/consultation", …)`**. That matches **`api/server.py`**. The Vercel handler in **`api/index.py`** defines **`@app.post("/api")`** — depending on how Vercel mounts the app, you may need the client URL and handler path to match your deployment (e.g. adjust the client to `/api` or add a `/api/consultation` route in `index.py`). For **local full-stack** streaming with the Docker setup, use **http://localhost:8000** (same origin for UI + API).

---

## Repository layout

```
├── pages/
│   ├── _app.tsx           # ClerkProvider, datepicker CSS, globals
│   ├── _document.tsx      # Title / meta (healthcare)
│   ├── index.tsx          # Landing (MediNotes Pro)
│   └── product.tsx        # Protect, PricingTable, consultation + SSE client
├── api/
│   ├── index.py           # FastAPI for Vercel (consultation stream)
│   └── server.py          # FastAPI + static site for Docker / App Runner
├── styles/globals.css     # Tailwind + .markdown-content
├── Dockerfile             # Multi-stage: Node build → Python + uvicorn
├── .dockerignore
├── next.config.ts         # output: "export", unoptimized images
├── requirements.txt
└── package.json
```

Vercel usually **auto-detects** Next.js and the Python app under `api/` (often **no `vercel.json`** required).

---

## Environment variables

Store secrets in **`.env.local`** or **`.env`** (never commit). **`.dockerignore`** excludes `.env` from image context.

**Application (local + Vercel + container runtime):**

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Clerk publishable key (client) |
| `CLERK_SECRET_KEY` | Clerk secret (server) |
| `CLERK_JWKS_URL` | JWKS URL for JWT verification in FastAPI |
| `OPENROUTER_API_KEY` | OpenRouter (or compatible) API key |
| `OPENROUTER_BASE_URL` | OpenRouter base URL |

**Docker build (bake into static export):**

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` — pass as **`--build-arg`** when running `docker build`.

**Optional (AWS CLI / ECR tagging):**

- `DEFAULT_AWS_REGION` (e.g. `us-east-1`)
- `AWS_ACCOUNT_ID`

**OpenAI directly:** The Python code is written for OpenRouter. To use OpenAI’s API only, set **`OPENAI_API_KEY`** and change the client in `api/index.py` / `api/server.py` to `OpenAI()` without a custom `base_url`.

**Vercel CLI (add to all environments you use):**

```bash
vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
vercel env add CLERK_SECRET_KEY
vercel env add CLERK_JWKS_URL
vercel env add OPENROUTER_API_KEY
vercel env add OPENROUTER_BASE_URL
```

---

## Local development

```bash
npm install
npm run dev
```

**Note:** Production builds use **`output: "export"`**. `npm run dev` is ideal for UI work. End-to-end **SSE** against FastAPI is most reliable when the API is actually running (**Docker on :8000** or **`uvicorn`** for `server.py`) with the same path the client calls.

Optional, closer to Vercel’s dev proxy:

```bash
vercel dev
```

Behavior may still differ from production for the Python route; use a **deployed preview** when debugging `/api` issues.

---

## Deploy on Vercel

**Prerequisites:** Node.js, [Vercel CLI](https://vercel.com/docs/cli) (`npm i -g vercel`), `vercel login`.

```bash
vercel link
vercel .
vercel --prod
```

Same-origin **Next + `/api`** is easiest to verify on a **preview or production URL**, not only `localhost`.

---

## Docker and AWS App Runner

Multi-stage **`Dockerfile`**: **Node 22** builds the static site (`npm run build` → `out/`); **Python 3.12** runs **`uvicorn server:app`** on **port 8000**.

If your course or fork includes **`day5.md`**, use it for the full AWS console walkthrough (IAM, ECR, App Runner, cost notes). The commands below are the short version.

**Load env into your shell (macOS / Linux):**

```bash
export $(cat .env | grep -v '^#' | xargs)
```

**Build and run locally:**

```bash
docker build \
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" \
  -t consultation-app .

docker run -p 8000:8000 \
  -e CLERK_SECRET_KEY="$CLERK_SECRET_KEY" \
  -e CLERK_JWKS_URL="$CLERK_JWKS_URL" \
  -e OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  -e OPENROUTER_BASE_URL="$OPENROUTER_BASE_URL" \
  consultation-app
```

Open **http://localhost:8000**.

**Apple Silicon → App Runner:** build with **`--platform linux/amd64`**.

```bash
aws ecr get-login-password --region "$DEFAULT_AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$DEFAULT_AWS_REGION.amazonaws.com"

docker build \
  --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" \
  -t consultation-app .

docker tag consultation-app:latest "$AWS_ACCOUNT_ID.dkr.ecr.$DEFAULT_AWS_REGION.amazonaws.com/consultation-app:latest"
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$DEFAULT_AWS_REGION.amazonaws.com/consultation-app:latest"
```

**App Runner checklist**

- Container port: **8000**
- Health check path: **`/health`**
- Runtime env: `CLERK_SECRET_KEY`, `CLERK_JWKS_URL`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`

---

## Clerk Billing

- In the Clerk Dashboard, the plan key must be **`premium_subscription`** — it must match **`Protect`** in `pages/product.tsx`.
- Non-subscribers see **`PricingTable`**; subscribers get the consultation form.

---

## Manual test flow

1. Open the app (deployed URL or **http://localhost:8000** with Docker), sign in.
2. Open **`/product`**.
3. Submit sample patient name, date, and notes.
4. Confirm streamed markdown shows the three intended sections.

---

## Security note

This project is a **demonstration**. Real clinical use needs appropriate regulatory, privacy, and security controls (e.g. HIPAA-style programs where applicable), audit logging, retention, and consent workflows—not provided here.

---

## NPM scripts

| Script | Command                                  |
| ------ | ---------------------------------------- |
| Dev    | `npm run dev`                            |
| Build  | `npm run build` (static export → `out/`) |
| Start  | `npm run start`                          |
| Lint   | `npm run lint`                           |

---

## Troubleshooting

- **405 / wrong path:** Ensure the browser path matches your backend (`/api/consultation` vs `/api`) and method is **`POST`** with **`Content-Type: application/json`**.
- **Date picker unstyled:** Import **`react-datepicker/dist/react-datepicker.css`** in `pages/_app.tsx`.
- **Broken markdown:** Check **`styles/globals.css`** (`.markdown-content`) and **`ReactMarkdown`** plugins in `pages/product.tsx`.
- **403 / long streams:** Long SSE responses can stress JWT/session limits; refresh tokens or shorten tests.
- **Plan not found:** Clerk plan key must match exactly: **`premium_subscription`**.
- **Clerk v7:** This repo targets **`@clerk/nextjs` v6.39.x**; upgrading to v7 may require UI changes.
- **SSE locally:** If streaming fails on `localhost`, test a **deployed** environment where frontend and API share one origin, or run the **Docker** stack on port 8000.

---

## Learn more

- [Next.js Documentation](https://nextjs.org/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Clerk Documentation](https://clerk.com/docs)
- [AWS App Runner](https://docs.aws.amazon.com/apprunner/)
- [Docker Documentation](https://docs.docker.com/)
