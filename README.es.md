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

Un fork limpio de [OpenCode](https://github.com/anomalyco/opencode) con todo el comportamiento de telemetría y "phone-home" eliminado.

OpenCode se promociona como "privacidad primero" y "código abierto", pero transmite datos silenciosamente a múltiples servicios de terceros: analítica (PostHog), telemetría (Honeycomb), compartición de sesiones (opncd.ai), proxificación de prompts (opencode.ai/zen), reenvío de consultas de búsqueda (mcp.exa.ai) y obtención de listas de modelos que filtran la IP (models.dev). Los mantenedores inicialmente negaron que existiera telemetría ([#459](https://github.com/sst/opencode/issues/459)), luego lo reconocieron. Los usuarios reportan que deshabilitar la telemetría en la configuración no detiene completamente las conexiones salientes ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode no intenta convencer a OpenCode para que cambie. Simplemente elimina su telemetría y entrega construcciones limpias.

El nombre proviene de *Childe Roland llegó a la Torre Oscura* de Browning: Roland alcanza la torre a pesar de todo lo que intenta detenerlo.

---

## Qué se eliminó

| Endpoint | Qué envió |
|----------|-----------|
| `us.i.posthog.com` | Analítica de uso |
| `api.honeycomb.io` | Telemetría, dirección IP, ubicación |
| `api.opencode.ai` | Contenido de sesión, prompts |
| `opncd.ai` | Datos de compartición de sesión |
| `opencode.ai/zen/v1` | Prompts proxificados a través de la pasarela de OpenCode |
| `mcp.exa.ai` | Consultas de búsqueda |
| `models.dev` | Obtención de listas de modelos (filtra IP) |
| `app.opencode.ai` | Proxy de aplicación general (catch-all) |

El catálogo de modelos se incluye en el momento de la construcción desde una instantánea local; no hay comunicación con el servidor en tiempo de ejecución.

## Instalación

Descarga un binario de la [página de lanzamientos](https://github.com/TODO/rolandcode/releases), o construye desde el código fuente:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Descargar una instantánea del catálogo de modelos
curl -fsSL -o models-api.json https://models.dev/api.json

# Construir
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

El binario está en `dist/opencode-linux-x64/bin/rolandcode` (o el equivalente para tu plataforma).

## Verificación

Cada construcción puede verificarse como limpia:

```bash
bash scripts/verify-clean.sh
```

Esto busca en todo el árbol de código fuente todos los dominios de telemetría conocidos y paquetes de SDK. Si queda alguna referencia, la construcción falla. Grep no miente.

## Cómo funciona

Rolandcode mantiene un pequeño conjunto de parches sobre el upstream de OpenCode. Cada commit de eliminación quita una preocupación de telemetría:

- `strip-posthog` — Analítica de PostHog
- `strip-honeycomb` — Telemetría de Honeycomb
- `strip-exa` — Reenvío de búsqueda mcp.exa.ai
- `strip-opencode-api` — Endpoints de api.opencode.ai y opncd.ai
- `strip-zen-gateway` — Enrutamiento de proxy Zen
- `strip-app-proxy` — Proxy general de app.opencode.ai
- `strip-share-sync` — Compartición automática de sesiones
- `strip-models-dev` — Obtención de listas de modelos en tiempo de ejecución

Commits pequeños e aislados se reintegran limpiamente cuando el upstream avanza.

## Pruebas

```bash
# Suite completa (ejecuta pruebas de permisos en Docker cuando se ejecuta como root)
bash scripts/test.sh

# Solo la suite principal
cd packages/opencode && bun test --timeout 30000

# Solo las pruebas de permisos (debe ser no-root, o usar Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Problemas conocidos de pruebas

| Prueba | Estado | Razón |
|--------|--------|-------|
| `session.llm.stream` (2 de 10) | Inestable | El estado del servidor HTTP simulado se filtra entre pruebas paralelas. Pasa 10/10 cuando se ejecuta en aislamiento (`bun test test/session/llm.test.ts`). Bug de aislamiento de pruebas del upstream — no un defecto de código. |
| `tool.write > lanza error cuando el OS deniega acceso de escritura` | Falla como root | Root evade `chmod 0o444`. Pasa en Docker como no-root. `scripts/test.sh` maneja esto automáticamente. |
| `tui config > continúa cargando cuando la fuente legada no puede eliminarse` | Falla como root | Mismo problema root-vs-chmod. Pasa en Docker como no-root. |
| `fsmonitor` (2 pruebas) | Omitido | Solo Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 prueba) | Omitido | Solo Windows. |
| `modificación y restauración de nombres de archivos unicode` | Omitido | El upstream lo omitió explícitamente — bug conocido que no han arreglado. |

## Origen

Este es un fork de [anomalyco/opencode](https://github.com/anomalyco/opencode) (licencia MIT). Todo el código original es de ellos. Se preserva el historial completo de commits del upstream; puedes ver exactamente qué se cambió y por qué.

OpenCode es un agente de codificación AI capaz con una excelente TUI, soporte LSP y flexibilidad multi-proveedor. Lo usamos porque es buen software. Eliminamos la telemetría porque las afirmaciones de privacidad no coinciden con el comportamiento.

## Licencia

MIT — igual que el upstream. Ver [LICENSE](LICENSE).
