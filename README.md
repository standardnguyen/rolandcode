# Rolandcode

A fork of [OpenCode](https://github.com/anomalyco/opencode) that bakes the model catalog into the binary at build time, removes the web-UI fallback proxy, and strips references to the vendor's hosted sharing/search/proxy endpoints from the source tree.

Most of what upstream calls out to is opt-in (session sharing, GitHub integration, the Zen hosted provider) or gated behind a permission prompt (Exa web search) — setting the right config does the job for those. Rolandcode removes the code paths anyway, belt-and-suspenders, and runs `scripts/verify-clean.sh` on every build so new references can't silently reappear on a sync.

The name is from Browning's *Childe Roland to the Dark Tower Came*.

> **Correction (2026-04-17):** An earlier version of this README claimed OpenCode "silently transmits data" via PostHog, Honeycomb, and a list of other endpoints. That was overstated. After [this r/LocalLLaMA comment from u/Spotty_Weldah](https://www.reddit.com/r/LocalLLaMA/comments/1s2q4et/opencode_source_code_audit_7_external_domains/) — the author of the original source-code audit, who walked back their own framing after going deeper — I went back through the source myself: PostHog lives in a GitHub Actions download-stats cron, Honeycomb lives in the cloud-console Lambda, and most of the remaining endpoints are opt-in or permission-gated in upstream. The genuinely default-on, in-CLI calls are the `models.dev` startup fetch and the `app.opencode.ai` web-UI fallback proxy — those are the real reason the fork exists. Sorry for the overclaim, and thanks to Spotty_Weldah for the correction.

---

## What's stripped, and what it actually does in upstream

| Endpoint | Upstream behavior | Category |
|----------|------------------|----------|
| `models.dev` | Fetched on startup to populate the model catalog. Redirectable via `OPENCODE_MODELS_URL`. | **Default-on** — baked from snapshot at build time instead |
| `app.opencode.ai` | Fallback proxy in the web-UI route (`src/server/ui/index.ts`) when embedded UI assets are absent | **Default-on for web-UI users** — proxy code removed |
| `opncd.ai` / `api.opencode.ai` | Session sharing. Only fires after `/share`, `share: auto` in config, or `OPENCODE_AUTO_SHARE=1` | Opt-in upstream; code path removed |
| `opencode.ai/zen/v1` | Hosted provider ("Zen"/"Go"). Only if the user signs up at opencode.ai/zen and configures the provider | Opt-in upstream; code path removed |
| `mcp.exa.ai` | Web search. Invoked by the `websearch` tool after the user approves a permission prompt | Permission-gated upstream; code path removed |
| `us.i.posthog.com` | Download-stats cron in `script/stats.ts` + `.github/workflows/stats.yml`. Not built into the CLI. | Not in upstream CLI; source kept clean as a guard |
| `api.honeycomb.io` | Cloud-console Lambda log processor in `packages/console/`. Not built into the CLI. | Not in upstream CLI; source kept clean as a guard |

At this point, those first two rows are the real reasons the fork exists. That and inertia. The rest is defense-in-depth — config drift, a future regression, or a silent upstream change can't put them back.

## Installation

Download a binary from the [releases page](https://github.com/standardnguyen/rolandcode/releases), or run with Docker:

```bash
docker run --rm -it -v "$PWD:/workspace" -w /workspace ghcr.io/standardnguyen/rolandcode
```

### Building from source

```bash
git clone https://github.com/standardnguyen/rolandcode.git
cd rolandcode
bun install

# Download a model catalog snapshot
curl -fsSL -o models-api.json https://models.dev/api.json

# Build
MODELS_DEV_API_JSON=$PWD/models-api.json bun run --cwd packages/opencode build --single
```

The binary is at `packages/opencode/dist/opencode-linux-x64/bin/rolandcode` (or the equivalent for your platform).

### Building from a fresh Debian container

If you're starting from a bare Debian 12 install (container, VM, or cloud instance):

```bash
# Prerequisites
apt-get update && apt-get install -y git curl unzip

# Install Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Build from source
git clone https://github.com/standardnguyen/rolandcode.git
cd rolandcode
bun install
curl -fsSL -o models-api.json https://models.dev/api.json
MODELS_DEV_API_JSON=$PWD/models-api.json bun run --cwd packages/opencode build --single

# Verify it's clean
bash scripts/verify-clean.sh

# Run it
./packages/opencode/dist/opencode-linux-x64/bin/rolandcode
```

Or build with Docker (no Bun required):

```bash
git clone https://github.com/standardnguyen/rolandcode.git
cd rolandcode
docker build -t rolandcode .
docker run --rm -it -v "$PWD:/workspace" -w /workspace rolandcode
```

## Verification

Every build can be verified clean:

```bash
bash scripts/verify-clean.sh
```

This greps the entire source tree for the known domains and SDK packages. If any reference remains, the build fails. Mechanical, not clever — but it catches regressions on upstream syncs.

## How it works

Rolandcode maintains a small patch set on top of upstream. Each strip commit targets one concern:

- `strip-models-dev` — runtime model-list fetch; replaced with a build-time snapshot
- `strip-app-proxy` — `app.opencode.ai` web-UI fallback proxy
- `strip-share-sync` — automatic session sharing
- `strip-opencode-api` — `api.opencode.ai` / `opncd.ai` endpoints
- `strip-zen-gateway` — Zen hosted-provider routing
- `strip-exa` — `mcp.exa.ai` web search
- `strip-posthog` — removes `script/stats.ts` references so the domain can't drift into the CLI
- `strip-honeycomb` — same for `packages/console` Honeycomb references

Small, isolated commits rebase cleanly when upstream moves.

## Testing

```bash
# Full suite (runs permission tests in Docker when running as root)
bash scripts/test.sh

# Just the main suite
cd packages/opencode && bun test --timeout 30000

# Just the permission tests (must be non-root, or use Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Known test issues

| Test | Status | Why |
|------|--------|-----|
| `session.llm.stream` (2 of 10) | Flaky | Mock HTTP server state leaks between parallel tests. Passes 10/10 when run in isolation (`bun test test/session/llm.test.ts`). Upstream test isolation bug — not a code defect. |
| `tool.write > throws error when OS denies write access` | Fails as root | Root bypasses `chmod 0o444`. Passes in Docker as non-root. `scripts/test.sh` handles this automatically. |
| `tui config > continues loading when legacy source cannot be stripped` | Fails as root | Same root-vs-chmod issue. Passes in Docker as non-root. |
| `fsmonitor` (2 tests) | Skipped | Windows-only (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Skipped | Windows-only. |
| `unicode filenames modification and restore` | Skipped | Upstream explicitly skipped — known bug they haven't fixed. |

## Upstream

This is a fork of [anomalyco/opencode](https://github.com/anomalyco/opencode) (MIT license). All original code is theirs. The full upstream commit history is preserved — you can see exactly what was changed and why.

OpenCode is a capable AI coding agent with a great TUI, LSP support, and multi-provider flexibility. I use it because it's good software. The strips exist because I'd rather not keep `OPENCODE_MODELS_URL` and a careful config review in my head on every invocation.

## License

MIT — same as upstream. See [LICENSE](LICENSE).
