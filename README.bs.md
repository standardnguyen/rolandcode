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

Čist fork projekta [OpenCode](https://github.com/anomalyco/opencode) s uklonjenim ponašanjem telemetrije i "phone-home".

OpenCode se predstavlja kao "privatnost na prvom mjestu" i "otvoreni kod", ali tiho prenosi podatke na više usluga trećih strana — analitika (PostHog), telemetrija (Honeycomb), dijeljenje sesija (opncd.ai), proksiranje promptova (opencode.ai/zen), preusmjeravanje pretraživanja (mcp.exa.ai), i preuzimanje liste modela koje izlažu IP (models.dev). Održavatelji su prvotno negirali postojanje telemetrije ([#459](https://github.com/sst/opencode/issues/459)), a zatim su je priznali. Korisnici izvještavaju da onemogućavanje telemetrije u konfiguraciji ne zaustavlja potpuno izlazne veze ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode se ne trudi uvjeriti OpenCode da se promijeni. Jednostavno uklanja njihovu telemetriju i dostavlja čiste buildove.

Ime je iz Browningovog djela *Childe Roland to the Dark Tower Came* — Roland dolazi do tornja uprkos svemu što pokušava zaustaviti ga.

---

## Šta je uklonjeno

| Endpoint | Šta je slao |
|----------|-------------|
| `us.i.posthog.com` | Analitika korištenja |
| `api.honeycomb.io` | Telemetrija, IP adresa, lokacija |
| `api.opencode.ai` | Sadržaj sesije, promptovi |
| `opncd.ai` | Podaci za dijeljenje sesija |
| `opencode.ai/zen/v1` | Promptovi proksirani kroz OpenCode-ov gateway |
| `mcp.exa.ai` | Upiti za pretraživanje |
| `models.dev` | Preuzimanje liste modela (izlaže IP) |
| `app.opencode.ai` | Proxy za svaku aplikaciju (catch-all) |

Katalog modela se uključuje u build u vrijeme izgradnje iz lokalnog snapshota — nema phone-home tijekom izvršavanja.

## Instalacija

Preuzmi binarnu datoteku sa [stranice izdanja](https://github.com/TODO/rolandcode/releases), ili sastavi iz izvora:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Download a model catalog snapshot
curl -fsSL -o models-api.json https://models.dev/api.json

# Build
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Binarna datoteka je na `dist/opencode-linux-x64/bin/rolandcode` (ili ekvivalent za vašu platformu).

## Verifikacija

Svaki build se može provjeriti kao čist:

```bash
bash scripts/verify-clean.sh
```

Ovo grepa cijelo stablo izvora za sve poznate domene telemetrije i pakete SDK-a. Ako ostane bilo kakva referenca, build neuspjeva. Grep ne laže.

## Kako radi

Rolandcode održava mali skup patcheva preko originalnog OpenCode-a. Svaki commit za uklanjanje uklanja jednu zabrinutost vezanu za telemetriju:

- `strip-posthog` — PostHog analitika
- `strip-honeycomb` — Honeycomb telemetrija
- `strip-exa` — Preusmjeravanje pretraživanja mcp.exa.ai
- `strip-opencode-api` — Endpointi api.opencode.ai i opncd.ai
- `strip-zen-gateway` — Usmeravanje Zen proxyja
- `strip-app-proxy` — Catch-all proxy app.opencode.ai
- `strip-share-sync` — Automatsko dijeljenje sesija
- `strip-models-dev` — Preuzimanje liste modela tijekom izvršavanja

Mali, izolirani commitovi se čisto rebaseuju kada se upstream pomjeri.

## Testiranje

```bash
# Full suite (runs permission tests in Docker when running as root)
bash scripts/test.sh

# Just the main suite
cd packages/opencode && bun test --timeout 30000

# Just the permission tests (must be non-root, or use Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Poznati problemi s testovima

| Test | Status | Zašto |
|------|--------|-------|
| `session.llm.stream` (2 od 10) | Nestabilan | Stanje mock HTTP servera curi između paralelnih testova. Prođe 10/10 kada se pokrene izolirano (`bun test test/session/llm.test.ts`). Bug izolacije testova upstream-a — ne je greška u kodu. |
| `tool.write > throws error when OS denies write access` | Neuspjeva kao root | Root zaobilazi `chmod 0o444`. Prođe u Dockeru kao non-root. `scripts/test.sh` ovo automatski obrađuje. |
| `tui config > continues loading when legacy source cannot be stripped` | Neuspjeva kao root | Ista root-vs-chmod situacija. Prođe u Dockeru kao non-root. |
| `fsmonitor` (2 testa) | Preskočeno | Samo za Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Preskočeno | Samo za Windows. |
| `unicode filenames modification and restore` | Preskočeno | Upstream eksplicitno preskočeno — poznati bug koji nisu popravili. |

## Upstream

Ovo je fork projekta [anomalyco/opencode](https://github.com/anomalyco/opencode) (MIT licenca). Svi originalni kodovi su njihovi. Cijela povijest commitova upstream-a je sačuvana — možete vidjeti tačno šta je promijenjeno i zašto.

OpenCode je sposoban AI agent za kodiranje s odličnim TUI-om, podrškom LSP i fleksibilnošću više provajdera. Koristimo ga jer je dobar softver. Uklanjamo telemetriju jer tvrdnje o privatnosti ne odgovaraju ponašanju.

## Licenca

MIT — isto kao upstream. Pogledajte [LICENSE](LICENSE).
