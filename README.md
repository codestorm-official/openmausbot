# Deploy and Host OpenMausBot on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/openmausbot-2?referralCode=indah&utm_medium=integration&utm_source=template&utm_campaign=generic)

OpenMausBot is an open-source chat app where every contact is an AI agent. Each bot runs a real Claude Code or Codex agent with its own model, memory, tools, browser and connected apps. This template runs the official server always-on behind an HTTPS edge, with every chat, login and workspace stored on a Railway volume.

## About Hosting OpenMausBot

OpenMausBot runs as one service: a small harness server owns each agent process, serves the web app and API, and keeps transcripts, routines and webhook state in `/data`. Agents work as ordinary processes inside the container, using the Claude Code and Codex CLIs baked into the image and your own subscriptions or API keys. A bundled Chrome gives each bot an isolated browser session. Caddy runs in the same container as the only public listener, keeps OpenMausBot on loopback, forwards the real client address and streams events without buffering. Sign-in uses OpenMausBot's own email allow-list; no separate identity provider or database is required.

## Common Use Cases

- An always-on team of coding and research bots on a Claude or ChatGPT plan.
- Bots that browse the web, fill forms and collect data in persistent browser sessions.
- Scheduled routines, such as a morning digest or weekly report, that run with every laptop closed.
- Webhook-driven bots that react to GitHub, Stripe or form events.
- A small shared workspace with admin and chat-only members.

## Dependencies for OpenMausBot Hosting

- A Claude Pro/Max subscription, a ChatGPT plan, or API keys for the models the bots should use.
- An email address for the first sign-in; OpenMausBot sends a one-time code from its account service.
- A Railway plan with at least 2 GB of RAM for one working bot. Add roughly 0.7 GB per concurrent bot and 0.4 GB per open browser.
- Optional: a Boat API key for hosted Linux desktops, and a Composio key for connected apps such as Gmail, Slack or GitHub.
- One Railway volume mounted at `/data`; no external database, Redis or queue.

### Implementation Details

| Component | Source | Purpose |
| --- | --- | --- |
| OpenMausBot | `ghcr.io/milind-soni/openmausbot:v0.1.175`, pinned by digest | Web app, API, agents, routines, webhooks and bots' browser on loopback |
| Caddy | `caddy:2.10.2`, pinned by digest | Public HTTPS edge on Railway's `PORT`, reverse proxy, SSE and WebSocket passthrough |
| Engines | `@anthropic-ai/claude-code` and `@openai/codex`, pinned in the Dockerfile | Agent CLIs are available immediately, with sign-in and model selection handled inside the app |
| State | Railway volume at `/data` | SQLite/DuckDB, chats, bot workspaces, engine logins, browser profiles and paired sessions |

The container starts as root only to repair ownership of a fresh or restored `/data` volume, then drops to the unprivileged `maus` user for OpenMausBot and a separate `caddy` user for the edge. One replica is intentional: state is stored in SQLite and files, not in a shared database.

## Why Deploy OpenMausBot on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenMausBot on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

## Comparison with Alternatives

✅ = built-in or managed; ❌ = unavailable or requires significant extra work.

| Capability | This template | OpenMausBot on a VPS | Closed AI chat apps |
| --- | --- | --- | --- |
| Managed HTTPS, domain and restarts | ✅ | ❌ manual proxy and service setup | ✅ |
| Always-on routines and webhooks | ✅ | ✅ if the server is maintained | Varies |
| Persistent chats, agent logins and workspaces | ✅ volume at `/data` | ✅ manual volume or disk | ❌ data stays with the vendor |
| Bring your own Claude/ChatGPT plan or API key | ✅ | ✅ | ❌ |
| Per-bot isolated browser | ✅ bundled Chrome | ✅ after installing browser libraries | Varies |
| Local VM or control of your own desktop | ❌ container platform | ✅ with Docker and the desktop app | ❌ |
| Infrastructure maintenance | Railway-managed | You manage OS, TLS, updates and backups | Vendor-managed |
| Data ownership and portability | ✅ | ✅ | ❌ |

## Security Considerations

- Every bot runs as the unprivileged `maus` user but shares `/data` with the server. A bot's shell can read chats, saved API keys, engine logins and other bots' files. New bots start at the most permissive approval level; choose **Ask for approval** for bots that touch sensitive accounts.
- Bots can reach the public internet and any other service in the same Railway project over the private network. Keep unrelated databases and credentials out of this project, and connect only the accounts the bots should use.
- The email allow-list is the admin boundary. Treat Railway project access as equivalent to server owner access, and review paired devices regularly.
- Public, session-less routes are limited to the sign-in pages, static app files, health and environment descriptors, and `/hooks/*` webhook URLs that carry their own secrets. Everything else requires a paired session.
- The template runs a single replica. Do not scale it horizontally: SQLite, browser profiles and bot workspaces are local to the volume.
- The container drops privileges after preparing the volume. The edge runs as its own user and cannot read engine logins or bot data.

## License

OpenMausBot is licensed under the Apache License 2.0. This repository contains deployment packaging and documentation only; it is not affiliated with or endorsed by OpenMausBot or Supamaus Software.
