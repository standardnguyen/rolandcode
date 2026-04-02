# Rolandcode

A clean fork of [OpenCode](https://github.com/anomalyco/opencode) with all telemetry and phone-home behavior removed.

OpenCode markets itself as "privacy-first" and "open source," but silently transmits data to multiple third-party services — analytics (PostHog), telemetry (Honeycomb), session sharing (opncd.ai), prompt proxying (opencode.ai/zen), search query forwarding (mcp.exa.ai), and IP-leaking model list fetches (models.dev). The maintainers initially denied telemetry existed ([#459](https://github.com/sst/opencode/issues/459)), then acknowledged it. Users report that disabling telemetry in config doesn't fully stop outbound connections ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode doesn't try to convince OpenCode to change. It just strips their telemetry and ships clean builds.

The name is from Browning's *Childe Roland to the Dark Tower Came* — Roland reaches the tower despite everything trying to stop him.

---

## What's removed

| Endpoint | What it sent |
|----------|-------------|
| `us.i.posthog.com` | Usage analytics |
| `api.honeycomb.io` | Telemetry, IP address, location |
| `api.opencode.ai` | Session content, prompts |
| `opncd.ai` | Session sharing data |
| `opencode.ai/zen/v1` | Prompts proxied through OpenCode's gateway |
| `mcp.exa.ai` | Search queries |
| `models.dev` | Model list fetches (leaks IP) |
| `app.opencode.ai` | Catch-all app proxy |

The model catalog is vendored at build time from a local snapshot — no runtime phone-home.

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

This greps the entire source tree for all known telemetry domains and SDK packages. If any reference remains, the build fails. Grep doesn't lie.

## How it works

Rolandcode maintains a small patch set on top of upstream OpenCode. Each strip commit removes one telemetry concern:

- `strip-posthog` — PostHog analytics
- `strip-honeycomb` — Honeycomb telemetry
- `strip-exa` — mcp.exa.ai search forwarding
- `strip-opencode-api` — api.opencode.ai and opncd.ai endpoints
- `strip-zen-gateway` — Zen proxy routing
- `strip-app-proxy` — app.opencode.ai catch-all proxy
- `strip-share-sync` — Automatic session sharing
- `strip-models-dev` — Runtime model list fetching

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

OpenCode is a capable AI coding agent with a great TUI, LSP support, and multi-provider flexibility. We use it because it's good software. We strip the telemetry because the privacy claims don't match the behavior.

## License

MIT — same as upstream. See [LICENSE](LICENSE).
