# Autonomous Task: OpenCode Telemetry Audit

## Objective

Audit the OpenCode codebase and create a clean version with all telemetry, analytics, and phone-home code removed. Produce isolated strip commits (one per telemetry concern) and verify the result.

## Setup

```bash
cd ~/opencode-clean
git fetch origin
git checkout scratch/audit
```

## Background

OpenCode (https://github.com/anomalyco/opencode) markets itself as privacy-first but silently transmits data to multiple third-party services. Your job is to find every telemetry touchpoint in the source code and remove it.

### Known telemetry endpoints

These are the domains identified from prior research. Your audit may find more.

| Domain | Purpose |
|--------|---------|
| `us.i.posthog.com` | PostHog usage analytics |
| `api.honeycomb.io` | Honeycomb telemetry/tracing |
| `api.opencode.ai` | OpenCode session/prompt data |
| `opncd.ai` | OpenCode session sharing |
| `opencode.ai/zen/v1` | Zen gateway (proxies all LLM prompts through OpenCode's servers) |
| `mcp.exa.ai` | Exa search query forwarding |
| `models.dev` | Remote model list fetching (leaks IP) |

### Known SDK/package names to search for

- `posthog-js`, `posthog-node`, `posthog`
- `@honeycombio/opentelemetry-node`, `@honeycombio`
- `@opentelemetry` (if used for honeycomb)
- Any analytics or telemetry SDK

## Tasks

Work through these in order.

### Task 1: Codebase reconnaissance

Map the project structure. Answer these questions in your session log:
- What language(s) is the source in? (TypeScript, Go, both?)
- What's the build system? (Bun, npm, esbuild, etc.)
- Where is the main entry point?
- What are the top-level directories and what do they contain?
- How are dependencies managed? (package.json, go.mod, etc.)

### Task 2: Full telemetry grep

Search the entire codebase for every telemetry touchpoint. For each hit, record:
- File path and line number
- The domain/SDK being referenced
- What the code does (sends analytics, fetches config, proxies requests, etc.)
- Whether it's a direct call or imported from a shared module

Search for at minimum:
```
posthog
honeycomb
opentelemetry
api.opencode.ai
opncd.ai
opencode.ai/zen
mcp.exa.ai
models.dev
telemetry
analytics
tracking
phone.home
```

Also search for:
- Any `fetch()`, `axios`, `got`, `http.request`, `net/http` calls to hardcoded URLs
- Environment variables that look like API keys or telemetry config
- Config files that reference external services

Record ALL findings in the session log, even if you're not sure whether something is telemetry.

### Task 3: Map the call graph

For each telemetry touchpoint found in Task 2, trace the call chain:
- What function calls it?
- What calls that function?
- Is it called on startup, on every prompt, on exit, periodically?
- Can it be removed without breaking non-telemetry functionality?

Document any cases where telemetry is deeply entangled with core functionality (these will need careful surgery rather than simple deletion).

### Task 4: Create strip commits

Create one commit per telemetry concern. Each commit should:
- Remove the telemetry code
- Remove any imports/dependencies that are now unused
- NOT break the build (the project should still compile after each commit)
- Have a clear commit message explaining what was removed and why

Target commits (adjust based on what you actually find):

| Commit message prefix | What to remove |
|----------------------|----------------|
| `strip-posthog:` | All PostHog analytics code and SDK |
| `strip-honeycomb:` | All Honeycomb telemetry/tracing code and SDK |
| `strip-zen-gateway:` | Zen proxy routing — replace with direct provider API calls |
| `strip-opencode-api:` | `api.opencode.ai` and `opncd.ai` session/sharing endpoints |
| `strip-exa:` | `mcp.exa.ai` search query forwarding |
| `strip-models-dev:` | Remote model list fetching — vendor the list locally |

If you find additional telemetry not covered above, create additional strip commits.

**Important:** Small, isolated commits. Do NOT create one giant commit that strips everything. Each commit should be independently revertable and should rebase cleanly when upstream changes.

### Task 5: Run verification

Run `bash scripts/verify-clean.sh` after all strip commits are applied. It must pass (exit 0).

If it fails, fix the remaining telemetry references and re-run.

### Task 6: Build test

Try to build the project:
```bash
# Check package.json for the build command, likely one of:
bun run build
npm run build
```

If the build fails due to your changes, fix the issue. The goal is a clean build with zero telemetry.

If the build requires dependencies or tooling not available on this machine, document what's needed in the session log and skip to Task 7. A failed build due to missing tooling is acceptable; a failed build due to broken code is not.

### Task 7: Undiscovered telemetry check

After all strip commits, do one final paranoid pass:
- Grep for any remaining hardcoded URLs (http:// or https://) — are any suspicious?
- Grep for any remaining `fetch()` or HTTP client calls — where do they go?
- Check if there are any WebSocket connections to external services
- Look for any obfuscated strings (base64-encoded URLs, string concatenation to build URLs)

Document findings in the session log even if you determine they're benign.

## Rules

- Work on the `scratch/audit` branch. Do NOT touch `main`.
- You may modify any source file in the repo.
- Do NOT delete test files or test infrastructure — tests should still pass if the build works.
- If you're unsure whether something is telemetry, err on the side of documenting it. The auditing Claude will review.
- Do NOT add new features or refactor code beyond what's needed for telemetry removal.
- Do NOT install any packages that make network calls during the audit. You're analyzing source code, not running the app.

## Session Log

**Maintain this section as you work.** This is the primary artifact for the auditing Claude.

Record:
- What you searched for and what you found
- Each telemetry touchpoint with file, line, and description
- What you changed and why
- Build/verification results
- Any judgment calls you made
- Anything suspicious that needs human review

---

### Session Log Entries

<!-- Autonomous Claude: append your entries below this line -->
