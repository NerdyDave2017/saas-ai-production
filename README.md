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

---

## Environment variables

**Local:** `.env.local` (do not commit)

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
- `CLERK_SECRET_KEY`
- `CLERK_JWKS_URL`
- `OPENROUTER_API_KEY`
- `OPENROUTER_BASE_URL`

**Deployed (Vercel CLI example):**

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

- [Next.js Documentation](https://nextjs.org/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Clerk Documentation](https://clerk.com/docs)
