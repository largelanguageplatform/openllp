# OpenLLP

An Elixir/Phoenix platform for connecting, observing, and testing AI agents. Agents connect over a WebSocket
using a small JSON protocol; the platform authenticates them, routes messages between them, records their
conversations, and gives each organization a live web portal to watch and exercise its agents.

## Quick Start with Docker Compose

The easiest way to run the platform with all dependencies:

```bash
make up
# or
docker-compose up
```

This will start:
- PostgreSQL database on port 5432
- Platform web app and API on port 80 (container port 4000)

**First run:** open http://localhost — you land directly on API-key setup
(no account, no email, no login). Generate a key, continue to the dashboard,
and connect your agents with that key. Agents connect via WebSocket to
`/agent` on the same HTTP port.

### Useful Commands

```bash
make up              # Start platform and dependencies
make up-detached     # Start in background
make down            # Stop all services
make restart         # Rebuild and restart
make logs            # View platform logs
```

Or use docker-compose directly:
```bash
docker-compose up           # Start services
docker-compose up -d        # Start in detached mode
docker-compose down         # Stop services
docker-compose up --build   # Rebuild and start
```

## Manual Development Setup

### Building
Run `make` for a local build. Run `make docker` to build a local docker image.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Running Locally
After you have generated a release, start the service with `_build/prod/rel/platform/bin/server`.

**Note:** You'll need PostgreSQL running locally with the following credentials:
- Database: `platform`
- User: `platform`
- Password: `localdev`
- Port: `5432`

## Connect a test agent

Agents talk to the platform through the [`llpsdk` client libraries](https://github.com/llpsdk)
(Python, Go, TypeScript, Elixir). Quickest loop, in Python:

```sh
pip install llpsdk        # or: uv add llpsdk
export LLP_API_KEY=...    # the key you generated on first run
export LLP_AGENT_NAME=my-agent
```

```python
import asyncio
import os
import llpsdk as llp

async def main():
    client = llp.Client(
        os.getenv("LLP_AGENT_NAME"),
        os.getenv("LLP_API_KEY"),
        # point the SDK at your self-hosted instance
        config=llp.Config(platform_url="ws://localhost/agent/websocket"),
    )
    client.on_message(lambda ctx, msg: msg.reply(f"echo: {msg.text}"))
    await client.connect()
    await asyncio.Event().wait()

asyncio.run(main())
```

Run it and the agent appears on your portal dashboard; open its logs page to watch messages
in real time. The in-app guide at `/docs` has the full Python/Go/TypeScript walkthroughs,
including tool-call reporting and attachments.

## Architecture

### Agent connectivity

Agents connect to the Phoenix endpoint at `/agent` (`Platform.Agent.Session`, a `Phoenix.Socket.Transport`)
and exchange JSON frames defined in `Platform.Protocol`:

| Type | Purpose |
|------|---------|
| `authenticate` | Presents an organization API key; names the agent |
| `presence` | Announces availability; relayed to interested parties |
| `message` | Direct agent-to-agent message routing |
| `tool_call` | Reports a tool invocation (name, parameters, result, duration) for the conversation log |
| `ack` / `error` | Delivery confirmation and protocol errors |

Each connected agent is one `Platform.Agent.Session` process. `Platform.Agent.Manager` (a GenServer) is the
session registry: it tracks live sessions in two ETS tables — `:sessions` (session id → pid) and
`:session_names` (agent name → session) — and routes direct messages between sessions. Session state that
should survive the connection (login/logout times, conversations, message annotations) is persisted through
the `Platform.Conversations` context.

### Web layer

The web UI is Phoenix LiveView throughout; pages subscribe to `Platform.PubSub` topics, so portal views
update in real time as agents connect and talk.

- **Portal** (`/portal`) — per-organization dashboard of registered agents and their status, with a live
  per-agent conversation/log view.
- **Access model** — single-tenant bootstrap mode: the platform auto-creates one local organization at
  startup and the dashboard has no login (see Security below). The **agent API key** is the system's
  credential, checked on the agent WebSocket.
- **Admin** — a separately-authenticated back office for managing domains and personas.
- **HTTP API** (`/api/v1`) — bundle upload/download and attachment storage for agents.

### Chaos testing

`Platform.Chaos` provides synthetic, LLM-driven counterpart agents. An orchestrator (one `DynamicSupervisor`
per side) spins up chaos agents that hold scripted-yet-generative conversations with a real connected agent
to exercise it; results land in the same conversation log the portal displays.

### Source layout

```
platform/
├── lib/
│   ├── platform/            # Business logic
│   │   ├── account/         # Organizations, members, tokens
│   │   ├── admin/           # Back-office admin users
│   │   ├── agent/           # Agent, session, manager, API keys, bundles, domains
│   │   ├── chaos/           # Chaos-testing orchestrator and synthetic agents
│   │   ├── conversations/   # Persisted sessions, conversations, messages
│   │   └── protocol/        # Wire protocol (authenticate/presence/message/tool_call)
│   └── platform_web/        # Endpoint, router, LiveViews, controllers, components
├── priv/repo/migrations/    # Database schema (single baseline migration)
└── assets/                  # Tailwind + daisyUI, vendored JS
```

### Debugging

```elixir
# In an IEx console attached to a running node:
:ets.tab2list(:session_names)              # All connected agents by name
Platform.Agent.Manager.session_count()     # Number of live sessions
Platform.Agent.Manager.get_agent("name")   # Look up a connected agent
```

## Security

The dashboard intentionally has **no authentication** — like Prometheus or a database admin UI, it is
built for private deployment. Anyone who can reach the HTTP port has full access to the portal and can
manage API keys. Bind it to localhost or a private network, or front it with your own reverse-proxy
auth. The agent WebSocket **is** authenticated (per-organization API keys); the admin back office
(`/sys-ctrl-…`) has its own separate password login.

Dormant schema note: the database schema retains unused multi-tenant auth tables
(`organization_members`, `member_tokens`, `organizations_tokens`) to keep the baseline migration
stable; no code reads or writes them.

## License

Apache License 2.0 — see [LICENSE](../LICENSE) and [NOTICE](../NOTICE) at the repository root.
