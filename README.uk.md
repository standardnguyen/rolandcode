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

Чиста форка [OpenCode](https://github.com/anomalyco/opencode) з повним прибиранням телеметрії та поведінки зворотного зв'язку з сервером.

OpenCode позиціонує себе як «приватність насамперед» та «відкритий код», але мовчки передає дані до кількох сторонніх сервісів — аналітика (PostHog), телеметрія (Honeycomb), спільний доступ до сесій (opncd.ai), проксі запиту (opencode.ai/zen), пересилання пошукових запитів (mcp.exa.ai), та отримання списків моделей, що розкривають IP (models.dev). Розробники спочатку заперечували існування телеметрії ([#459](https://github.com/sst/opencode/issues/459)), а потім визнали це. Користувачі повідомляють, що вимкнення телеметрії в конфігурації не повністю зупиняє вихідні з'єднання ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode не намагається переконати OpenCode щось змінити. Він просто прибирає їхню телеметрію та видає чисті збірки.

Назва походить від поеми Браунінга «Чайльд Роланд прийшов до Темної Вежі» — Роланд досягає вежі, попри все, що намагається зупинити його.

---

## Що прибрано

| Кінцева точка | Що відправлялося |
|----------|-------------|
| `us.i.posthog.com` | Аналітика використання |
| `api.honeycomb.io` | Телеметрія, IP-адреса, локація |
| `api.opencode.ai` | Вміст сесії, промпти |
| `opncd.ai` | Дані спільного доступу до сесій |
| `opencode.ai/zen/v1` | Промпти, проксі через шлюз OpenCode |
| `mcp.exa.ai` | Пошукові запити |
| `models.dev` | Отримання списків моделей (розкриває IP) |
| `app.opencode.ai` | Універсальний проксі-додаток |

Каталог моделей включається під час збірки з локального сніпшоту — без зв'язку з сервером під час виконання.

## Встановлення

Завантажте бінарний файл зі [сторінки релізів](https://github.com/TODO/rolandcode/releases), або зберіть з джерельного коду:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Завантажте сніпшот каталогу моделей
curl -fsSL -o models-api.json https://models.dev/api.json

# Збірка
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Бінарний файл знаходиться за шляхом `dist/opencode-linux-x64/bin/rolandcode` (або аналогічним для вашої платформи).

## Перевірка

Кожен реліз можна перевірити на чистоту:

```bash
bash scripts/verify-clean.sh
```

Ця команда перевіряє все дерево джерельного коду на наявність відомих доменів телеметрії та пакетів SDK. Якщо залишається будь-який посилання, збірка не вдається. Grep не бреше.

## Як це працює

Rolandcode підтримує невеликий набір патчів поверх вихідного OpenCode. Кожен комміт прибирання видаляє одну загрозу телеметрії:

- `strip-posthog` — Аналітика PostHog
- `strip-honeycomb` — Телеметрія Honeycomb
- `strip-exa` — Пересилання пошуку mcp.exa.ai
- `strip-opencode-api` — Кінцеві точки api.opencode.ai та opncd.ai
- `strip-zen-gateway` — Маршрутизація проксі Zen
- `strip-app-proxy` — Універсальний проксі app.opencode.ai
- `strip-share-sync` — Автоматичний спільний доступ до сесій
- `strip-models-dev` — Отримання списків моделей під час виконання

Невеликі, ізольовані комміти чистимо ребейсуються, коли змінюється вихідний код.

## Тестування

```bash
# Повний набір (виконує тести дозволів у Docker, коли працює як root)
bash scripts/test.sh

# Тільки основний набір
cd packages/opencode && bun test --timeout 30000

# Тільки тести дозволів (має бути не-root, або використати Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Відомі проблеми з тестами

| Тест | Статус | Чому |
|------|--------|-----|
| `session.llm.stream` (2 з 10) | Нестабільний | Стан мок-сервера HTTP витекає між паралельними тестами. Проходить 10/10 при виконанні в ізольованому режимі (`bun test test/session/llm.test.ts`). Помилка ізоляції тестів у вихідному коді — не дефект коду. |
| `tool.write > throws error when OS denies write access` | Не виходить як root | Root обходить `chmod 0o444`. Проходить у Docker як не-root. `scripts/test.sh` обробляє це автоматично. |
| `tui config > continues loading when legacy source cannot be stripped` | Не виходить як root | Та сама проблема root-vs-chmod. Проходить у Docker як не-root. |
| `fsmonitor` (2 тести) | Пропущено | Тільки для Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 тест) | Пропущено | Тільки для Windows. |
| `unicode filenames modification and restore` | Пропущено | Вихідний код явно пропустив — відома помилка, яку вони не виправили. |

## Вихідний репозиторій (Upstream)

Це форка [anomalyco/opencode](https://github.com/anomalyco/opencode) (ліцензія MIT). Весь оригінальний код належить їм. Повна історія коммітів вихідного коду збережена — ви можете бачити саме те, що було змінено і чому.

OpenCode — це потужний агент для написання коду з чудовим TUI, підтримкою LSP та гнучкістю для кількох провайдерів. Ми використовуємо його, тому що це хороше програмне забезпечення. Ми прибираємо телеметрію, тому що заяви про приватність не відповідають поведінці.

## Ліцензія

MIT — така ж, як у вихідному коді. Див. [LICENSE](LICENSE).
