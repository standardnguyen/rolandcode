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

Un fork pulito di [OpenCode](https://github.com/anomalyco/opencode) con tutta la telemetria e il comportamento di comunicazione con il server centrale rimossi.

OpenCode si pubblicizza come "focalizzato sulla privacy" e "open source", ma trasmette silenziosamente dati a vari servizi di terze parti: analisi (PostHog), telemetria (Honeycomb), condivisione sessioni (opncd.ai), proxy per i prompt (opencode.ai/zen), inoltramento delle query di ricerca (mcp.exa.ai) e recupero delle liste dei modelli che泄露 l'IP (models.dev). I maintainers hanno inizialmente negato l'esistenza della telemetria ([#459](https://github.com/sst/opencode/issues/459)), per poi riconoscerla. Gli utenti riportano che disabilitare la telemetria nella configurazione non ferma completamente le connessioni in uscita ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode non cerca di convincere OpenCode a cambiare. Rimuove semplicemente la loro telemetria e distribuisce build pulite.

Il nome deriva da *Childe Roland alla Torre Oscura* di Browning — Roland raggiunge la torre nonostante tutto ciò che cerca di fermarlo.

---

## Cosa è stato rimosso

| Endpoint | Cosa inviava |
|----------|-------------|
| `us.i.posthog.com` | Analisi di utilizzo |
| `api.honeycomb.io` | Telemetria, indirizzo IP, posizione |
| `api.opencode.ai` | Contenuto sessione, prompt |
| `opncd.ai` | Dati di condivisione sessione |
| `opencode.ai/zen/v1` | Prompt inoltrati tramite il gateway di OpenCode |
| `mcp.exa.ai` | Query di ricerca |
| `models.dev` | Recupero lista modelli (泄露 IP) |
| `app.opencode.ai` | Proxy app generico |

Il catalogo dei modelli è incluso al momento della build da uno snapshot locale — nessuna comunicazione con il server centrale in tempo di esecuzione.

## Installazione

Scarica un binario dalla [pagina delle release](https://github.com/TODO/rolandcode/releases), oppure compila dal sorgente:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Scarica uno snapshot del catalogo modelli
curl -fsSL -o models-api.json https://models.dev/api.json

# Compila
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Il binario si trova in `dist/opencode-linux-x64/bin/rolandcode` (o l'equivalente per la tua piattaforma).

## Verifica

Ogni build può essere verificata come pulita:

```bash
bash scripts/verify-clean.sh
```

Questo esegue un grep su tutto l'albero dei sorgenti per tutti i domini di telemetria noti e i pacchetti SDK. Se rimane un riferimento, la build fallisce. Grep non mente.

## Come funziona

Rolandcode mantiene un piccolo insieme di patch sopra l'upstream OpenCode. Ogni commit di rimozione elimina un aspetto della telemetria:

- `strip-posthog` — Analisi PostHog
- `strip-honeycomb` — Telemetria Honeycomb
- `strip-exa` — Inoltramento ricerca mcp.exa.ai
- `strip-opencode-api` — Endpoint api.opencode.ai e opncd.ai
- `strip-zen-gateway` — Instradamento proxy Zen
- `strip-app-proxy` — Proxy generico app.opencode.ai
- `strip-share-sync` — Condivisione automatica sessioni
- `strip-models-dev` — Recupero lista modelli in tempo di esecuzione

Commit piccoli e isolati si rebaseano pulitamente quando l'upstream si aggiorna.

## Test

```bash
# Suite completa (esegue test di permessi in Docker quando si esegue come root)
bash scripts/test.sh

# Solo la suite principale
cd packages/opencode && bun test --timeout 30000

# Solo i test di permessi (deve essere non-root, oppure usare Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Problemi noti nei test

| Test | Stato | Motivo |
|------|--------|-----|
| `session.llm.stream` (2 su 10) | Instabile | Perdita di stato del server HTTP simulato tra test paralleli. Passa 10/10 se eseguito in isolamento (`bun test test/session/llm.test.ts`). Bug di isolamento dei test upstream — non un difetto di codice. |
| `tool.write > genera errore quando il sistema operativo nega l'accesso in scrittura` | Fallisce come root | Root bypassa `chmod 0o444`. Passa in Docker come non-root. `scripts/test.sh` gestisce questo automaticamente. |
| `tui config > continua il caricamento quando la sorgente legacy non può essere rimossa` | Fallisce come root | Stesso problema root-vs-chmod. Passa in Docker come non-root. |
| `fsmonitor` (2 test) | Saltato | Solo per Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Saltato | Solo per Windows. |
| `unicode filenames modification and restore` | Saltato | Esplicitamente saltato dall'upstream — bug noto che non hanno corretto. |

## Progetto Originale

Questo è un fork di [anomalyco/opencode](https://github.com/anomalyco/opencode) (licenza MIT). Tutto il codice originale è loro. L'intera cronologia dei commit upstream è conservata — puoi vedere esattamente cosa è stato modificato e perché.

OpenCode è un agente di coding AI capace con un'ottima interfaccia testuale, supporto LSP e flessibilità multi-provider. Lo usiamo perché è un buon software. Rimuoviamo la telemetria perché le affermazioni sulla privacy non corrispondono al comportamento.

## Licenza

MIT — stessa dell'upstream. Vedi [LICENSE](LICENSE).
