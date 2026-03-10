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

Um fork limpo do [OpenCode](https://github.com/anomalyco/opencode) com toda a telemetria e comportamento de envio de dados externo ("phone-home") removidos.

O OpenCode se comercializa como "privacidade em primeiro lugar" e "código aberto", mas transmite silenciosamente dados para vários serviços de terceiros — análise de uso (PostHog), telemetria (Honeycomb), compartilhamento de sessão (opncd.ai), proxy de prompts (opencode.ai/zen), encaminhamento de consultas de busca (mcp.exa.ai) e requisições de lista de modelos que vazam o IP (models.dev). Os mantenedores inicialmente negaram a existência de telemetria ([#459](https://github.com/sst/opencode/issues/459)), depois admitiram. Usuários relatam que desabilitar a telemetria na configuração não para completamente as conexões de saída ([#5554](https://github.com/sst/opencode/issues/5554)).

O Rolandcode não tenta convencer o OpenCode a mudar. Ele apenas remove a telemetria deles e distribui builds limpos.

O nome vem do poema de Browning *Childe Roland to the Dark Tower Came* (Childe Roland foi à Torre Negra) — Roland chega à torre apesar de tudo tentar impedi-lo.

---

## O que foi removido

| Endpoint | O que enviava |
|----------|-------------|
| `us.i.posthog.com` | Análise de uso |
| `api.honeycomb.io` | Telemetria, endereço IP, localização |
| `api.opencode.ai` | Conteúdo da sessão, prompts |
| `opncd.ai` | Dados de compartilhamento de sessão |
| `opencode.ai/zen/v1` | Prompts roteados pelo gateway do OpenCode |
| `mcp.exa.ai` | Consultas de busca |
| `models.dev` | Requisições de lista de modelos (vaza IP) |
| `app.opencode.ai` | Proxy de captura geral do aplicativo |

O catálogo de modelos é incorporado no momento da build a partir de um instantâneo local — sem envio de dados externo em tempo de execução.

## Instalação

Baixe um binário da [página de lançamentos](https://github.com/TODO/rolandcode/releases), ou construa a partir do código-fonte:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Baixe um instantâneo do catálogo de modelos
curl -fsSL -o models-api.json https://models.dev/api.json

# Build
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

O binário está em `dist/opencode-linux-x64/bin/rolandcode` (ou o equivalente para sua plataforma).

## Verificação

Cada build pode ser verificado como limpo:

```bash
bash scripts/verify-clean.sh
```

Isso executa um grep em toda a árvore de código-fonte por todos os domínios de telemetria conhecidos e pacotes de SDK. Se alguma referência permanecer, a build falha. O grep não mente.

## Como funciona

O Rolandcode mantém um pequeno conjunto de patches sobre o OpenCode original. Cada commit de remoção elimina uma preocupação de telemetria:

- `strip-posthog` — Análise do PostHog
- `strip-honeycomb` — Telemetria do Honeycomb
- `strip-exa` — Encaminhamento de busca do mcp.exa.ai
- `strip-opencode-api` — Endpoints do api.opencode.ai e opncd.ai
- `strip-zen-gateway` — Roteamento de proxy Zen
- `strip-app-proxy` — Proxy de captura geral do app.opencode.ai
- `strip-share-sync` — Compartilhamento automático de sessão
- `strip-models-dev` — Requisição de lista de modelos em tempo de execução

Commits pequenos e isolados fazem rebase limpo quando o projeto original avança.

## Testes

```bash
# Suíte completa (executa testes de permissão no Docker quando rodando como root)
bash scripts/test.sh

# Apenas a suíte principal
cd packages/opencode && bun test --timeout 30000

# Apenas os testes de permissão (deve ser não-root, ou usar Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Problemas conhecidos de teste

| Teste | Status | Por quê |
|------|--------|-----|
| `session.llm.stream` (2 de 10) | Instável (Flaky) | Estado do servidor HTTP mock vaza entre testes paralelos. Passa 10/10 quando executado em isolamento (`bun test test/session/llm.test.ts`). Bug de isolamento de teste do upstream — não é um defeito de código. |
| `tool.write > throws error when OS denies write access` | Falha como root | Root ignora `chmod 0o444`. Passa no Docker como não-root. `scripts/test.sh` lida com isso automaticamente. |
| `tui config > continues loading when legacy source cannot be stripped` | Falha como root | Mesmo problema root-vs-chmod. Passa no Docker como não-root. |
| `fsmonitor` (2 testes) | Pulado | Apenas Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 teste) | Pulado | Apenas Windows. |
| `unicode filenames modification and restore` | Pulado | Pulado explicitamente pelo upstream — bug conhecido que eles não corrigiram. |

## Projeto Original (Upstream)

Este é um fork do [anomalyco/opencode](https://github.com/anomalyco/opencode) (licença MIT). Todo o código original é deles. O histórico completo de commits do upstream é preservado — você pode ver exatamente o que foi alterado e por quê.

O OpenCode é um agente de código IA capaz com uma excelente TUI, suporte a LSP e flexibilidade de múltiplos provedores. Nós o usamos porque é um bom software. Removemos a telemetria porque as alegações de privacidade não correspondem ao comportamento.

## Licença

MIT — mesma do upstream. Veja [LICENSE](LICENSE).
