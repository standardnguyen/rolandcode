# Rolandcode

<p align="center">
  <a href="README.md">English</a> |
  <a href="README.zh.md">简体中文</a> |
  <a href="README.zht.md">繁體中文</a> |
  <a href="README.ko.md">한국어</a> |
  <a href="README.de.md">Deutsch</a> |
  <a href="README.es.md">Español</a> |
  <a href="README.fr.md">Français</a> |
  <a href="README.it.md">Italiano</a> |
  <a href="README.da.md">Dansk</a> |
  <a href="README.ja.md">日本語</a> |
  <a href="README.pl.md">Polski</a> |
  <a href="README.ru.md">Русский</a> |
  <a href="README.bs.md">Bosanski</a> |
  <a href="README.ar.md">العربية</a> |
  <a href="README.no.md">Norsk</a> |
  <a href="README.br.md">Português (Brasil)</a> |
  <a href="README.th.md">ไทย</a> |
  <a href="README.tr.md">Türkçe</a> |
  <a href="README.uk.md">Українська</a> |
  <a href="README.bn.md">বাংলা</a> |
  <a href="README.gr.md">Ελληνικά</a> |
  <a href="README.vi.md">Tiếng Việt</a>
</p>

Eine saubere Fork von [OpenCode](https://github.com/anomalyco/opencode), bei der alle Telemetrie und Rückrufverhalten entfernt wurden.

OpenCode wirbt mit „Datenschutz vorneweg" und „Quellcode offen", übermittelt aber stillschweigend Daten an mehrere Dienste Dritter — Analyse (PostHog), Telemetrie (Honeycomb), Sitzungsteilung (opncd.ai), Prompt-Weiterleitung (opencode.ai/zen), Weiterleitung von Suchanfragen (mcp.exa.ai) und Abrufe der Modellliste, die IP-Adressen preisgeben (models.dev). Die Maintainer bestritten zunächst, dass Telemetrie existierte ([#459](https://github.com/sst/opencode/issues/459)), erkannten es dann an. Benutzer berichten, dass das Deaktivieren der Telemetrie in der Konfiguration ausgehende Verbindungen nicht vollständig stoppt ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode versucht nicht, OpenCode zur Änderung zu bewegen. Es entfernt einfach deren Telemetrie und liefert saubere Builds aus.

Der Name stammt aus Brownings *Childe Roland to the Dark Tower Came* — Roland erreicht den Turm trotz allem, was ihn aufhalten will.

---

## Was entfernt wurde

| Endpunkt | Was gesendet wurde |
|----------|-------------|
| `us.i.posthog.com` | Nutzungsanalyse |
| `api.honeycomb.io` | Telemetrie, IP-Adresse, Standort |
| `api.opencode.ai` | Sitzungsinhalt, Prompts |
| `opncd.ai` | Daten zur Sitzungsteilung |
| `opencode.ai/zen/v1` | Prompts, die durch OpenCodes Gateway weitergeleitet wurden |
| `mcp.exa.ai` | Suchanfragen |
| `models.dev` | Abrufe der Modellliste (preisgibt IP) |
| `app.opencode.ai` | Auffang-App-Proxy |

Der Modellkatalog wird zum Build-Zeitpunkt aus einem lokalen Snapshot eingebunden — kein Rückruf zur Laufzeit.

## Installation

Lade eine Binärdatei von der [Releases-Seite](https://github.com/TODO/rolandcode/releases) herunter, oder baue aus dem Quellcode:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Lade einen Snapshot des Modellkatalogs herunter
curl -fsSL -o models-api.json https://models.dev/api.json

# Build
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Die Binärdatei befindet sich unter `dist/opencode-linux-x64/bin/rolandcode` (oder das Äquivalent für deine Plattform).

## Verifizierung

Jeder Build kann auf Sauberkeit überprüft werden:

```bash
bash scripts/verify-clean.sh
```

Dies durchsucht den gesamten Quellbaum nach allen bekannten Telemetrie-Domains und SDK-Paketen. Wenn eine Referenz verbleibt, schlägt der Build fehl. Grep lügt nicht.

## Wie es funktioniert

Rolandcode pflegt einen kleinen Patch-Satz auf dem Upstream OpenCode. Jeder Strip-Commit entfernt eine Telemetrie-Komponente:

- `strip-posthog` — PostHog-Analyse
- `strip-honeycomb` — Honeycomb-Telemetrie
- `strip-exa` — mcp.exa.ai Suchweiterleitung
- `strip-opencode-api` — api.opencode.ai und opncd.ai Endpunkte
- `strip-zen-gateway` — Zen-Proxy-Routing
- `strip-app-proxy` — app.opencode.ai Auffang-Proxy
- `strip-share-sync` — Automatische Sitzungsteilung
- `strip-models-dev` — Abruf der Modellliste zur Laufzeit

Kleine, isolierte Commits rebasen sauber, wenn sich das Upstream bewegt.

## Tests

```bash
# Vollständige Suite (führt Berechtigungstests in Docker aus, wenn als root ausgeführt)
bash scripts/test.sh

# Nur die Hauptsuite
cd packages/opencode && bun test --timeout 30000

# Nur die Berechtigungstests (muss nicht-root sein, oder Docker verwenden)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Bekannte Testprobleme

| Test | Status | Grund |
|------|--------|-----|
| `session.llm.stream` (2 von 10) | Instabil | Mock-HTTP-Server-Zustand leckt zwischen parallelen Tests. Bestätigt 10/10, wenn isoliert ausgeführt (`bun test test/session/llm.test.ts`). Upstream-Test-Isolierungsfehler — kein Code-Defekt. |
| `tool.write > wirft Fehler, wenn OS Schreibzugriff verweigert` | Scheitert als root | Root umgeht `chmod 0o444`. Bestätigt in Docker als nicht-root. `scripts/test.sh` behandelt dies automatisch. |
| `tui config > lädt weiter, wenn legacy-Quelle nicht entfernt werden kann` | Scheitert als root | Gleiche root-vs-chmod-Problematik. Bestätigt in Docker als nicht-root. |
| `fsmonitor` (2 Tests) | Übersprungen | Nur für Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 Test) | Übersprungen | Nur für Windows. |
| `unicode Dateinamen Änderung und Wiederherstellung` | Übersprungen | Upstream explizit übersprungen — bekannter Fehler, den sie nicht behoben haben. |

## Upstream

Dies ist eine Fork von [anomalyco/opencode](https://github.com/anomalyco/opencode) (MIT-Lizenz). Der gesamte ursprüngliche Code gehört ihnen. Die vollständige Upstream-Commit-Historie wird erhalten — du kannst genau sehen, was geändert wurde und warum.

OpenCode ist ein fähiger AI-Coding-Agent mit einer großartigen TUI, LSP-Unterstützung und Multi-Provider-Flexibilität. Wir verwenden ihn, weil es gute Software ist. Wir entfernen die Telemetrie, weil die Datenschutzbehauptungen nicht mit dem Verhalten übereinstimmen.

## Lizenz

MIT — wie beim Upstream. Siehe [LICENSE](LICENSE).
