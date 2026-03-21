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

[OpenCode](https://github.com/anomalyco/opencode) 的一个干净分支，移除了所有遥测和回连（phone-home）行为。

OpenCode 宣传自己是“隐私优先”和“开源”的，但静默地将数据传输到多个第三方服务——分析（PostHog）、遥测（Honeycomb）、会话共享（opncd.ai）、提示词代理（opencode.ai/zen）、搜索查询转发（mcp.exa.ai）以及泄露 IP 的模型列表获取（models.dev）。维护者最初否认存在遥测（[#459](https://github.com/sst/opencode/issues/459)），随后又承认了。用户报告称，在配置中禁用遥测并不能完全停止出站连接（[#5554](https://github.com/sst/opencode/issues/5554)）。

Rolandcode 不试图说服 OpenCode 做出改变。它只是剥离他们的遥测并发布干净的构建版本。

名字源自布朗宁的《奇尔德·罗兰来到黑塔》（*Childe Roland to the Dark Tower Came*）——罗兰不顾一切阻碍，最终抵达了塔楼。

---

## 移除的内容

| 端点 | 发送了什么 |
|----------|-------------|
| `us.i.posthog.com` | 使用分析 |
| `api.honeycomb.io` | 遥测、IP 地址、位置 |
| `api.opencode.ai` | 会话内容、提示词 |
| `opncd.ai` | 会话共享数据 |
| `opencode.ai/zen/v1` | 通过 OpenCode 网关代理的提示词 |
| `mcp.exa.ai` | 搜索查询 |
| `models.dev` | 模型列表获取（泄露 IP） |
| `app.opencode.ai` | 通用应用代理 |

模型目录在构建时从本地快照嵌入——没有运行时回连。

## 安装

从 [发布页面](https://github.com/TODO/rolandcode/releases) 下载二进制文件，或从源码构建：

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# 下载模型目录快照
curl -fsSL -o models-api.json https://models.dev/api.json

# 构建
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

二进制文件位于 `dist/opencode-linux-x64/bin/rolandcode`（或您平台的等效路径）。

## 验证

每个构建都可以验证为干净：

```bash
bash scripts/verify-clean.sh
```

这会在整个源码树中 grep 所有已知的遥测域名和 SDK 包。如果仍有引用，构建将失败。grep 不会撒谎。

## 工作原理

Rolandcode 在上游 OpenCode 之上维护一个小的补丁集。每个剥离提交移除一个遥测关注点：

- `strip-posthog` — PostHog 分析
- `strip-honeycomb` — Honeycomb 遥测
- `strip-exa` — mcp.exa.ai 搜索转发
- `strip-opencode-api` — api.opencode.ai 和 opncd.ai 端点
- `strip-zen-gateway` — Zen 代理路由
- `strip-app-proxy` — app.opencode.ai 通用代理
- `strip-share-sync` — 自动会话共享
- `strip-models-dev` — 运行时模型列表获取

小型、孤立的提交在上游移动时可以干净地变基。

## 测试

```bash
# 全套测试（以 root 运行时在 Docker 中运行权限测试）
bash scripts/test.sh

# 仅主测试套件
cd packages/opencode && bun test --timeout 30000

# 仅权限测试（必须是非 root，或使用 Docker）
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### 已知的测试问题

| 测试 | 状态 | 原因 |
|------|--------|-----|
| `session.llm.stream` (2 of 10) | 不稳定 | 模拟 HTTP 服务器状态在并行测试间泄漏。隔离运行时通过率为 10/10 (`bun test test/session/llm.test.ts`)。上游测试隔离 bug——非代码缺陷。 |
| `tool.write > throws error when OS denies write access` | 以 root 身份运行失败 | root 绕过 `chmod 0o444`。在 Docker 中以非 root 身份运行通过。`scripts/test.sh` 会自动处理此问题。 |
| `tui config > continues loading when legacy source cannot be stripped` | 以 root 身份运行失败 | 同样的 root 与 chmod 问题。在 Docker 中以非 root 身份运行通过。 |
| `fsmonitor` (2 个测试) | 跳过 | 仅限 Windows (`process.platform === "win32"`)。 |
| `worktree-remove` (1 个测试) | 跳过 | 仅限 Windows。 |
| `unicode filenames modification and restore` | 跳过 | 上游明确跳过——已知 bug 尚未修复。 |

## 上游

这是 [anomalyco/opencode](https://github.com/anomalyco/opencode) 的一个分支（MIT 许可证）。所有原始代码归他们所有。完整的上游提交历史被保留——您可以确切看到更改了什么以及为什么。

OpenCode 是一个功能强大的 AI 编程代理，拥有出色的 TUI、LSP 支持和多提供商灵活性。我们使用它因为它是很好的软件。我们剥离遥测是因为隐私声明与行为不符。

## 许可证

MIT — 与上游相同。参见 [LICENSE](LICENSE)。
