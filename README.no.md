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

En ren fork av [OpenCode](https://github.com/anomalyco/opencode) med all telemetri og "ring-hjem"-opførsel fjernet.

OpenCode markedsfører seg selv som "privatliv først" og "åpen kildekode", men sender stille data til flere tredjepartstjenester — analyse (PostHog), telemetri (Honeycomb), sesjonsdeling (opncd.ai), proxying av prompter (opencode.ai/zen), videresending av søkeforespørsler (mcp.exa.ai), og henting av modellliste som lekker IP (models.dev). Vedlikeholderne nektet først for at telemetri eksisterte ([#459](https://github.com/sst/opencode/issues/459)), før de innrømmet det. Brukere rapporterer at å deaktivere telemetri i konfigurasjonen ikke helt stopper utgående forbindelser ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode forsøker ikke å overtale OpenCode til å endre seg. Det fjerner bare deres telemetri og leverer rene bygninger.

Navnet er hentet fra Browning's *Childe Roland to the Dark Tower Came* — Roland når tårnet til tross for alt som prøver å stoppe ham.

---

## Hva som er fjernet

| Endepunkt | Hva det sendte |
|----------|-------------|
| `us.i.posthog.com` | Bruksanalyse |
| `api.honeycomb.io` | Telemetri, IP-adresse, lokasjon |
| `api.opencode.ai` | Sesjonsinnhold, prompter |
| `opncd.ai` | Data for sesjonsdeling |
| `opencode.ai/zen/v1` | Prompter som ble proxyet gjennom OpenCode's gatekeeper |
| `mcp.exa.ai` | Søkeforespørsler |
| `models.dev` | Henting av modellliste (lekker IP) |
| `app.opencode.ai` | Proxy for alle app-forespørsler (catch-all) |

Modellkatalogen er inkludert lokalt ved byggingstidspunktet fra et lokalt snapshot — ingen oppkobling hjemmefra ved kjøretid.

## Installasjon

Last ned en binærfil fra [releases-siden](https://github.com/TODO/rolandcode/releases), eller bygg fra kildekode:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Last ned et snapshot av modellkatalogen
curl -fsSL -o models-api.json https://models.dev/api.json

# Bygg
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Binærfilen ligger på `dist/opencode-linux-x64/bin/rolandcode` (eller tilsvarende for din plattform).

## Verifisering

Hver bygging kan verifiseres som ren:

```bash
bash scripts/verify-clean.sh
```

Dette søker (grep) gjennom hele kildetre for alle kjente telemetri-domener og SDK-pakker. Hvis noen referanse gjenstår, mislykkes byggingen. Grep lyver ikke.

## Hvordan det fungerer

Rolandcode vedlikeholder et lite sett med endringslapper ovenpå oppstrøms OpenCode. Hver "strip"-commit fjerner én telemetri-bekymring:

- `strip-posthog` — PostHog-analyse
- `strip-honeycomb` — Honeycomb-telemetri
- `strip-exa` — mcp.exa.ai videresending av søk
- `strip-opencode-api` — api.opencode.ai og opncd.ai endepunkter
- `strip-zen-gateway` — Zen proxy-routing
- `strip-app-proxy` — app.opencode.ai proxy for alle forespørsler
- `strip-share-sync` — Automatisk sesjonsdeling
- `strip-models-dev` — Henting av modellliste ved kjøretid

Små, isolerte commits rebaseres rent når oppstrøms beveger seg.

## Testing

```bash
# Full testserie (kjører tillatelsestester i Docker når kjører som root)
bash scripts/test.sh

# Bare hovedserien
cd packages/opencode && bun test --timeout 30000

# Bare tillatelsestestene (må være ikke-root, eller bruk Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Kjente testproblemer

| Test | Status | Hvorfor |
|------|--------|-----|
| `session.llm.stream` (2 av 10) | Ustabil | Mock HTTP-server tilstand lekker mellom parallelle tester. Passer 10/10 når kjørt isolert (`bun test test/session/llm.test.ts`). Oppstrøms feil med testisolering — ikke en kodeskade. |
| `tool.write > throws error when OS denies write access` | Mislykkes som root | Root omgår `chmod 0o444`. Passer i Docker som ikke-root. `scripts/test.sh` håndterer dette automatisk. |
| `tui config > continues loading when legacy source cannot be stripped` | Mislykkes som root | Samme root-vs-chmod-problemet. Passer i Docker som ikke-root. |
| `fsmonitor` (2 tester) | Hoppet over | Kun for Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Hoppet over | Kun for Windows. |
| `unicode filenames modification and restore` | Hoppet over | Oppstrøms eksplisitt hoppet over — kjent feil de ikke har rettet. |

## Oppstrøms

Dette er en fork av [anomalyco/opencode](https://github.com/anomalyco/opencode) (MIT-lisens). All opprinnelig kode er deres. Hele oppstrøms commit-historikken er bevart — du kan se nøyaktig hva som ble endret og hvorfor.

OpenCode er en kapabel AI-kodingsagent med et flott TUI, LSP-støtte, og fleksibilitet med flere leverandører. Vi bruker den fordi det er god programvare. Vi fjerner telemetri fordi privatlivserklæringene ikke stemmer overens med atferden.

## Lisens

MIT — samme som oppstrøms. Se [LICENSE](LICENSE).
