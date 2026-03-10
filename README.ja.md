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

[OpenCode](https://github.com/anomalyco/opencode) のクリーンなフォークです。すべてのテレメトリおよびフォーンホーム（外部への報告）機能が削除されています。

OpenCode は自らを「プライバシーファースト」かつ「オープンソース」と宣伝していますが、実際には複数のサードパーティサービスへデータを静かに送信しています（分析用 PostHog、テレメトリ用 Honeycomb、セッション共有用 opncd.ai、プロンプトプロキシ用 opencode.ai/zen、検索クエリ転送用 mcp.exa.ai、IP 漏洩を伴うモデルリスト取得用 models.dev など）。メンテナは当初テレメトリの存在を否定していましたが（[#459](https://github.com/sst/opencode/issues/459)）、後に認めました。ユーザーは設定でテレメトリを無効にしても、外部への接続が完全に止まらないことを報告しています（[#5554](https://github.com/sst/opencode/issues/5554)）。

Rolandcode は OpenCode に変更を促そうとはしません。単にテレメトリを削除し、クリーンなビルドを公開するだけです。

名前はブラウニングの詩『チャイルド・ロランドは暗黒の塔に到達した』（*Childe Roland to the Dark Tower Came*）に由来します。ロランドは彼を止めるあらゆるもののせいで塔に到達しました。

---

## 削除されたもの

| エンドポイント | 送信された内容 |
|----------|-------------|
| `us.i.posthog.com` | 使用状況分析 |
| `api.honeycomb.io` | テレメトリ、IP アドレス、所在地 |
| `api.opencode.ai` | セッション内容、プロンプト |
| `opncd.ai` | セッション共有データ |
| `opencode.ai/zen/v1` | OpenCode のゲートウェイを経由してプロキシされたプロンプト |
| `mcp.exa.ai` | 検索クエリ |
| `models.dev` | モデルリスト取得（IP を漏洩） |
| `app.opencode.ai` | キャッチオールアプリプロキシ |

モデルカタログは、ビルド時にローカルのスナップショットからベンダー化されます。ランタイムでのフォーンホームはありません。

## インストール

[リリースページ](https://github.com/TODO/rolandcode/releases) からバイナリをダウンロードするか、ソースからビルドします：

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Download a model catalog snapshot
curl -fsSL -o models-api.json https://models.dev/api.json

# Build
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

バイナリは `dist/opencode-linux-x64/bin/rolandcode` にあります（または、プラットフォームに応じて同等の場所）。

## 検証

すべてのビルドはクリーンであることを検証できます：

```bash
bash scripts/verify-clean.sh
```

これは、既知のすべてのテレメトリドメインおよび SDK パッケージに対してソースツリー全体を grep します。参照が残っている場合、ビルドは失敗します。Grep は嘘をつきません。

## 仕組み

Rolandcode は、アップストリームの OpenCode 上に小さなパッチセットを維持しています。各ストリップコミットは 1 つのテレメトリ関心領域を削除します：

- `strip-posthog` — PostHog 分析
- `strip-honeycomb` — Honeycomb テレメトリ
- `strip-exa` — mcp.exa.ai 検索転送
- `strip-opencode-api` — api.opencode.ai および opncd.ai エンドポイント
- `strip-zen-gateway` — Zen プロキシルーティング
- `strip-app-proxy` — app.opencode.ai キャッチオールプロキシ
- `strip-share-sync` — 自動セッション共有
- `strip-models-dev` — ランタイムモデルリスト取得

小さな、分離されたコミットは、アップストリームが移動した際にクリーンにリベースできます。

## テスト

```bash
# Full suite (runs permission tests in Docker when running as root)
bash scripts/test.sh

# Just the main suite
cd packages/opencode && bun test --timeout 30000

# Just the permission tests (must be non-root, or use Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### 既知のテストの問題点

| テスト | ステータス | 理由 |
|------|--------|-----|
| `session.llm.stream` (10 のうち 2 つ) | 不安定 | モック HTTP サーバーの状態が並列テスト間で漏洩します。孤立して実行すると 10/10 でパスします（`bun test test/session/llm.test.ts`）。アップストリームのテスト分離バグであり、コードの欠陥ではありません。 |
| `tool.write > OS が書き込みアクセスを拒否した際のエラースロー` | root として実行すると失敗 | root は `chmod 0o444` をバイパスします。Docker の非 root 環境ではパスします。`scripts/test.sh` がこれを自動的に処理します。 |
| `tui config > レガシーソースをストリップできない場合の読み込み継続` | root として実行すると失敗 | 同じ root 対 chmod の問題。Docker の非 root 環境ではパスします。 |
| `fsmonitor` (2 テスト) | スキップ | Windows 専用（`process.platform === "win32"`）。 |
| `worktree-remove` (1 テスト) | スキップ | Windows 専用。 |
| `ユニコードファイル名の修正と復元` | スキップ | アップストリームで明示的にスキップ済み — 修正されていない既知のバグ。 |

## アップストリーム

これは [anomalyco/opencode](https://github.com/anomalyco/opencode) のフォークです（MIT ライセンス）。すべての元のコードは彼らのものです。完全なアップストリームコミット履歴は保存されています — 何が変わり、なぜ変わったかが正確に見えます。

OpenCode は、優れた TUI、LSP サポート、マルチプロバイダーの柔軟性を備えた有能な AI コーディングエージェントです。良いソフトウェアなので使用しています。プライバシーの主張が実際の動作と一致しないので、テレメトリを削除しています。

## ライセンス

MIT — アップストリームと同じ。[LICENSE](LICENSE) を参照。
