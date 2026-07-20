# OpenLLP PDF Agent

Generates realistic financial documents — invoices, W-2s, 1099-NECs, receipts, and
bank statements — as PDFs, for use as attachments in OpenLLP's chaos test personas.
It exposes a small HTTP API the platform calls; each endpoint renders a document,
uploads it to the platform's storage bucket via a signed URL, and returns the
stored file's name and location.

## Running it

With Docker Compose it comes up automatically as the `pdf-agent` service — you only
need to give it an API key so it can request signed upload URLs:

1. Start the stack once (`docker compose up`), open http://localhost:4000, and
   **Generate API Key**.
2. Put it in your environment and restart:

   ```sh
   export PDF_AGENT_API_KEY=<the key you generated>
   docker compose up -d pdf-agent
   ```

Without a key the service still starts and serves HTTP, but uploads will fail until
one is provided. Text-only test personas (e.g. `tax_noob`, `weather`) don't need the
PDF agent at all.

## HTTP API

`POST /invoice`, `/w2`, `/receipt`, `/1099-nec`, `/bank-statement` — each takes the
document's data as JSON and returns `201 {"location": "...", "filename": "..."}`.
`location` is a URL the platform serves the stored PDF from.

## Rendering

Invoices and W-2s render with the pure-Go [`fpdf`](https://github.com/go-pdf/fpdf)
library. Receipts, 1099-NECs, and bank statements are HTML templates rendered to PDF
with headless Chromium (via [`go-rod`](https://github.com/go-rod/rod)) — which is why
the Docker image bundles Chromium.

## Configuration

| Variable | Purpose |
|---|---|
| `LLP_API_KEY` | Platform API key, for requesting signed upload URLs (required for uploads) |
| `LLP_API_URL` | Platform HTTP API base (default `http://localhost:4000/api/v1`) |
| `OLLAMA_HOST` / `OLLAMA_API_KEY` / `OLLAMA_MODEL` | LLM used to fabricate document contents when running in agent mode |
| `USE_PLATFORM=1` | Also connect to the platform as a WebSocket agent named `pdf-agent` |

## License

Apache License 2.0 — see the [repository root](../../LICENSE).
