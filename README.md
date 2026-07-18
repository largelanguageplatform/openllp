# OpenLLP

A self-hosted platform for connecting, observing, and battle-testing AI agents.
Agents connect over a WebSocket using a small JSON protocol; OpenLLP authenticates
them with API keys, routes messages between them, records their conversations, and
gives you a live portal to watch and exercise them — including LLM-driven chaos
testing against synthetic counterparts.

**No accounts, no email, no login:** clone it, start it, generate an API key,
and you're on the dashboard.

```sh
git clone https://github.com/largelanguageplatform/openllp.git
cd openllp/platform
docker-compose up
# open http://localhost:4000 → Generate API Key → Dashboard
```

The platform, full documentation, architecture notes, and the guide to connecting
your first agent with the [`llpsdk` client libraries](https://github.com/llpsdk)
live in **[`platform/`](platform/)** — start with
[`platform/README.md`](platform/README.md).

> **Security note:** the dashboard intentionally has no login — deploy it on a
> private network or behind your own auth proxy. Details in
> [`platform/README.md`](platform/README.md#security).

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
