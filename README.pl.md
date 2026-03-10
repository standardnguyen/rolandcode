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

Czysty fork projektu [OpenCode](https://github.com/anomalyco/opencode), z którego usunięto całą telemetrię i zachowania typu "kontakt z serwerem".

OpenCode reklamuje się jako "priorytet prywatności" i "otwarte źródło", ale w cichu przesyła dane do wielu usług stron trzecich — analityka (PostHog), telemetria (Honeycomb), współdzielenie sesji (opncd.ai), proxy promptów (opencode.ai/zen), przekazywanie zapytań wyszukiwania (mcp.exa.ai) oraz pobieranie list modeli wyciekających adres IP (models.dev). Utrzymujący projekt początkowo zaprzeczali istnieniu telemetrii ([#459](https://github.com/sst/opencode/issues/459)), a następnie ją potwierdzili. Użytkownicy raportują, że wyłączenie telemetrii w konfiguracji nie zatrzymuje w pełni połączeń wychodzących ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode nie próbuje przekonać OpenCode do zmian. Po prostu usuwa ich telemetrię i dostarcza czyste budowy.

Nazwa pochodzi z utworu Browninga *Childe Roland przyszedł do Ciemnej Wieży* — Roland dociera do wieży pomimo wszystkiego, co próbuje go powstrzymać.

---

## Co zostało usunięte

| Endpoint | Przesyłane dane |
|----------|-----------------|
| `us.i.posthog.com` | Analiza użytkowania |
| `api.honeycomb.io` | Telemetria, adres IP, lokalizacja |
| `api.opencode.ai` | Treść sesji, prompty |
| `opncd.ai` | Dane współdzielenia sesji |
| `opencode.ai/zen/v1` | Prompty przekazywane przez bramę OpenCode |
| `mcp.exa.ai` | Zapytania wyszukiwania |
| `models.dev` | Pobieranie listy modeli (wyciek IP) |
| `app.opencode.ai` | Proxy typu "wszystko w jednym" |

Katalog modeli jest włączany do budowy w czasie kompilacji z lokalnej migawki — brak kontaktu z serwerem w czasie działania.

## Instalacja

Pobierz binarkę ze [strony wydań](https://github.com/TODO/rolandcode/releases), lub zbuduj ze źródła:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Pobierz migawkę katalogu modeli
curl -fsSL -o models-api.json https://models.dev/api.json

# Budowa
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Binarka znajduje się w `dist/opencode-linux-x64/bin/rolandcode` (lub odpowiedniku dla Twojej platformy).

## Weryfikacja

Każdą budowę można zweryfikować jako czystą:

```bash
bash scripts/verify-clean.sh
```

To przeszukuje (grep) całe drzewo źródłowe pod kątem wszystkich znanych domen telemetrycznych i pakietów SDK. Jeśli pozostanie jakiekolwiek odniesienie, budowa się nie powiodzie. Grep nie kłamie.

## Jak to działa

Rolandcode utrzymuje mały zestaw łatek na wierzchu projektu źródłowego OpenCode. Każdy commit typu "strip" usuwa jedno zagadnienie telemetryczne:

- `strip-posthog` — Analiza PostHog
- `strip-honeycomb` — Telemetria Honeycomb
- `strip-exa` — Przekazywanie wyszukiwania mcp.exa.ai
- `strip-opencode-api` — Endpointy api.opencode.ai i opncd.ai
- `strip-zen-gateway` — Routing proxy Zen
- `strip-app-proxy` — Proxy typu "wszystko w jednym" app.opencode.ai
- `strip-share-sync` — Automatyczne współdzielenie sesji
- `strip-models-dev` — Pobieranie listy modeli w czasie działania

Małe, izolowane commity czysto się rebaseują, gdy projekt źródłowy się przesuwa.

## Testowanie

```bash
# Pełny zestaw (uruchamia testy uprawnień w Dockerze, gdy działa jako root)
bash scripts/test.sh

# Tylko główny zestaw
cd packages/opencode && bun test --timeout 30000

# Tylko testy uprawnień (musi być nie-root, lub użyj Dockera)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Znane problemy z testami

| Test | Status | Dlaczego |
|------|--------|-----|
| `session.llm.stream` (2 z 10) | Niestabilny | Stan serwera HTTP mock wycieka między równoległymi testami. Przechodzi 10/10 przy uruchomieniu w izolacji (`bun test test/session/llm.test.ts`). Błąd izolacji testów w projekcie źródłowym — nie wada kodu. |
| `tool.write > zgłasza błąd, gdy system operacyjny odmawia dostępu do zapisu` | Nieudany jako root | Root omija `chmod 0o444`. Przechodzi w Dockerze jako nie-root. `scripts/test.sh` obsługuje to automatycznie. |
| `tui config > kontynuuje ładowanie, gdy źródło legacy nie może zostać usunięte` | Nieudany jako root | Ten sam problem root-vs-chmod. Przechodzi w Dockerze jako nie-root. |
| `fsmonitor` (2 testy) | Pominięty | Tylko Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Pominięty | Tylko Windows. |
| `modyfikacja i przywracanie nazw plików unicode` | Pominięty | Projekt źródłowy jawnie pominął — znany błąd, którego nie naprawili. |

## Projekt źródłowy (Upstream)

To jest fork projektu [anomalyco/opencode](https://github.com/anomalyco/opencode) (licencja MIT). Cały oryginalny kod należy do nich. Pełna historia commitów projektu źródłowego jest zachowana — możesz zobaczyć dokładnie, co zostało zmienione i dlaczego.

OpenCode to zdolny agent AI do kodowania z świetnym interfejsem TUI, obsługą LSP i elastycznością wielodostawczą. Używamy go, ponieważ to dobry soft. Usuwamy telemetrię, ponieważ twierdzenia o prywatności nie odpowiadają zachowaniu.

## Licencja

MIT — taka sama jak w projekcie źródłowym. Zobacz [LICENSE](LICENSE).
