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

Tüm telemetri ve uzaktan bağlantı ("phone-home") davranışları kaldırılmış, [OpenCode](https://github.com/anomalyco/opencode) projesinin temiz bir çatalı (fork) (fork).

OpenCode kendini "önce gizlilik" ve "açık kaynak" olarak pazarlıyor, ancak sessizce çok sayıda üçüncü taraf servise veri gönderiyor — analitik (PostHog), telemetri (Honeycomb), oturum paylaşımı (opncd.ai), istek (prompt) yönlendirme (opencode.ai/zen), arama sorgusu yönlendirme (mcp.exa.ai) ve IP sızdırma riski taşıyan model listesi çekimleri (models.dev). Bakım görevlileri ilk olarak telemetrinin varlığını inkar ettiler ([#459](https://github.com/sst/opencode/issues/459)), ardından kabul ettiler. Kullanıcılar, yapılandırma dosyasında telemetriyi devre dışı bırakmanın giden bağlantıları tamamen durdurmadığını raporluyor ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode, OpenCode'yi değiştirmeye ikna etmeye çalışmaz. Sadece onların telemetrilerini kaldırır ve temiz derlemeler (builds) sunar.

İsim, Browning'in *Childe Roland to the Dark Tower Came* eserinden geliyor — Roland, onu durdurmaya çalışan her şeye rağmen kuleye ulaşır.

## Ne Kaldırıldı

| Endpoint | Ne Gönderdi |
|----------|-------------|
| `us.i.posthog.com` | Kullanım analitiği |
| `api.honeycomb.io` | Telemetri, IP adresi, konum |
| `api.opencode.ai` | Oturum içeriği, istekler (prompts) |
| `opncd.ai` | Oturum paylaşımı verisi |
| `opencode.ai/zen/v1` | OpenCode'nin kapısı üzerinden yönlendirilen istekler |
| `mcp.exa.ai` | Arama sorguları |
| `models.dev` | Model listesi çekimleri (IP sızdırır) |
| `app.opencode.ai` | Kapsamlı uygulama (catch-all) proxy |

Model kataloğu, derleme zamanında yerel bir anlık görüntüden temin edilir — çalışma zamanında uzaktan bağlantı (phone-home) yok.

## Kurulum

[Sürümler sayfasından](https://github.com/TODO/rolandcode/releases) bir yürütülebilir dosya (binary) indirin veya kaynaktan derleyin:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Bir model kataloğu anlık görüntüsü indirin
curl -fsSL -o models-api.json https://models.dev/api.json

# Derle
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Yürütülebilir dosya `dist/opencode-linux-x64/bin/rolandcode` konumunda (veya platformunuz için eşdeğer) bulunur.

## Doğrulama

Her derleme temiz olarak doğrulanabilir:

```bash
bash scripts/verify-clean.sh
```

Bu komut, tüm kaynak ağacında bilinen telemetri alan adları ve SDK paketleri için grep yapar. Herhangi bir referans kalırsa derleme başarısız olur. Grep yalan söylemez.

## Nasıl Çalışır

Rolandcode, yukarı akış (upstream) OpenCode üzerinde küçük bir yama (patch) seti tutar. Her "strip" commit'i bir telemetri endişesini kaldırır:

- `strip-posthog` — PostHog analitikleri
- `strip-honeycomb` — Honeycomb telemetrisi
- `strip-exa` — mcp.exa.ai arama yönlendirme
- `strip-opencode-api` — api.opencode.ai ve opncd.ai uç noktaları
- `strip-zen-gateway` — Zen proxy yönlendirme
- `strip-app-proxy` — app.opencode.ai kapsamlı proxy
- `strip-share-sync` — Otomatik oturum paylaşımı
- `strip-models-dev` — Çalışma zamanında model listesi çekimi

Küçük, izole commit'ler, yukarı akış hareket ettiğinde temiz bir şekilde rebase olur.

## Test Etme

```bash
# Tam dizi (kök kullanıcı olarak çalışıldığında Docker'da izin testlerini çalıştırır)
bash scripts/test.sh

# Sadece ana dizi
cd packages/opencode && bun test --timeout 30000

# Sadece izin testleri (kök olmamalı veya Docker kullanılmalı)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Bilinen Test Sorunları

| Test | Durum | Neden |
|------|--------|-----|
| `session.llm.stream` (10'dan 2'si) | Kararsız (Flaky) | Mock HTTP sunucusu durumu paralel testler arasında sızdırıyor. İzole çalıştırıldığında 10/10 geçer (`bun test test/session/llm.test.ts`). Yukarı akış test izolasyon hatası — kod hatası değil. |
| `tool.write > işletim sistemi yazma erişimini reddettiğinde hata fırlatır` | Kök kullanıcı olarak başarısız | Kök kullanıcı `chmod 0o444`'ü atlatır. Docker'da kök olmayan kullanıcı olarak geçer. `scripts/test.sh` bunu otomatik olarak yönetir. |
| `tui config > eski kaynak kaldırılamadığında yükleme devam eder` | Kök kullanıcı olarak başarısız | Aynı kök-vs-chmod sorunu. Docker'da kök olmayan kullanıcı olarak geçer. |
| `fsmonitor` (2 test) | Atlandı | Sadece Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Atlandı | Sadece Windows. |
| `unicode dosya adları değişiklik ve geri yükleme` | Atlandı | Yukarı akış açıkça atlandı — düzeltmedikleri bilinen hata. |

## Kaynak Proje (Upstream)

Bu, [anomalyco/opencode](https://github.com/anomalyco/opencode) projesinin bir çatalıdır (MIT lisansı). Tüm orijinal kod onların. Tam yukarı akış commit geçmişi korunur — ne değişti ve neden değişti tam olarak görebilirsiniz.

OpenCode, harika bir TUI, LSP desteği ve çoklu sağlayıcı esnekliği ile yetenekli bir AI kodlama ajanıdır. İyi bir yazılım olduğu için kullanıyoruz. Telemetriyi kaldırmamızın nedeni ise gizlilik iddialarının davranışla eşleşmemesidir.

## Lisans

MIT — kaynak projeyle aynı. [LICENSE](LICENSE) dosyasına bakın.
