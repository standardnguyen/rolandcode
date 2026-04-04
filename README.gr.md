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

Ένας καθαρός κλάδος (fork) του [OpenCode](https://github.com/anomalyco/opencode) με όλα τα δεδομένα τηλεμετρίας και τη συμπεριφορά επικοινωνίας με τον κεντρικό διακομιστή (phone-home) να έχουν αφαιρεθεί.

Το OpenCode προωθείται ως «πρώτα η ιδιωτικότητα» και «ανοιχτού κώδικα», αλλά σιωπηλά μεταδίδει δεδομένα σε πολλαπλές υπηρεσίες τρίτων — αναλυτικά δεδομένα (PostHog), τηλεμετρία (Honeycomb), διαμοιρασμός συνεδριών (opncd.ai), προαγωγή εντολών (prompt proxying) (opencode.ai/zen), προώθηση ερωτημάτων αναζήτησης (mcp.exa.ai), και ανακτήσεις λιστών μοντέλων που διαρρέουν τη διεύθυνση IP (models.dev). Οι διαχειριστές αρχικά άρνησαν την ύπαρξη τηλεμετρίας ([#459](https://github.com/sst/opencode/issues/459)), και στη συνέχεια την αναγνώρισαν. Οι χρήστες αναφέρουν ότι η απενεργοποίηση της τηλεμετρίας στις ρυθμίσεις δεν σταματά πλήρως τις εξερχόμενες συνδέσεις ([#5554](https://github.com/sst/opencode/issues/5554)).

Το Rolandcode δεν προσπαθεί να πείσει το OpenCode να αλλάξει. Απλώς αφαιρεί την τηλεμετρία τους και παρέχει καθαρές κατασκευές (builds).

Το όνομα προέρχεται από το ποίημα του Browning *Childe Roland to the Dark Tower Came* — ο Roland φτάνει στον πύργο παρά τα πάντα που προσπαθούν να τον σταματήσουν.

---

## Τι αφαιρέθηκε

| Endpoint | Τι απέστειλε |
|----------|-------------|
| `us.i.posthog.com` | Αναλυτικά δεδομένα χρήσης |
| `api.honeycomb.io` | Τηλεμετρία, διεύθυνση IP, τοποθεσία |
| `api.opencode.ai` | Περιεχόμενο συνεδρίας, εντολές (prompts) |
| `opncd.ai` | Δεδομένα διαμοιρασμού συνεδρίας |
| `opencode.ai/zen/v1` | Εντολές που προωθήθηκαν μέσω της πύλης του OpenCode |
| `mcp.exa.ai` | Ερωτήματα αναζήτησης |
| `models.dev` | Ανακτήσεις λιστών μοντέλων (διαρρέει IP) |
| `app.opencode.ai` | Αντικαταστάτης εφαρμογής (catch-all app proxy) |

Ο κατάλογος μοντέλων ενσωματώνεται κατά την κατασκευή από μια τοπική στιγμή (snapshot) — χωρίς επικοινωνία με τον διακομιστή κατά την εκτέλεση.

## Εγκατάσταση

Λήψη ενός εκτελέσιμου αρχείου από τη [σελίδα εκδόσεων](https://github.com/TODO/rolandcode/releases), ή κατασκευή από τον κώδικα:

```bash
git clone https://github.com/TODO/rolandcode.git
cd rolandcode/packages/opencode

# Λήψη στιγμής καταλόγου μοντέλων
curl -fsSL -o models-api.json https://models.dev/api.json

# Κατασκευή
MODELS_DEV_API_JSON=./models-api.json bun run build --single
```

Το αρχείο εκτελέσιμου προγράμματος βρίσκεται στο `dist/opencode-linux-x64/bin/rolandcode` (ή το αντίστοιχο για την πλατφόρμα σας).

## Επαλήθευση

Κάθε κατασκευή μπορεί να επαληθευτεί ως καθαρή:

```bash
bash scripts/verify-clean.sh
```

Αυτό αναζητά (grep) σε όλο το δέντρο πηγαίου κώδικα για όλους τους γνωσμένους τομείς τηλεμετρίας και πακέτα SDK. Αν παραμείνει οποιαδήποτε αναφορά, η κατασκευή αποτυγχάνει. Το grep δεν ψεύδεται.

## Πώς λειτουργεί

Το Rolandcode διατηρεί ένα μικρό σύνολο διορθώσεων (patch set) πάνω από το upstream OpenCode. Κάθε commit αφαίρεσης (strip commit) αφαιρεί ένα θέμα τηλεμετρίας:

- `strip-posthog` — Αναλυτικά δεδομένα PostHog
- `strip-honeycomb` — Τηλεμετρία Honeycomb
- `strip-exa` — Προώθηση αναζήτησης mcp.exa.ai
- `strip-opencode-api` — Τομείς api.opencode.ai και opncd.ai
- `strip-zen-gateway` — Ρύθμιση διαύλου Zen
- `strip-app-proxy` — Αντικαταστάτης εφαρμογής app.opencode.ai (catch-all)
- `strip-share-sync` — Αυτόματη διαμοιρασμός συνεδριών
- `strip-models-dev` — Ανακτήσεις λιστών μοντέλων κατά την εκτέλεση

Μικρές, απομονωμένες αναθεωρήσεις επαναβάλλονται (rebase) καθαρά όταν το upstream κινείται.

## Δοκιμές

```bash
# Πλήρης σετ (εκτελεί δοκιμές δικαιωμάτων στο Docker όταν εκτελείται ως root)
bash scripts/test.sh

# Μόνο το κύριο σετ
cd packages/opencode && bun test --timeout 30000

# Μόνο οι δοκιμές δικαιωμάτων (πρέπει να μην είναι root, ή να χρησιμοποιείτε Docker)
docker run --rm -v $(pwd):/app:ro -w /app/packages/opencode -u 1000:1000 --tmpfs /tmp:exec oven/bun:1.3.10 \
  bun test test/tool/write.test.ts test/config/tui.test.ts --timeout 30000
```

### Γνωστά ζητήματα δοκιμών

| Δοκιμή | Κατάσταση | Λόγος |
|------|--------|-----|
| `session.llm.stream` (2 από 10) | Ασταθής (Flaky) | Η κατάσταση του διακομιστή HTTP προσομοίωσης διαρρέει μεταξύ παράλληλων δοκιμών. Περνάει 10/10 όταν εκτελείται απομονωμένα (`bun test test/session/llm.test.ts`). Ζήτημα απομόνωσης δοκιμών upstream — όχι ελάττωμα κώδικα. |
| `tool.write > πετάει σφάλμα όταν το OS αρνείται πρόσβαση εγγραφής` | Αποτυγχάνει ως root | Το root παρακάμπτει το `chmod 0o444`. Περνάει στο Docker ως μη-root. Το `scripts/test.sh` το χειρίζεται αυτόματα. |
| `tui config > συνεχίζει το φορτώμα όταν η πηγή legacy δεν μπορεί να αφαιρεθεί` | Αποτυγχάνει ως root | Ίδιο ζήτημα root-αντι-chmod. Περνάει στο Docker ως μη-root. |
| `fsmonitor` (2 δοκιμές) | Παραλείπονται | Μόνο για Windows (`process.platform === "win32"`). |
| `worktree-remove` (1 δοκιμή) | Παραλείπονται | Μόνο για Windows. |
| `τροποποίηση και αποκατάσταση ονομάτων αρχείων unicode` | Παραλείπονται | Το upstream το παραλείπει ρητά — γνωστό σφάλμα που δεν έχουν διορθώσει. |

## Αρχική Πηγή (Upstream)

Αυτό είναι ένα fork του [anomalyco/opencode](https://github.com/anomalyco/opencode) (άδεια MIT). Όλος ο αρχικός κώδικας είναι δικός τους. Η πλήρης ιστορία υποβολής (commit history) του upstream διατηρείται — μπορείτε να δείτε ακριβώς τι αλλάχθηκε και γιατί.

Το OpenCode είναι ένας ικανός πράκτορας AI κωδικοποίησης με εξαιρετική διασύνδεση γραμμής εντολών (TUI), υποστήριξη LSP και ευελιξία πολυπρόβλεψης. Το χρησιμοποιούμε επειδή είναι καλό λογισμικό. Αφαιρούμε την τηλεμετρία επειδή οι ισχυρισμοί ιδιωτικότητας δεν ταιριάζουν με τη συμπεριφορά.

## Άδεια

MIT — ίδια με το upstream. Δείτε το [LICENSE](LICENSE).
