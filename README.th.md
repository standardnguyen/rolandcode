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

การแยกสาขา (fork) ที่สะอาดของ [OpenCode](https://github.com/anomalyco/opencode) โดยมีการลบการติดตามการใช้งาน (telemetry) และพฤติกรรมการติดต่อกลับเซิร์ฟเวอร์ (phone-home behavior) ออกทั้งหมด

OpenCode โฆษณาตัวเองว่าเป็น "ความเป็นส่วนตัวเป็นอันดับแรก" และ "โอเพนซอร์ส" แต่กลับส่งข้อมูลไปยังบริการบุคคลที่สามหลายแห่งอย่างเงียบเชียบ — การวิเคราะห์การใช้งาน (PostHog), การติดตามข้อมูล (Honeycomb), การแชร์เซสชัน (opncd.ai), การส่งต่อพรอมต์ (opencode.ai/zen), การส่งต่อคำค้นหา (mcp.exa.ai), และการดึงรายชื่อโมเดลที่รั่วไหลที่อยู่ IP (models.dev) ผู้ดูแลโครงการเดิมได้ปฏิเสธในตอนแรกว่ามีการติดตามข้อมูล ([#459](https://github.com/sst/opencode/issues/459)) ก่อนที่จะยอมรับในภายหลัง ผู้ใช้รายงานว่า การปิดการติดตามข้อมูลในไฟล์คอนฟิกไม่ได้หยุดการเชื่อมต่อออกสู่ภายนอกทั้งหมด ([#5554](https://github.com/sst/opencode/issues/5554))

Rolandcode ไม่ได้พยายามโน้มน้าว OpenCode ให้เปลี่ยนแปลง มันเพียงแค่ลบการติดตามข้อมูลออกและปล่อยเวอร์ชันที่สะอาด

ชื่อนี้มาจากบทกวีของบราวน์นิง *Childe Roland to the Dark Tower Came* (เด็กหนุ่มโรแลนด์มุ่งหน้าสู่หอคอยมืด) — โรแลนด์สามารถไปถึงหอคอยได้ แม้จะมีทุกอย่างพยายามหยุดเขา

---

## สิ่งที่ถูกถอดออก

| จุดปลายทาง (Endpoint) | สิ่งที่ถูกส่ง |
|----------|-------------|
| `us.i.posthog.com` | สถิติการใช้งาน |
| `api.honeycomb.io` | ข้อมูลการติดตาม, ที่อยู่ IP, ตำแหน่งที่ตั้ง |
| `api.opencode.ai` | เนื้อหาเซสชัน, คำสั่ง (prompts) |
| `opncd.ai` | ข้อมูลการแชร์เซสชัน |
| `opencode.ai/zen/v1` | คำสั่งที่ถูกส่งผ่านเกตเวย์ของ OpenCode |
| `mcp.exa.ai` | คำค้นหา |
| `models.dev` | การดึงรายชื่อโมเดล (รั่วไหล IP) |
| `app.opencode.ai` | การส่งต่อแอปแบบรวม (catch-all app proxy) |

แคตตาล็อกโมเดลจะถูกนำเข้า (vendored) ในช่วงเวลาการสร้างจากสแนปช็อตท้องถิ่น — ไม่มีการติดต่อกลับเซิร์ฟเวอร์ขณะรันไทม์

## การติดตั้ง

ดาวน์โหลดไบนารีจาก [หน้าเวอร์ชัน](https://github.com/TODO/rolandcode/releases) หรือสร้างจากซอร์สโค้ด:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# ดาวน์โหลดสแนปช็อตแคตตาล็อกโมเดล
curl -fsSL -o models-api.json https://models.dev/api.json

# สร้าง (Build)
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

ไบนารีจะอยู่ที่ `dist/opencode-linux-x64/bin/rolandcode` (หรือไฟล์เทียบเท่าสำหรับแพลตฟอร์มของคุณ)

## การตรวจสอบ

ทุกครั้งที่สร้างสามารถตรวจสอบความสะอาดได้:

```bash
bash scripts/verify-clean.sh
```

สคริปต์นี้จะค้นหา (grep) ต้นไม้ซอร์สโค้ดทั้งหมดเพื่อหาโดเมนและแพ็กเกจ SDK ที่เกี่ยวข้องกับการติดตามข้อมูลทั้งหมด หากยังมีการอ้างอิงอยู่ การสร้างจะล้มเหลว Grep ไม่เคยโกหก

## วิธีการทำงาน

Rolandcode รักษาชุดแพตช์ขนาดเล็กไว้เหนือ OpenCode ต้นทาง แต่ละครั้งที่แก้ไข (commit) เพื่อลบออกจะจัดการกับปัญหาการติดตามข้อมูลหนึ่งอย่าง:

- `strip-posthog` — สถิติ PostHog
- `strip-honeycomb` — การติดตามข้อมูล Honeycomb
- `strip-exa` — การส่งต่อคำค้นหา mcp.exa.ai
- `strip-opencode-api` — จุดปลายทาง api.opencode.ai และ opncd.ai
- `strip-zen-gateway` — การกำหนดเส้นทางพร็อกซี Zen
- `strip-app-proxy` — พร็อกซีรวม app.opencode.ai
- `strip-share-sync` — การแชร์เซสชันอัตโนมัติ
- `strip-models-dev` — การดึงรายชื่อโมเดลขณะรันไทม์

การแก้ไขที่เล็กและแยกส่วนสามารถทำ Rebase ได้สะอาดเมื่อต้นทางมีการอัปเดต

## การทดสอบ

```bash
# ชุดทดสอบแบบเต็ม (จะรันการทดสอบสิทธิ์ใน Docker เมื่อรันด้วย root)
bash scripts/test.sh

# เฉพาะชุดหลัก
cd packages/opencode && bun test --timeout 30000

# เฉพาะการทดสอบสิทธิ์ (ต้องไม่ใช่ root หรือใช้ Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### ปัญหาการทดสอบที่ทราบแล้ว

| การทดสอบ | สถานะ | เหตุผล |
|------|--------|-----|
| `session.llm.stream` (2 จาก 10) | ไม่เสถียร (Flaky) | สถานะเซิร์ฟเวอร์ HTTP แบบจำลองรั่วไหลระหว่างการทดสอบแบบขนาน ผ่าน 10/10 เมื่อรันแยก (`bun test test/session/llm.test.ts`) บักการแยกส่วนการทดสอบของต้นทาง — ไม่ใช่ข้อบกพร่องของโค้ด |
| `tool.write > throws error when OS denies write access` | ล้มเหลวเมื่อเป็น root | Root สามารถข้าม `chmod 0o444` ได้ ผ่านใน Docker เมื่อไม่ใช่ root `scripts/test.sh` จัดการเรื่องนี้โดยอัตโนมัติ |
| `tui config > continues loading when legacy source cannot be stripped` | ล้มเหลวเมื่อเป็น root | ปัญหา root-vs-chmod เดียวกัน ผ่านใน Docker เมื่อไม่ใช่ root |
| `fsmonitor` (2 การทดสอบ) | ข้าม | เฉพาะ Windows (`process.platform === "win32"`) |
| `worktree-remove` (1 การทดสอบ) | ข้าม | เฉพาะ Windows |
| `unicode filenames modification and restore` | ข้าม | ต้นทางข้ามไว้ชัดเจน — บักที่ทราบแล้วซึ่งพวกเขา尚未แก้ไข |

## ต้นทาง (Upstream)

นี่คือการแยกสาขาของ [anomalyco/opencode](https://github.com/anomalyco/opencode) (ลิขสิทธิ์ MIT) โค้ดดั้งเดิมทั้งหมดเป็นของพวกเขา ประวัติการแก้ไข (commit history) ของต้นทางทั้งหมดได้รับการรักษาไว้ — คุณสามารถเห็นได้อย่างชัดเจนว่าอะไรถูกเปลี่ยนและทำไม

OpenCode เป็นเอเจนต์เขียนโค้ด AI ที่มีความสามารถ พร้อม TUI ที่ยอดเยี่ยม การรองรับ LSP และความยืดหยุ่นของหลายผู้ให้บริการ เราใช้มันเพราะเป็นซอฟต์แวร์ที่ดี เราลบการติดตามข้อมูลออกเพราะคำอ้างเรื่องความเป็นส่วนตัวไม่ตรงกับพฤติกรรม

## ใบอนุญาต

MIT — เหมือนกับต้นทาง ดูที่ [LICENSE](LICENSE)
