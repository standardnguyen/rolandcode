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

[OpenCode]-এর একটি পরিষ্কার ফর্ক যেখানে সমস্ত টেলিমিট্রি এবং ফোন-হোম আচরণ অপসারণ করা হয়েছে।

OpenCode নিজেকে "গোপনীয়তা-প্রথম" এবং "ওপেন সোর্স" হিসেবে প্রচার করে, কিন্তু নীরবে একাধিক তৃতীয় পক্ষের সার্ভিসে ডেটা পাঠায় — বিশ্লেষণ (PostHog), টেলিমিট্রি (Honeycomb), সেশন শেয়ারিং (opncd.ai), প্রম্পট প্রক্সি (opencode.ai/zen), সার্চ কোয়েরি ফরওয়ার্ডিং (mcp.exa.ai), এবং আইপি-লিকিং মডেল লিস্ট ফেচ (models.dev)। মেইনটেইনাররা প্রাথমিকভাবে অস্বীকার করেছিলেন যে টেলিমিট্রি বিদ্যমান ([#459](https://github.com/sst/opencode/issues/459)), পরে তারা এটি স্বীকার করেন। ব্যবহারকারীরা রিপোর্ট করেছেন যে কনফিগ-তে টেলিমিট্রি নিষ্ক্রিয় করলেও আউটবাইন্ড সংযোগ পুরোপুরি থামে না ([#5554](https://github.com/sst/opencode/issues/5554))।

Rolandcode OpenCode-কে পরিবর্তন করতে রাজি করানোর চেষ্টা করে না। এটি শুধুমাত্র তাদের টেলিমিট্রি অপসারণ করে পরিষ্কার বিল্ড শিপ করে।

নামটি ব্রাউনিংয়ের *Childe Roland to the Dark Tower Came*-এর থেকে — রোল্যান্ড সব কিছুকে থামানোর চেষ্টার পরেও টাওয়ারে পৌঁছায়।

## কী অপসারণ করা হয়েছে

| এন্ডপয়েন্ট | কী পাঠানো হতো |
|----------|-------------|
| `us.i.posthog.com` | ব্যবহার বিশ্লেষণ |
| `api.honeycomb.io` | টেলিমিট্রি, আইপি ঠিকানা, অবস্থান |
| `api.opencode.ai` | সেশন কন্টেন্ট, প্রম্পট |
| `opncd.ai` | সেশন শেয়ারিং ডেটা |
| `opencode.ai/zen/v1` | OpenCode-এর গেটওয়ে-র মাধ্যমে প্রক্সি করা প্রম্পট |
| `mcp.exa.ai` | সার্চ কোয়েরি |
| `models.dev` | মডেল লিস্ট ফেচ (আইপি লিক করে) |
| `app.opencode.ai` | ক্যাচ-অল অ্যাপ প্রক্সি |

মডেল ক্যাটালগ বিল্ডের সময় একটি স্থানীয় স্ন্যাপশট থেকে ভেন্ডর করা হয় — কোনো রানটাইম ফোন-হোম নেই।

## ইনস্টলেশন

[রিলিজ পেজ](https://github.com/TODO/rolandcode/releases) থেকে একটি বাইনারি ডাউনলোড করুন, অথবা সোর্স থেকে বিল্ড করুন:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# একটি মডেল ক্যাটালগ স্ন্যাপশট ডাউনলোড করুন
curl -fsSL -o models-api.json https://models.dev/api.json

# বিল্ড করুন
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

বাইনারিটি `dist/opencode-linux-x64/bin/rolandcode`-এ অবস্থিত (অথবা আপনার প্ল্যাটফর্মের জন্য সমমানের)।

## যাচাই

প্রতিটি বিল্ড পরিষ্কার হিসেবে যাচাই করা যায়:

```bash
bash scripts/verify-clean.sh
```

এটি সমস্ত পরিচিত টেলিমিট্রি ডোমেইন এবং এসডিকে প্যাকেজের জন্য পুরো সোর্স ট্রি-তে গ্রিপ করে। যদি কোনো রেফারেন্স থাকে, বিল্ড ব্যর্থ হয়। গ্রিপ মিথ্যা বলে না।

## এটি কীভাবে কাজ করে

Rolandcode আপস্ট্রিম OpenCode-এর উপরে একটি ছোট প্যাচ সেট বজায় রাখে। প্রতিটি স্ট্রিপ কমিট একটি টেলিমিট্রি বিষয় অপসারণ করে:

- `strip-posthog` — PostHog বিশ্লেষণ
- `strip-honeycomb` — Honeycomb টেলিমিট্রি
- `strip-exa` — mcp.exa.ai সার্চ ফরওয়ার্ডিং
- `strip-opencode-api` — api.opencode.ai এবং opncd.ai এন্ডপয়েন্ট
- `strip-zen-gateway` — Zen প্রক্সি রাউটিং
- `strip-app-proxy` — app.opencode.ai ক্যাচ-অল প্রক্সি
- `strip-share-sync` — স্বয়ংক্রিয় সেশন শেয়ারিং
- `strip-models-dev` — রানটাইম মডেল লিস্ট ফেচিং

ছোট, বিচ্ছিন্ন কমিট আপস্ট্রিম যখন সরে যায় তখন পরিষ্কারভাবে রিবেজ হয়।

## টেস্টিং

```bash
# পূর্ণ সুট (রুট হিসেবে রান করার সময় ডকারে অনুমতি টেস্ট চালায়)
bash scripts/test.sh

# শুধুমাত্র প্রধান সুট
cd packages/opencode && bun test --timeout 30000

# শুধুমাত্র অনুমতি টেস্ট (রুট-হীন হতে হবে, অথবা ডকার ব্যবহার করুন)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### জানা টেস্ট ইস্যু

| টেস্ট | অবস্থা | কারণ |
|------|--------|-----|
| `session.llm.stream` (১০-এর মধ্যে ২টি) | অস্থির | সমান্তরাল টেস্টের মধ্যে মক HTTP সার্ভার অবস্থা লিক করে। বিচ্ছিন্নভাবে চালানো হলে ১০/১০ পাস করে (`bun test test/session/llm.test.ts`)। আপস্ট্রিম টেস্ট বিচ্ছিন্নতা বাগ — কোডের ত্রুটি নয়। |
| `tool.write > OS লেখা অ্যাক্সেস প্রত্যাখ্যান করলে ত্রুটি ফেলে` | রুট হিসেবে ব্যর্থ | রুট `chmod 0o444` বাইপাস করে। ডকারে রুট-হীন হিসেবে পাস করে। `scripts/test.sh` এটি স্বয়ংক্রিয়ভাবে পরিচালনা করে। |
| `tui config > লেগেসি সোর্স অপসারণ করা না গেলে লোডিং চালিয়ে যায়` | রুট হিসেবে ব্যর্থ | একই রুট-বনাম-chmod ইস্যু। ডকারে রুট-হীন হিসেবে পাস করে। |
| `fsmonitor` (২টি টেস্ট) | স্কিপ | উইন্ডোজ-এর জন্য (`process.platform === "win32"`). |
| `worktree-remove` (১টি টেস্ট) | স্কিপ | উইন্ডোজ-এর জন্য। |
| `unicode filenames modification and restore` | স্কিপ | আপস্ট্রিম স্পষ্টভাবে স্কিপ করেছে — তারা ঠিক করেননি এমন একটি জানা বাগ। |

## আপস্ট্রিম

এটি [anomalyco/opencode]-এর একটি ফর্ক (MIT লাইসেন্স)। সমস্ত মূল কোড তাদের। পুরো আপস্ট্রিম কমিট ইতিহাস সংরক্ষিত — আপনি ঠিক কী পরিবর্তন হয়েছে এবং কেন তা দেখতে পারেন।

OpenCode একটি সক্ষম এআই কোডিং এজেন্ট যার চমৎকার টিইউআই, এলএসপি সাপোর্ট, এবং মাল্টি-প্রোভাইডার নমনীয়তা আছে। আমরা এটি ব্যবহার করি কারণ এটি ভালো সফটওয়্যার। আমরা টেলিমিট্রি অপসারণ করি কারণ গোপনীয়তার দাবি আচরণের সাথে মিলে না।

## লাইসেন্স

MIT — আপস্ট্রিমের মতো। দেখুন [LICENSE](LICENSE)।
