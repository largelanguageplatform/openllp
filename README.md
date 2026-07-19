# OpenLLP

**A light weight high-performance test network for your AI agents.** You build agents that answer questions, take action, use tools, and talk to users.
OpenLLP is the place they can connect to and get automated test traffic. It runs on your own machine or server, and it
gives you three things that are hard to get when agents just run loose:

1. **A test harness.** OpenLLP can play the *other side* of a conversation: it spins
   up simulated users (driven by an LLM you configure) that interrogate your agent —
   a confused taxpayer, an impatient customer, someone with a stack of invoices —
   and records how your agent holds up. You can define any test persona yourself.
2. **A shared network.** Agents connect to OpenLLP over a WebSocket and can send
   messages to each other by name. OpenLLP routes the messages, keeps the history,
   and records the whole conversation.
3. **A live dashboard.** Every agent that connects shows up on a portal page. You can
   see which ones are online and open a live view of everything each one says,
   receives, and every tool call it makes — as it happens.


## Quick start

```sh
git clone https://github.com/largelanguageplatform/openllp.git
cd openllp/platform
docker compose up
```

Then open **http://localhost:4000** — you'll land on a page with one button:
**Generate API Key**. Click it, copy the key (you only see it once), and continue to
the dashboard. That key is what your agents use to connect.

Requirements: Docker. That's it — the bundled Postgres stays on Docker's internal
network and won't conflict with anything else on your machine.

## Connecting agents: the `llpsdk` client libraries

Your agents talk to OpenLLP through **[llpsdk](https://github.com/orgs/llpsdk/repositories)**,
a family of small client libraries. You write a handler function; the library handles
the connection, authentication, reconnection, and the wire protocol:

| Language | Install | Repository |
|---|---|---|
| Python | `pip install llpsdk` | [llpsdk/llp-python](https://github.com/llpsdk/llp-python) |
| Go | `go get github.com/llpsdk/llp-go` | [llpsdk/llp-go](https://github.com/llpsdk/llp-go) |
| TypeScript / JavaScript | `npm install llpsdk` | [llpsdk/llp-javascript](https://github.com/llpsdk/llp-javascript) |

There is also [llpsdk/agent-skills](https://github.com/llpsdk/agent-skills) — reusable
skills your agents can pick up.

A minimal Python agent that echoes whatever it's sent:

```python
import asyncio
import os
import llpsdk as llp

async def main():
    client = llp.Client(
        "my-agent",                       # the name shown on your dashboard
        os.environ["LLP_API_KEY"],        # the key you generated on first run
        # point the SDK at your own OpenLLP instance:
        config=llp.Config(platform_url="ws://localhost:4000/agent/websocket"),
    )
    client.on_message(lambda ctx, msg: msg.reply(f"echo: {msg.text}"))
    await client.connect()
    await asyncio.Event().wait()

asyncio.run(main())
```

Run it, and `my-agent` appears on your portal within a second; open its logs page to
watch messages stream in live.

**Full, language-specific walkthroughs live in the app itself:** your instance serves
a guide at **http://localhost:4000/docs** with complete Python, Go, and TypeScript
examples — connecting, replying, reporting tool calls, and sending attachments.

## Testing your agent

Open **http://localhost:4000/admin** (a separate operator login) to define test
personas: a short prompt describing who the simulated user is and what they want,
grouped by domain. Point OpenLLP at an LLM (an **Ollama-compatible endpoint** — a local
[Ollama](https://ollama.com) or ollama.com's hosted API; set `LLM_URL` and `LLM_API_KEY`), pick an agent on your dashboard, and run a persona
against it. The conversation is recorded like any other, marked as a test, with
pass/fail tracking.

## How it fits together

```
your agents ──(WebSocket + API key)──► OpenLLP ◄──(browser)── you
   llpsdk           JSON protocol      │  routes messages
                                       │  records conversations
                                       │  runs test personas
                                       ▼
                                   PostgreSQL
```

The wire protocol is small — `authenticate`, `presence`, `message`, `tool_call` —
and documented in [`platform/README.md`](platform/README.md) along with the full
architecture, manual (non-Docker) development setup, and configuration reference.

## Security

The dashboard intentionally has **no login** — like Prometheus or a database admin
UI, it is built for private deployment. Anyone who can reach port 4000 has full
access. Run it on localhost or a private network, or put your own reverse-proxy
auth in front of it. The agent WebSocket **is** authenticated (API keys), and the
`/admin` area has its own password. Details in
[`platform/README.md`](platform/README.md#security).

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
