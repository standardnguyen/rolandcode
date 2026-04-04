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

Một bản fork sạch sẽ của [OpenCode](https://github.com/anomalyco/opencode) với tất cả telemetry và hành vi phone-home bị loại bỏ.

OpenCode tự quảng bá mình là "ưu tiên quyền riêng tư" và "mã nguồn mở", nhưng âm thầm truyền tải dữ liệu đến nhiều dịch vụ bên thứ ba — phân tích (PostHog), telemetry (Honeycomb), chia sẻ phiên (opncd.ai), proxy prompt (opencode.ai/zen), chuyển tiếp truy vấn tìm kiếm (mcp.exa.ai), và lấy danh sách mô hình rò rỉ IP (models.dev). Người duy trì ban đầu phủ nhận việc tồn tại telemetry ([#459](https://github.com/sst/opencode/issues/459)), sau đó thừa nhận. Người dùng báo cáo rằng việc tắt telemetry trong cấu hình không hoàn toàn dừng các kết nối đi ra ([#5554](https://github.com/sst/opencode/issues/5554)).

Rolandcode không cố gắng thuyết phục OpenCode thay đổi. Nó chỉ loại bỏ telemetry của họ và phân phối các bản build sạch.

Tên gọi lấy từ tác phẩm của Browning *Childe Roland đến Tháp Tối Tăm* — Roland đến được tháp bất chấp mọi thứ cố gắng ngăn cản anh ta.

---

## Những gì bị loại bỏ

| Endpoint | Dữ liệu gửi đi |
|----------|-------------|
| `us.i.posthog.com` | Phân tích sử dụng |
| `api.honeycomb.io` | Telemetry, địa chỉ IP, vị trí |
| `api.opencode.ai` | Nội dung phiên, prompt |
| `opncd.ai` | Dữ liệu chia sẻ phiên |
| `opencode.ai/zen/v1` | Prompt được proxy qua cổng của OpenCode |
| `mcp.exa.ai` | Truy vấn tìm kiếm |
| `models.dev` | Lấy danh sách mô hình (rò rỉ IP) |
| `app.opencode.ai` | Proxy ứng dụng tổng hợp |

Danh mục mô hình được đóng gói tại thời điểm build từ một bản chụp địa phương — không có phone-home lúc runtime.

## Cài đặt

Tải một binary từ [trang releases](https://github.com/TODO/rolandcode/releases), hoặc build từ nguồn:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Tải bản chụp danh mục mô hình
curl -fsSL -o models-api.json https://models.dev/api.json

# Build
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Binary nằm tại `dist/opencode-linux-x64/bin/rolandcode` (hoặc tương đương cho nền tảng của bạn).

## Xác minh

Mọi bản build đều có thể được xác minh sạch sẽ:

```bash
bash scripts/verify-clean.sh
```

Script này grep toàn bộ cây nguồn cho tất cả các miền telemetry và gói SDK đã biết. Nếu còn bất kỳ tham chiếu nào, build sẽ thất bại. Grep không nói dối.

## Cách hoạt động

Rolandcode duy trì một bộ vá nhỏ trên đầu OpenCode upstream. Mỗi commit strip loại bỏ một mối quan tâm về telemetry:

- `strip-posthog` — Phân tích PostHog
- `strip-honeycomb` — Telemetry Honeycomb
- `strip-exa` — Chuyển tiếp tìm kiếm mcp.exa.ai
- `strip-opencode-api` — Các endpoint api.opencode.ai và opncd.ai
- `strip-zen-gateway` — Định tuyến proxy Zen
- `strip-app-proxy` — Proxy tổng hợp app.opencode.ai
- `strip-share-sync` — Chia sẻ phiên tự động
- `strip-models-dev` — Lấy danh sách mô hình lúc runtime

Các commit nhỏ, biệt lập rebase sạch sẽ khi upstream di chuyển.

## Kiểm thử

```bash
# Bộ đầy đủ (chạy kiểm tra quyền hạn trong Docker khi chạy dưới quyền root)
bash scripts/test.sh

# Chỉ bộ chính
cd packages/opencode && bun test --timeout 30000

# Chỉ kiểm tra quyền hạn (phải không phải root, hoặc dùng Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Vấn đề kiểm thử đã biết

| Kiểm thử | Trạng thái | Tại sao |
|------|--------|-----|
| `session.llm.stream` (2 trong 10) | Không ổn định (Flaky) | Trạng thái máy chủ HTTP giả mạo rò rỉ giữa các kiểm thử song song. Đạt 10/10 khi chạy biệt lập (`bun test test/session/llm.test.ts`). Lỗi biệt lập kiểm thử upstream — không phải lỗi mã. |
| `tool.write > throws error when OS denies write access` | Thất bại khi là root | Root bỏ qua `chmod 0o444`. Đạt trong Docker khi không phải root. `scripts/test.sh` xử lý điều này tự động. |
| `tui config > continues loading when legacy source cannot be stripped` | Thất bại khi là root | Vấn đề root-vs-chmod tương tự. Đạt trong Docker khi không phải root. |
| `fsmonitor` (2 kiểm thử) | Bỏ qua | Chỉ dành cho Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 kiểm thử) | Bỏ qua | Chỉ dành cho Windows. |
| `unicode filenames modification and restore` | Bỏ qua | Upstream bỏ qua rõ ràng — lỗi đã biết họ chưa sửa. |

## Upstream

Đây là bản fork của [anomalyco/opencode](https://github.com/anomalyco/opencode) (giấy phép MIT). Tất cả mã nguồn gốc là của họ. Lịch sử commit upstream đầy đủ được lưu giữ — bạn có thể thấy chính xác những gì đã thay đổi và tại sao.

OpenCode là một tác nhân lập trình AI có năng lực với TUI tuyệt vời, hỗ trợ LSP, và tính linh hoạt đa nhà cung cấp. Chúng tôi sử dụng nó vì nó là phần mềm tốt. Chúng tôi loại bỏ telemetry vì các tuyên bố về quyền riêng tư không khớp với hành vi.

## Giấy phép

MIT — giống như upstream. Xem [LICENSE](LICENSE).
