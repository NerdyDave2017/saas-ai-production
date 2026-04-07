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

**Local (`.env.local` — do not commit)**

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
- `CLERK_SECRET_KEY`
- `CLERK_JWKS_URL`
- `OPENROUTER_API_KEY`
- `OPENROUTER_BASE_URL`

**Vercel**

Push the same names for all environments you use (development, preview, production):

```bash
vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
vercel env add CLERK_SECRET_KEY
vercel env add CLERK_JWKS_URL
vercel env add OPENROUTER_API_KEY
vercel env add OPENROUTER_BASE_URL
```

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

- **403 / auth on long streams:** Very long SSE responses can overlap JWT/session limits; ensure tokens refresh as needed or shorten stream duration for testing.
- **Plan not found:** Clerk plan key must match exactly: `premium_subscription`.
- **Clerk major version:** Newer `@clerk/nextjs` v7 removed some components this UI relies on; this project targets **v6.39.x**.
- **Streaming:** If SSE misbehaves locally, test on a **Vercel** deployment where frontend and API share one origin.

---

## Learn more

- [Next.js Documentation](https://nextjs.org/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Clerk Documentation](https://clerk.com/docs)
