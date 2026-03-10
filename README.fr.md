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

Une fourche épurée de [OpenCode](https://github.com/anomalyco/opencode) avec toute télémétrie et tout comportement de 'phone-home' supprimés.

OpenCode se présente comme 'priorité à la vie privée' et 'open source', mais transmet silencieusement des données à plusieurs services tiers — analyses (PostHog), télémétrie (Honeycomb), partage de session (opncd.ai), proxification de prompts (opencode.ai/zen), transfert de requêtes de recherche (mcp.exa.ai), et récupérations de listes de modèles divulguant l'IP (models.dev). Les mainteneurs ont initialement nié l'existence de la télémétrie ([#459](https://github.com/sst/opencode/issues/459)), puis l'ont reconnue. Les utilisateurs rapportent que désactiver la télémétrie dans la configuration n'arrête pas complètement les connexions sortantes ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode ne tente pas de convaincre OpenCode de changer. Il supprime simplement leur télémétrie et fournit des compilations épurées.

Le nom provient de *Childe Roland to the Dark Tower Came* de Browning — Roland atteint la tour malgré tout ce qui tente de l'arrêter.

---

## Ce qui est supprimé

| Point de terminaison | Ce qu'il envoyait |
|----------|-------------|
| `us.i.posthog.com` | Analyses d'utilisation |
| `api.honeycomb.io` | Télémétrie, adresse IP, localisation |
| `api.opencode.ai` | Contenu de session, prompts |
| `opncd.ai` | Données de partage de session |
| `opencode.ai/zen/v1` | Prompts proxifiés via la passerelle d'OpenCode |
| `mcp.exa.ai` | Requêtes de recherche |
| `models.dev` | Récupérations de liste de modèles (divulgue l'IP) |
| `app.opencode.ai` | Proxy d'application universel |

Le catalogue de modèles est intégré au moment de la compilation à partir d'un instantané local — pas de 'phone-home' à l'exécution.

## Installation

Téléchargez un binaire depuis la [page des versions](https://github.com/TODO/rolandcode/releases), ou compilez à partir de la source :

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Téléchargez un instantané du catalogue de modèles
curl -fsSL -o models-api.json https://models.dev/api.json

# Compilez
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Le binaire se trouve à `dist/opencode-linux-x64/bin/rolandcode` (ou l'équivalent pour votre plateforme).

## Vérification

Chaque compilation peut être vérifiée comme épurée :

```bash
bash scripts/verify-clean.sh
```

Cela utilise grep sur tout l'arbre de source pour tous les domaines de télémétrie connus et les packages SDK. Si une référence subsiste, la compilation échoue. Grep ne ment pas.

## Comment ça fonctionne

Rolandcode maintient un petit ensemble de correctifs au-dessus de l'amont OpenCode. Chaque commit de suppression élimine une préoccupation de télémétrie :

- `strip-posthog` — Analyses PostHog
- `strip-honeycomb` — Télémétrie Honeycomb
- `strip-exa` — Transfert de recherche mcp.exa.ai
- `strip-opencode-api` — Points de terminaison api.opencode.ai et opncd.ai
- `strip-zen-gateway` — Routage du proxy Zen
- `strip-app-proxy` — Proxy universel app.opencode.ai
- `strip-share-sync` — Partage automatique de session
- `strip-models-dev` — Récupération de liste de modèles à l'exécution

Les petits commits isolés se rebasent proprement lorsque l'amont évolue.

## Tests

```bash
# Suite complète (exécute les tests de permissions dans Docker lorsqu'exécuté en tant que root)
bash scripts/test.sh

# Juste la suite principale
cd packages/opencode && bun test --timeout 30000

# Juste les tests de permissions (doit être non-root, ou utiliser Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Problèmes de tests connus

| Test | Statut | Pourquoi |
|------|--------|-----|
| `session.llm.stream` (2 sur 10) | Inconstant | L'état du serveur HTTP simulé fuit entre les tests parallèles. Passe 10/10 lorsqu'exécuté en isolation (`bun test test/session/llm.test.ts`). Bug d'isolation de test amont — pas un défaut de code. |
| `tool.write > throws error when OS denies write access` | Échoue en tant que root | Root contourne `chmod 0o444`. Passe dans Docker en tant que non-root. `scripts/test.sh` gère cela automatiquement. |
| `tui config > continues loading when legacy source cannot be stripped` | Échoue en tant que root | Même problème root-vs-chmod. Passe dans Docker en tant que non-root. |
| `fsmonitor` (2 tests) | Ignoré | Windows uniquement (`process.platform === "win32"`). |
| `worktree-remove` (1 test) | Ignoré | Windows uniquement. |
| `unicode filenames modification and restore` | Ignoré | Explicitement ignoré par l'amont — bug connu qu'ils n'ont pas corrigé. |

## Amont

Ceci est une fourche de [anomalyco/opencode](https://github.com/anomalyco/opencode) (licence MIT). Tout le code original est le leur. L'historique complet des commits amont est préservé — vous pouvez voir exactement ce qui a été changé et pourquoi.

OpenCode est un agent de code AI capable avec une excellente interface textuelle, un support LSP et une flexibilité multi-fournisseur. Nous l'utilisons car c'est un bon logiciel. Nous supprimons la télémétrie car les revendications de vie privée ne correspondent pas au comportement.

## Licence

MIT — identique à l'amont. Voir [LICENSE](LICENSE).
