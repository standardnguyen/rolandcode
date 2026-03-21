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

[OpenCode](https://github.com/anomalyco/opencode) 의 깔끔한 포크로, 모든 텔레메트리 및 폰홈 (phone-home) 기능이 제거되었습니다.

OpenCode 는 자신을 "프라이버시 우선" 과 "오픈 소스" 라 홍보하지만, 여러 제 3 자 서비스로 데이터를 조용히 전송합니다 — 분석 (PostHog), 텔레메트리 (Honeycomb), 세션 공유 (opncd.ai), 프롬프트 프록시 (opencode.ai/zen), 검색 쿼리 전달 (mcp.exa.ai), 그리고 IP 유출되는 모델 목록 조회 (models.dev). 유지자들은 초기에 텔레메트리가 존재한다고 부인했다가 ([#459](https://github.com/sst/opencode/issues/459)), 이후 이를 인정했습니다. 사용자들은 설정에서 텔레메트리를 비활성화해도 외부 연결이 완전히 중지되지 않는다고 보고합니다 ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode 는 OpenCode 가 변경되도록 설득하려고 하지 않습니다. 그저 텔레메트리를 제거하고 깨끗한 빌드를 배포할 뿐입니다.

이 이름은 브라우닝의 시 *Childe Roland to the Dark Tower Came* 에서 유래했습니다. 롤란드는 그를 막으려던 모든 것을 뚫고 탑에 도달합니다.

---

## 제거된 항목

| 엔드포인트 | 전송한 내용 |
|----------|-------------|
| `us.i.posthog.com` | 사용량 분석 |
| `api.honeycomb.io` | 텔레메트리, IP 주소, 위치 |
| `api.opencode.ai` | 세션 내용, 프롬프트 |
| `opncd.ai` | 세션 공유 데이터 |
| `opencode.ai/zen/v1` | OpenCode 게이트웨이를 경유한 프롬프트 |
| `mcp.exa.ai` | 검색 쿼리 |
| `models.dev` | 모델 목록 조회 (IP 유출) |
| `app.opencode.ai` | 전체 앱 프록시 |

모델 카탈로그는 빌드 시점에 로컬 스냅샷에서 벤더링되며, 런타임 폰홈 연결이 없습니다.

## 설치

[릴리스 페이지](https://github.com/TODO/rolandcode/releases) 에서 이진 파일을 다운로드하거나 소스에서 빌드하세요:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# 모델 카탈로그 스냅샷 다운로드
curl -fsSL -o models-api.json https://models.dev/api.json

# 빌드
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

이진 파일은 `dist/opencode-linux-x64/bin/rolandcode` (또는 플랫폼에 따른 해당 파일) 에 있습니다.

## 검증

모든 빌드는 깨끗하게 검증될 수 있습니다:

```bash
bash scripts/verify-clean.sh
```

이 스크립트는 전체 소스 트리에서 알려진 텔레메트리 도메인과 SDK 패키지를 검색합니다. 참조가 남아 있으면 빌드가 실패합니다. Grep 은 거짓말을 하지 않습니다.

## 동작 원리

Rolandcode 는 업스트림 OpenCode 위에 작은 패치 세트를 유지합니다. 각 스트립 (strip) 커밋은 하나의 텔레메트리 문제를 제거합니다:

- `strip-posthog` — PostHog 분석
- `strip-honeycomb` — Honeycomb 텔레메트리
- `strip-exa` — mcp.exa.ai 검색 전달
- `strip-opencode-api` — api.opencode.ai 및 opncd.ai 엔드포인트
- `strip-zen-gateway` — Zen 프록시 라우팅
- `strip-app-proxy` — app.opencode.ai 전체 프록시
- `strip-share-sync` — 자동 세션 공유
- `strip-models-dev` — 런타임 모델 목록 조회

작고 격리된 커밋은 업스트림이 변경될 때도 깔끔하게 리베이스됩니다.

## 테스트

```bash
# 전체 테스트 세트 (루트로 실행 시 Docker 에서 권한 테스트 실행)
bash scripts/test.sh

# 메인 테스트 세트만
cd packages/opencode && bun test --timeout 30000

# 권한 테스트만 (루트가 아니어야 하거나 Docker 사용)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### 알려진 테스트 이슈

| 테스트 | 상태 | 이유 |
|------|--------|-----|
| `session.llm.stream` (10 개 중 2 개) | 불안정 (Flaky) | 모의 HTTP 서버 상태가 병렬 테스트 간 누출됨. 격리 실행 시 10/10 통과 (`bun test test/session/llm.test.ts`). 업스트림 테스트 격리 버그 — 코드 결함 아님. |
| `tool.write > OS 가 쓰기 접근을 거부할 때 오류 발생` | 루트 권한 시 실패 | 루트는 `chmod 0o444` 를 우회합니다. Docker 에서 비루트로 실행 시 통과. `scripts/test.sh` 가 이를 자동으로 처리합니다. |
| `tui config > 레거시 소스를 스트립할 수 없을 때 로딩 계속` | 루트 권한 시 실패 | 동일한 루트 대 chmod 이슈. Docker 에서 비루트로 실행 시 통과. |
| `fsmonitor` (2 개 테스트) | 생략 (Skipped) | Windows 전용 (`process.platform === "win32"`). |
| `worktree-remove` (1 개 테스트) | 생략 (Skipped) | Windows 전용. |
| `유니코드가 포함된 파일명 수정 및 복원` | 생략 (Skipped) | 업스트림에서 명시적으로 생략됨 — 수정하지 않은 알려진 버그. |

## 업스트림

이 프로젝트는 [anomalyco/opencode](https://github.com/anomalyco/opencode) (MIT 라이선스) 의 포크입니다. 모든 기존 코드는 그들의 소유입니다. 전체 업스트림 커밋 히스토리가 보존되어 있으므로 정확히 무엇이 변경되었고 그 이유가 무엇인지 확인할 수 있습니다.

OpenCode 는 뛰어난 TUI, LSP 지원, 다중 제공자 유연성을 갖춘 유능한 AI 코딩 에이전트입니다. 우리는 그것이 좋은 소프트웨어이기 때문에 사용합니다. 프라이버시 주장이 실제 동작과 맞지 않기 때문에 텔레메트리를 제거합니다.

## 라이선스

MIT — 업스트림과 동일합니다. [LICENSE](LICENSE) 파일을 참조하세요.
