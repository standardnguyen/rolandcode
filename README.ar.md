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

شعبة نظيفة من [OpenCode](https://github.com/anomalyco/opencode) تمت إزالة جميع بيانات التتبع (Telemetry) وسلوك "الاتصال الخلفي" (Phone-home) منها.

تسوق OpenCode نفسها على أنها "تضع الخصوصية أولاً" و"مفتوحة المصدر"، لكنها تنقل البيانات بصمت إلى خدمات طرف ثالث متعددة — تحليلات الاستخدام (PostHog)، قياس الأداء (Honeycomb)، مشاركة الجلسات (opncd.ai)، ووكالة الأوامر (prompt proxying) (opencode.ai/zen)، وتوجيه استعلامات البحث (mcp.exa.ai)، وجلب قوائم النماذج التي تسرب عناوين IP (models.dev). أنكر الحفاظون على المشروع في البداية وجود قياس للأداء ([#459](https://github.com/sst/opencode/issues/459))، ثم اعترفوا به. يبلغ المستخدمون أن تعطيل قياس الأداء في ملف التكوين لا يوقف اتصالات الخروج بالكامل ([#5554](https://github.com/sst/opencode/issues/554)).

لا يحاول Rolandcode إقناع OpenCode بالتغيير. إنه ببساطة يزيل بيانات التتبع الخاصة بهم وينشر نسخًا نظيفة.

الاسم مستمد من شعر روبرت براونينغ "جاء رولاند الطفل إلى البرج المظلم" (Childe Roland to the Dark Tower Came) — يصل رولاند إلى البرج على الرغم من كل ما يحاول إيقافه.

---

## ما تم إزالته

| Endpoint | ما أرسله |
|----------|-------------|
| `us.i.posthog.com` | تحليلات الاستخدام |
| `api.honeycomb.io` | بيانات التتبع، عنوان IP، الموقع |
| `api.opencode.ai` | محتوى الجلسة، الأوامر (Prompts) |
| `opncd.ai` | بيانات مشاركة الجلسة |
| `opencode.ai/zen/v1` | أوامر تم توجيهها عبر بوابة OpenCode |
| `mcp.exa.ai` | استعلامات البحث |
| `models.dev` | جلب قوائم النماذج (يسرب IP) |
| `app.opencode.ai` | وكيل التطبيق الشامل (Catch-all) |

يتم تضمين كتالوج النماذج (Model Catalog) في وقت البناء من نسخة محلية — بدون اتصال خلفي في وقت التشغيل.

## التثبيت

قم بتنزيل ملف تنفيذي من [صفحة الإصدارات](https://github.com/TODO/rolandcode/releases)، أو قم بالبناء من المصدر:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# تنزيل نسخة من كتالوج النماذج
curl -fsSL -o models-api.json https://models.dev/api.json

# البناء
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

الملف التنفيذي موجود في `dist/opencode-linux-x64/bin/rolandcode` (أو ما يعادله لمنصتك).

## التحقق

يمكن التحقق من نظافة كل نسخة:

```bash
bash scripts/verify-clean.sh
```

هذا الأمر يفحص شجرة المصدر بالكامل بحثًا عن جميع نطاقات التتبع المعروفة وحزم SDK. إذا بقي أي مرجع، تفشل النسخة. grep لا يكذب.

## كيف يعمل

يحتفظ Rolandcode بمجموعة صغيرة من التصحيحات (Patches) فوق OpenCode الأصلي. كل تسليم إزالة (Strip Commit) يزيل مخاوف التتبع واحدة تلو الأخرى:

- `strip-posthog` — تحليلات PostHog
- `strip-honeycomb` — قياس أداء Honeycomb
- `strip-exa` — توجيه بحث mcp.exa.ai
- `strip-opencode-api` — نقاط نهاية api.opencode.ai و opncd.ai
- `strip-zen-gateway` — توجيه وكيل Zen
- `strip-app-proxy` — وكيل app.opencode.ai الشامل
- `strip-share-sync` — مشاركة الجلسة التلقائية
- `strip-models-dev` — جلب قوائم النماذج في وقت التشغيل

التسليمات الصغيرة والمعزولة تعيد أساسها (Rebase) بشكل نظيف عند تحرك المصدر الأصلي.

## الاختبار

```bash
# المجموعة الكاملة (تشغيل اختبارات الأذونات في Docker عند التشغيل كمسؤول)
bash scripts/test.sh

# فقط المجموعة الرئيسية
cd packages/opencode && bun test --timeout 30000

# فقط اختبارات الأذونات (يجب أن يكون غير مسؤول، أو استخدام Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### مشاكل الاختبار المعروفة

| الاختبار | الحالة | السبب |
|------|--------|-----|
| `session.llm.stream` (2 من 10) | غير مستقر (Flaky) | تسرب حالة خادم HTTP الوهمي (Mock) بين الاختبارات المتوازية. يمر 10/10 عند التشغيل في عزلة (`bun test test/session/llm.test.ts`). عيب في عزل الاختبارات في المصدر الأصلي — وليس عيبًا في الكود. |
| `tool.write > يرمي خطأ عندما يمنع نظام التشغيل الوصول للكتابة` | يفشل كمسؤول (Root) | المسؤول يتجاوز `chmod 0o444`. يمر في Docker كغير مسؤول. `scripts/test.sh` يتعامل مع هذا تلقائيًا. |
| `tui config > يستمر التحميل عندما لا يمكن إزالة المصدر القديم` | يفشل كمسؤول | نفس مشكلة المسؤول مقابل chmod. يمر في Docker كغير مسؤول. |
| `fsmonitor` (2 اختبارات) | متخطى | ويندوز فقط (`process.platform === "win32"`). |
| `worktree-remove` (1 اختبار) | متخطى | ويندوز فقط. |
| `تعديل واستعادة أسماء الملفات Unicode` | متخطى | تم تخطيه صراحة في المصدر الأصلي — عيب معروف لم يتم إصلاحه. |

## المصدر الأصلي (Upstream)

هذه شعبة من [anomalyco/opencode](https://github.com/anomalyco/opencode) (ترخيص MIT). كل الكود الأصلي ملكهم. يتم حفظ تاريخ التسليم الكامل للمصدر الأصلي — يمكنك رؤية بالضبط ما تم تغييره ولماذا.

OpenCode هو وكيل برمجة ذكاء اصطناعي قادر مع واجهة نصية رائعة (TUI)، ودعم LSP، ومرونة متعددة المزودين. نستخدمه لأنه برنامج جيد. نزيل بيانات التتبع لأن مطالبات الخصوصية لا تتطابق مع السلوك.

## الترخيص

MIT — نفس المصدر الأصلي. راجع [LICENSE](LICENSE).
