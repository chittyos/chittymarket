# LLM Routing — chittyclaw / OpenClaw / ai-parity

Load for LLM-routing, model-selection, OpenClaw gateway, or cross-client AI-config tasks.

## The chain

**OpenClaw gateway → provider selection → Cloudflare AI Gateway (the Model Router) → underlying model.**

- **Canonical router = Cloudflare AI Gateway**, not the client (ADR-001 §3: it owns model routing, provider abstraction, fallback, observability). Clients point at the OpenAI-compat endpoint:
  `https://gateway.ai.cloudflare.com/v1/0bc21e3a5a9de1a4cc843be9c3e98121/chittyclaw/compat` (`api: openai-completions`).
- Constants (non-secret): CF account `0bc21e3a5a9de1a4cc843be9c3e98121` (ChittyCorp LLC), AI Gateway id `chittyclaw`.
- **Credential:** `CLOUDFLARE_ISSUED_CHITTYCLAW_AI_GATEWAY_TOKEN` (VM/systemd canonical). Deprecated/host-variant aliases — do not add consumers: `CLOUDFLARE_AI_GATEWAY_API_KEY`, `OPENAI_API_KEY`, `CHITTYCLAW_TOKEN`, `CF_ISSUED_AIGATEWAY_TOKEN` (the Mac/launchd variant). Never place/read it yourself — route through the broker (see `secrets.md`).

## What chittyclaw is

`chittyclaw` = the operator's ChittyOS-integrated instance of the open-source **OpenClaw** assistant gateway. Naming layers: OpenClaw (upstream) → chittyclaw (this deployment) → chittyserv (fabric: `chittyserv-vm` + `chittymini-00..06`) → Ch1tty/myCh1tty (orchestration) → Ch1tty Sovereign (the whole).

- **CORRECTED 2026-07-30 (verified live).** The gateway runs **on the `chittyclaw` tailnet node itself** (`100.69.69.7`, hostname `chitty`), as **Docker Compose**, not as a systemd unit on `chittyserv-vm`:
  - `~/openclaw-prod/docker-compose.yml`, OpenClaw **2026.6.34**, two containers:
    - `openclaw-prod-openclaw-gateway-1` — healthy, binds `0.0.0.0:3978` and `0.0.0.0:18789-18790`
    - `openclaw-prod-openclaw-cli-1` — **the CLI surface; use this for inference, not the gateway HTTP API directly**
  - Reach it with `ssh chittyclaw`, then `docker exec openclaw-prod-openclaw-cli-1 openclaw ...`
- The `openclaw-gateway.service` systemd unit on `chittyserv-vm` is a **stale duplicate — dead since 2026-07-18 07:55 UTC.** Its `EnvironmentFile=-/home/ubuntu/.openclaw/secrets/chittyclaw.env` does not exist (dir empty, mtime = the minute it died); because the `-` prefix makes the file optional, systemd starts it and the process then aborts on the missing var, crash-looping (~9s CPU/cycle). Nothing depends on it. Do not "restore" it — delete the unit.
- Exposed only via Tailscale Serve (443/8443 → :18789) + Cloudflare Tunnel (`claw.chitty.cc`). Never bind public.

## Models & routing

- Providers: **`chittyclaw`** (CF AI Gateway `/compat`) → Workers AI (`@cf/meta/llama-3.3-70b-instruct-fp8-fast`, `@cf/meta/llama-3.1-8b-instruct`, `@cf/qwen/qwen2.5-coder-32b-instruct`); **`ollama`** (local `127.0.0.1:11434`, `glm-5.1:cloud`) = on-box/offline fallback.
- **In transition:** default `primary` moving from the fixed Workers-AI model to CF AI Gateway **Dynamic Route `chittyclaw/dynamic/three-wise-men`** (server-side model selection/fallback). Live VM template still shows the fixed model; persona worktree + Mac launchd instance have moved. **The route's member-model/fallback definition is server-side in CF, not in these repos** — look it up in the AI Gateway dashboard/API before relying on its behavior.
- **Auth is NOT off** (doc was stale). The gateway **hard-requires `CLOUDFLARE_ISSUED_CHITTYCLAW_AI_GATEWAY_TOKEN` at startup and fails closed** — `SecretRefResolutionError` → `Startup failed: required secrets are unavailable`. Placing that value is broker/`chico` work; never resolve it yourself.
- **CLI invocation gotcha:** `--model` needs `<provider>/<catalog-id>`, and the catalog id itself contains a slash. `openclaw infer model list` shows `dynamic/three-wise-men`, but the working argument is `cloudflare-ai-gateway/dynamic/three-wise-men`. Passing the bare id fails `Unknown model`.
- **Use the wrapper, do not hand-roll the invocation.**
  `~/.claude/skills/nb-development-defaults/scripts/adversarial-review.sh` encodes the whole loop:
  ```
  git diff main...HEAD -- src/ | adversarial-review.sh - -p "focus on auth bypass"
  ```
  It checks the container is actually running first (a dead node exits **2** with
  `POLICY_BLOCKED_CHITTYCLAW_UNAVAILABLE` rather than returning an empty review that could be
  misread as "no findings"), strips the CLI's config/doctor chrome, and exits **3** on a model/route
  failure. Never report a change as reviewed on a non-zero exit.

- **`dynamic/adversarial-reviewer` is BROKEN** (verified 2026-07-30): the catalog advertises it as configured+available ("ChittyClaw Cost-Conscious Adversarial Reviewer"), but calls return `400 {"code":2005,"message":"Failed to get response from provider"}`. The route definition is server-side in CF AI Gateway. Until fixed, the separated-review workflow silently degrades — fall back to `cloudflare-ai-gateway/dynamic/three-wise-men` and say so in the review output.

## OpenClaw & ai-parity

- **OpenClaw** = multi-channel assistant runtime (Telegram, group chats, heartbeat/cron, skills, MCP client) with per-agent workspace memory — one of the "synthetic team" clients alongside Claude and Codex.
- **ai-parity** = the config-distribution layer (NOT a router). One canonical git repo renders config into `~/.codex`, `~/.claude`, and OpenClaw across machines; separates `portable/` from `machine/`-local state; auto-sync via timer. **Config is distributed via ai-parity, not hand-edited per machine.**
- ChittyOS tools reach LLM clients via **MCP**: Ch1tty `127.0.0.1:9099/mcp`, cowork bridge `127.0.0.1:8850/mcp`, plus Ch1tty's reverse `/openclaw/*` skill facade.

## Deploy / verify

- IaC root: `/Volumes/chitty/Workspace/openclaw/` (repo `chittycorp/ops`). Redeploy: `hosts/chittyserv-vm/apply.sh` (idempotent; mode-600 env-file, systemd unit, health + provider smoke test). NOTE: 1Password/`op run` is RETIRED — if `apply.sh` still renders via `op run`, it needs migrating to the ChittySecrets/Secrets-Store path; verify the script before relying on this line.
- Service: `systemctl --user restart openclaw-gateway`; smoke test `openclaw infer model providers` (confirm `provider: chittyclaw` configured+selected).

## In-transition / gaps

- Planned migration chittyclaw → addressable `chittyagent-chittyclaw` Cloudflare Worker (once `@chittyos/chittyagent-sdk` lands).
- Per-env secret separation: the old 1P-SA vault blocker is OBSOLETE (1P retired). Per-env separation now lives in the ChittySecrets / Cloudflare Secrets Store model — revisit against that plane, not 1P vaults.
- VM (systemd, `CLOUDFLARE_ISSUED_…`) vs Mac (launchd `ai.openclaw.gateway`, `CF_ISSUED_AIGATEWAY_TOKEN`) env-name divergence unresolved.
