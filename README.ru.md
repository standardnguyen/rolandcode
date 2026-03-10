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

Чистая версия (форк) [OpenCode](https://github.com/anomalyco/opencode) с удаленной телеметрией и функциями связи с внешними серверами.

OpenCode позиционирует себя как «с приватностью на первом месте» и «с открытым исходным кодом», но тайно передает данные в несколько сторонних сервисов — аналитику (PostHog), телеметрию (Honeycomb), обмен сессиями (opncd.ai), проксирование запросов (opencode.ai/zen), пересылку поисковых запросов (mcp.exa.ai) и получение списка моделей, раскрывающее IP-адрес (models.dev). Разработчики изначально отрицали наличие телеметрии ([#459](https://github.com/sst/opencode/issues/459)), а затем признали её. Пользователи сообщают, что отключение телеметрии в конфигурации не полностью останавливает исходящие соединения ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode не пытается убедить OpenCode что-то изменить. Он просто удаляет их телеметрию и выпускает чистые сборки.

Название взято из поэмы Бронинга *Чильд Роланд у тёмной башни* (Childe Roland to the Dark Tower Came) — Роланд достигает башни, несмотря на всё, что пытается его остановить.

---

## Что удалено

| Конечная точка | Что отправлялось |
|----------|-------------|
| `us.i.posthog.com` | Аналитика использования |
| `api.honeycomb.io` | Телеметрия, IP-адрес, геолокация |
| `api.opencode.ai` | Содержимое сессии, промпты |
| `opncd.ai` | Данные для обмена сессиями |
| `opencode.ai/zen/v1` | Пропмпты, проксируемые через шлюз OpenCode |
| `mcp.exa.ai` | Поисковые запросы |
| `models.dev` | Запросы списка моделей (раскрывает IP) |
| `app.opencode.ai` | Универсальный прокси приложения |

Каталог моделей встраивается во время сборки из локального снимка — никаких обращений к серверу во время работы.

## Установка

Скачайте исполняемый файл со [страницы релизов](https://github.com/TODO/rolandcode/releases) или соберите из исходного кода:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Скачайте снимок каталога моделей
curl -fsSL -o models-api.json https://models.dev/api.json

# Сборка
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Исполняемый файл находится в `dist/opencode-linux-x64/bin/rolandcode` (или аналогичный путь для вашей платформы).

## Проверка

Каждую сборку можно проверить на чистоту:

```bash
bash scripts/verify-clean.sh
```

Это скрипт ищет по всем исходникам все известные домены телеметрии и пакеты SDK. Если найдется какая-либо ссылка, сборка завершится ошибкой. Grep не врет.

## Как это работает

Rolandcode поддерживает небольшой набор патчей поверх исходного OpenCode. Каждый коммит по удалению устраняет одну проблему телеметрии:

- `strip-posthog` — аналитика PostHog
- `strip-honeycomb` — телеметрия Honeycomb
- `strip-exa` — пересылка поиска через mcp.exa.ai
- `strip-opencode-api` — конечные точки api.opencode.ai и opncd.ai
- `strip-zen-gateway` — маршрутизация через прокси Zen
- `strip-app-proxy` — универсальный прокси app.opencode.ai
- `strip-share-sync` — автоматический обмен сессиями
- `strip-models-dev` — получение списка моделей во время работы

Маленькие, изолированные коммиты чистятся при ребейзе, когда исходный проект обновляется.

## Тестирование

```bash
# Полный набор (запускает тесты прав в Docker при запуске от root)
bash scripts/test.sh

# Только основной набор
cd packages/opencode && bun test --timeout 30000

# Только тесты прав (должны запускаться не от root, или через Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Известные проблемы с тестами

| Тест | Статус | Причина |
|------|--------|-----|
| `session.llm.stream` (2 из 10) | Нестабильный | Состояние мок-сервера HTTP утекает между параллельными тестами. Проходит 10/10 при запуске в изоляции (`bun test test/session/llm.test.ts`). Ошибка изоляции тестов в исходном проекте — не дефект кода. |
| `tool.write > throws error when OS denies write access` | Не проходит от root | Root обходит `chmod 0o444`. Проходит в Docker не от root. `scripts/test.sh` обрабатывает это автоматически. |
| `tui config > continues loading when legacy source cannot be stripped` | Не проходит от root | Та же проблема с root и chmod. Проходит в Docker не от root. |
| `fsmonitor` (2 теста) | Пропущены | Только для Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 тест) | Пропущен | Только для Windows. |
| `unicode filenames modification and restore` | Пропущен | Явно пропущено в исходном проекте — известный баг, который они не исправили. |

## Исходный проект

Это форк [anomalyco/opencode](https://github.com/anomalyco/opencode) (лицензия MIT). Весь оригинальный код принадлежит им. Полная история коммитов исходного проекта сохранена — вы можете увидеть, что именно было изменено и почему.

OpenCode — это capable AI-агент для написания кода с отличным TUI, поддержкой LSP и гибкостью выбора провайдеров. Мы используем его, потому что это хороший софт. Мы удаляем телеметрию, потому что заявления о приватности не соответствуют поведению.

## Лицензия

MIT — как и в исходном проекте. См. [LICENSE](LICENSE).
