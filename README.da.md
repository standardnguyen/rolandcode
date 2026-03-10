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

Een schone fork van [OpenCode](https://github.com/anomalyco/opencode) waarbij alle telemetrie en 'phone-home'-gedrag is verwijderd.

OpenCode presenteert zich als "privacy-voorop" en "open source", maar verzendt gegevens stilzwijgend naar meerdere externe diensten — analyse (PostHog), telemetrie (Honeycomb), sessiedeling (opncd.ai), prompt-proxying (opencode.ai/zen), doorsturen van zoekopdrachten (mcp.exa.ai), en ophalen van modellijsten die IP-adressen lekken (models.dev). De onderhouders ontkenden aanvankelijk dat telemetrie bestond ([#459](https://github.com/sst/opencode/issues/459)), maar erkenden het later. Gebruikers melden dat het uitschakelen van telemetrie in de configuratie uitgaande verbindingen niet volledig stopt ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode probeert OpenCode niet te overtuigen om te veranderen. Het verwijdert gewoon hun telemetrie en levert schone builds.

De naam is afkomstig uit Browning's *Childe Roland to the Dark Tower Came* — Roland bereikt de toren ondanks alles wat hem probeert tegen te houden.

---

## Wat is verwijderd

| Endpoint | Wat het verzond |
|----------|-------------|
| `us.i.posthog.com` | Gebruiksanalyse |
| `api.honeycomb.io` | Telemetrie, IP-adres, locatie |
| `api.opencode.ai` | Sessie-inhoud, prompts |
| `opncd.ai` | Sessiedelingsgegevens |
| `opencode.ai/zen/v1` | Prompts die via OpenCode's gateway worden geproxyd |
| `mcp.exa.ai` | Zoekopdrachten |
| `models.dev` | Ophalen van modellijsten (lekken IP) |
| `app.opencode.ai` | Alles-omvattende app-proxy |

De modelcatalogus is tijdens de build ingebouwd vanuit een lokale snapshot — geen 'phone-home' tijdens runtime.

## Installatie

Download een binary van de [releases-pagina](https://github.com/TODO/rolandcode/releases), of bouw vanuit broncode:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Download een snapshot van de modelcatalogus
curl -fsSL -o models-api.json https://models.dev/api.json

# Bouwen
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

De binary staat in `dist/opencode-linux-x64/bin/rolandcode` (of het equivalent voor uw platform).

## Verificatie

Elke build kan als schoon worden geverifieerd:

```bash
bash scripts/verify-clean.sh
```

Dit 'grept' de gehele broncodeboom op alle bekende telemetrie-domeinen en SDK-pakketten. Als er referenties overblijven, faalt de build. Grep liegt niet.

## Hoe het werkt

Rolandcode onderhoudt een kleine patchset bovenop upstream OpenCode. Elke 'strip'-commit verwijdert één telemetrie-zaak:

- `strip-posthog` — PostHog-analyse
- `strip-honeycomb` — Honeycomb-telemetrie
- `strip-exa` — mcp.exa.ai zoekopdracht-doorsturing
- `strip-opencode-api` — api.opencode.ai en opncd.ai endpoints
- `strip-zen-gateway` — Zen proxy routing
- `strip-app-proxy` — app.opencode.ai alles-omvattende proxy
- `strip-share-sync` — Automatische sessiedeling
- `strip-models-dev` — Runtime ophalen van modellijst

Kleine, geïsoleerde commits rebaseen zonder problemen wanneer upstream wordt bijgewerkt.

## Testen

```bash
# Volledige suite (draait machtigingstests in Docker bij uitvoering als root)
bash scripts/test.sh

# Alleen de hoofd suite
cd packages/opencode && bun test --timeout 30000

# Alleen de machtigingstests (moet niet-root zijn, of gebruik Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Bekende testproblemen

| Test | Status | Reden |
|------|--------|-----|
| `session.llm.stream` (2 van 10) | Onstabiel | De status van de mock HTTP-server lekt tussen parallelle tests. Lukt 10/10 wanneer geïsoleerd gedraaid (`bun test test/session/llm.test.ts`). Upstream test-isolatie bug — geen code-defect. |
| `tool.write > throws error when OS denies write access` | Faalt als root | Root omzeilt `chmod 0o444`. Lukt in Docker als niet-root. `scripts/test.sh` behandelt dit automatisch. |
| `tui config > continues loading when legacy source cannot be stripped` | Faalt als root | Zelfde root-vs-chmod probleem. Lukt in Docker als niet-root. |
| `fsmonitor` (2 tests) | Overslagen | Alleen voor Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Overslagen | Alleen voor Windows. |
| `unicode filenames modification and restore` | Overslagen | Upstream expliciet overgeslagen — bekende bug die ze niet hebben opgelost. |

## Upstream

Dit is een fork van [anomalyco/opencode](https://github.com/anomalyco/opencode) (MIT-licentie). Alle originele code is van hen. De volledige upstream commit-historie is behouden — je kunt precies zien wat er is veranderd en waarom.

OpenCode is een capabele AI-codeeragent met een geweldige TUI, LSP-ondersteuning en flexibiliteit voor meerdere providers. We gebruiken het omdat het goede software is. We verwijderen de telemetrie omdat de privacy-claims niet overeenkomen met het gedrag.

## Licentie

MIT — hetzelfde als upstream. Zie [LICENSE](LICENSE).
