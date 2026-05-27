# PubMinder — Developer Log

A running record of what was built, decisions made, problems hit, and why things are the way they are. Written for future-me (or anyone picking this up cold).

---

## Session 1 — Initial build + Phase 1 attempt (2026-05-25)

### What we started with

A working prototype that fetched bioRxiv and medRxiv RSS feeds with FeedKit, filtered abstracts by keyword, and called Groq to summarize matching articles. Single-file architecture, no source badges, no saved articles.

### Phase 1 — Server-side Groq proxy (attempted, then reverted)

**The plan:** deploy a Cloudflare Worker that holds the Groq key server-side. The iOS app would POST to the worker instead of calling Groq directly — no API key visible in the binary.

**What was built:** `proxy/worker.js` and `proxy/wrangler.toml` were created. `fetchData.swift`, `SettingsPage.swift`, and `PubMinderApp.swift` were updated to point at the worker URL and remove the key input UI.

**Why it was reverted:** during review, the goal became clear — this is a personal/research app, not a public product. Each user should bring their own Groq key; there's no shared server to run. The proxy model would require paying for infra and would route everyone's requests through a single key. Fully reverted all three Swift files. The `proxy/` folder could not be deleted from the sandbox but doesn't affect the iOS build (Xcode ignores `.js` and `.toml`).

**Decision logged:** Model A (bring-your-own-key) was chosen over Model B (shared proxy). If the app ever goes public on the App Store, reconsider the proxy approach.

---

### Phase 2 — arXiv integration

**Feed format difference:** bioRxiv and medRxiv return RSS feeds; arXiv returns Atom. FeedKit handles both, but they have different field names. Added a branch in `fetchAndSummarizeRSSFeed` that checks `feed.rssFeed` vs `feed.atomFeed` and reads from the appropriate structure.

**arXiv ID handling:** arXiv abstract URLs look like `http://arxiv.org/abs/2301.12345v1`. Added `extractArxivID(from:)` to strip the version suffix and return the bare ID. Stored in the `doi` field of `Article` (reused for display, even though it's technically not a DOI — labeled "arXiv ID" in the UI).

**`Article` struct migration:** added `source: String` field. This broke `Codable` compatibility with existing saved articles (which had no `source` key). Solved with a custom `init(from decoder:)` that uses `try?` for the source key and defaults to `""`. Also added an explicit memberwise `init` with `source: String = ""` so all existing call sites compiled without changes.

**11 arXiv subjects added:** cs.AI, cs.LG, cs.CV, cs.CL, cs.NE, math, cond-mat, hep-ph, quant-ph, stat.ML, q-bio.

---

### Phase 3 — UI polish

Changes in `SummaryPage.swift`:

- **Source badges:** small colored capsule below each article title. Color map: bioRxiv → green, medRxiv → orange, arXiv → teal, PubMed → blue. Two module-level functions `sourceDisplayName(_:)` and `sourceBadgeColor(_:)` are non-private so `fetchData.swift` can call `sourceDisplayName` inside `friendlyNetworkError`.
- **Source filter chips:** horizontal `ScrollView` of tappable chips at the top of the feed. Only shown when 2+ sources are present. State held in `@State private var sourceFilter: String`. Chips filter `summaries` client-side — no new network calls.
- **"Read Paper →" button:** replaced raw URL text with a styled `Link` button. arXiv Atom entries can contain unencoded characters in URLs; added a `addingPercentEncoding` fallback in `Article.articleURL`.
- **Pull-to-refresh:** `.refreshable { onRefresh() }` on the `ScrollView`.

**Settings:** added `.searchable(text: $subjectSearch, prompt: "Search subjects…")` to the List. All three subject arrays are passed through `filtered(_:)` before rendering.

---

### Phase 4 — PubMed integration

**Why it's different from RSS:** PubMed has no subject-category RSS. The only way to get articles is the NCBI E-utilities API — a two-step REST flow.

**Two-step flow:**
1. `esearch.fcgi` — POST keyword query, get back a JSON list of PMIDs (sorted by date).
2. `efetch.fcgi` — POST those PMIDs, get back PubMed XML with full records.

**XML parsing:** created `PubMedParser.swift` with a `PubMedXMLParser: NSObject, XMLParserDelegate`. Key design decision: used boolean collecting flags (`collectingTitle`, `collectingAbstract`, etc.) rather than tracking `currentElement` as a string. The reason: PubMed abstracts frequently contain inline formatting tags (`<i>`, `<sub>`, `<sup>`) nested inside `<AbstractText>`. If you track by element name, entering `<i>` sets `currentElement = "i"` and you lose the outer context. With boolean flags, nested elements are transparent — you just keep appending characters.

**Structured abstracts:** some PubMed records have multiple `<AbstractText>` sections with `Label` attributes (BACKGROUND, METHODS, RESULTS, CONCLUSIONS). The parser concatenates them with a space separator. Works correctly as input to the summarization prompt.

**PMID deduplication:** `<PMID>` appears twice in some records — once in `<MedlineCitation>` and again inside `<ArticleIdList>`. Added a `seenFirstPMID` flag to capture only the first occurrence.

**Settings integration:** added a "PubMed Searches" section to `SettingsPage` with a `TextField` + add button. Searches stored as `[String]` JSON in `UserDefaults` under `"pubmedSearchesRaw"`. Optional NCBI API key field in a `DisclosureGroup` (raises rate limit from 3 → 10 req/sec).

**App orchestration:** `PubMinderApp.loadSummaries()` changed `TaskGroup` type from `[Article].self` to `FetchOutcome.self` to carry both articles and error messages. Both RSS and PubMed tasks run in the same group — fully parallel.

---

### Error handling + onboarding

**Error surface:** added `FetchOutcome` struct wrapping `articles: [Article]` and `errorMessage: String?`. Both `fetchAndSummarizeRSSFeed` and `fetchAndSummarizePubMed` return `FetchOutcome`. Added `friendlyNetworkError(_ error: Error, source: String)` that maps `URLError` codes to human-readable strings (no internet / timed out / server unreachable / generic).

**Error UI:** dismissible orange banners at the top of the Summary tab. Errors are deduplicated (same message only shown once). `dismissedErrors: Set<String>` in `SummaryPage` state; cleared at the start of each refresh cycle.

**Onboarding:** created `OnboardingView.swift` with a three-page `TabView(.page)` flow:
- Page 1 — Welcome: app icon, tagline, three `FeatureRow` items.
- Page 2 — AI setup: Groq key input with show/hide toggle, step-by-step instructions, link to console.groq.com. "Continue without key" path for users who will rely on Apple Intelligence.
- Page 3 — Subject picker: three preset cards (Life Sciences / Medicine & Health / AI & Computing) using multi-select. Tapping "Explore PubMinder →" applies the preset and triggers the first load.

Stored in `@AppStorage("hasSeenOnboarding"): Bool`. The sheet uses `interactiveDismissDisabled(true)` — the user must complete or explicitly skip onboarding. After completion, auto-load fires only if a key is present.

---

## Session 2 — Apple Intelligence detection + PubMed filters (2026-05-25)

### Apple Intelligence adaptive onboarding

**The insight:** `summarizeText()` already tries `summarizeWithAppleAI()` first. But the onboarding always asked for a Groq key — even on devices that don't need one. Users on Apple Intelligence-capable hardware were being asked to do unnecessary setup.

**Solution:** split `GroqKeyPage` into a router + two sub-pages. The router uses `if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available` to branch at runtime:

- `AppleAIReadyPage` — green checkmark, "You're all set!", Groq key hidden behind a collapsible "Add a Groq key (optional)" section for power users. The disclosure explains Groq is a cloud fallback, not required.
- `GroqKeySetupPage` — original step-by-step key entry flow, unchanged.

`FoundationModels` is guarded with `#if canImport(FoundationModels)` / `#else` so the file compiles against iOS 17 SDKs.

---

### PubMed per-search filters

**Motivation:** PubMed's database is enormous. Without a date constraint, a query like "machine learning" surfaces papers from 2003 alongside 2025. Without an article type filter, a user trying to read recent reviews gets mixed in with case reports and editorials.

**Model added (in `fetchData.swift`):**

```swift
enum PubMedDateRange   // Last 7d / 30d / 90d (default) / 1y / All time
enum PubMedArticleType // All / Research articles / Reviews
struct PubMedSearch    // Codable: id, query, dateRange, articleType
```

**How filters wire into the API:**
- Date range → `reldate=N&datetype=pdat` added to esearch query items. `allTime` omits these params entirely.
- Article type → appended to the search term: `AND Journal Article[pt]` or `AND (Review[pt] OR Systematic Review[pt])`. Appending to the query string is the official NCBI approach — it's additive and doesn't affect result ranking.

**Storage migration:** PubMed searches previously stored as `[String]` under `"pubmedSearchesRaw"`. New format is `[PubMedSearch]` under `"pubmedSearchesV2"`. Both `SettingsPage` and `PubMinderApp` read V2 first; if empty, fall back to legacy and wrap each string in a default `PubMedSearch`. Migration writes to V2 on first read — transparent to the user.

**Settings UI:** each saved search is rendered by `PubMedSearchRow` — the query text on top, two compact `Menu` pickers below. Blue calendar chip for date range, purple document chip for article type. Pickers write back immediately via a per-index `Binding` generated by `bindingFor(index:)`.

**Bug fixed during verification:** two `guard let ... else { return [] }` lines in `fetchAndSummarizePubMed` had the wrong return type (`[Article]` instead of `FetchOutcome`). Fixed to `return FetchOutcome()`.

---

## Architecture at end of Session 2

```
fetchData.swift
├── Article (Codable, source-aware, backward-compatible decoder)
├── FetchOutcome (articles + errorMessage)
├── PubMedDateRange / PubMedArticleType / PubMedSearch (Codable filter model)
├── fetchAndSummarizeRSSFeed(feedURL:source:) → FetchOutcome
│     RSS path:  FeedKit rssFeed → keyword filter → parallel TaskGroup summarize
│     Atom path: FeedKit atomFeed → keyword filter → parallel TaskGroup summarize
├── fetchAndSummarizePubMed(_ search: PubMedSearch) → FetchOutcome
│     esearch (query + date + type filters) → PMIDs
│     efetch → PubMed XML → PubMedXMLParser
│     keyword filter → parallel TaskGroup summarize
└── summarizeText() → summarizeWithAppleAI() → summarizeWithGroq()

PubMedParser.swift
└── PubMedXMLParser: XMLParserDelegate
      boolean collecting flags (robust to nested inline tags)
      structured abstract concatenation

OnboardingView.swift
└── GroqKeyPage (router) → AppleAIReadyPage | GroqKeySetupPage

SettingsPage.swift
└── PubMedSearchRow (per-search Binding with date + type menus)
```

---

## Known issues / future work

- **SSRN** — planned in the roadmap but not yet started. Elsevier's API situation is messy; see ROADMAP.md for details.
- **`FeatuePage.swift` typo** — the file is named "Featu**e**Page" (missing 'r'). Left as-is to avoid breaking the Xcode project reference.
- **`ListOfThings.swift`** — old prototype file. Not connected to the current app. Left in the target to avoid disturbing the project file; can be deleted once the project structure is cleaned up.
- **`proxy/`** — Cloudflare Worker from the reverted Phase 1. Cannot be deleted from the sandbox. Has no effect on the iOS build.
- **Pull-to-refresh dismisses errors** — refreshing clears `dismissedErrors`, so previously dismissed banners reappear if the same error recurs. This is intentional (the user should know if the same source keeps failing) but could be annoying if a source is persistently down.
- **arXiv "Read Paper" URLs** — some arXiv Atom entries emit unencoded characters (spaces, brackets) in `<link href>`. Handled with a `addingPercentEncoding` fallback in `Article.articleURL`, but worth monitoring if new edge cases appear.

---

## Session 3 — App Store preparation (2026-05-26)

### Keychain migration for API keys

**Problem:** The Groq API key and NCBI API key were stored in `UserDefaults` as plain strings. UserDefaults data can be included in iCloud backups and is not encrypted at rest — inappropriate for credentials.

**Solution:** Created `KeychainHelper.swift` — a lightweight static wrapper around the iOS Security framework. It provides `save(_:forKey:)`, `load(forKey:)`, `delete(forKey:)`, and a one-shot `migrateFromUserDefaults(userDefaultsKey:keychainKey:)` helper.

Keys are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — encrypted, device-bound, and excluded from backups.

**Files changed:**
- `KeychainHelper.swift` — NEW
- `fetchData.swift` — `groqAPIKey` global now reads from Keychain via `KeychainHelper.load(forKey:)`
- `SettingsPage.swift` — `@AppStorage("groqAPIKey")` and `@AppStorage("pubmedAPIKey")` replaced with `@State` + `.onAppear { Keychain load + migrate }` + `.onChange { Keychain save }`
- `OnboardingView.swift` — `@AppStorage("groqAPIKey")` replaced with same pattern

Migration is transparent: on first launch after the update, any existing UserDefaults key is moved to Keychain and deleted from UserDefaults automatically.

---

### Privacy manifest

**Problem:** Apple has required a `PrivacyInfo.xcprivacy` file for all App Store submissions since May 2024. Without it, apps using "required reason APIs" (including `UserDefaults`) get flagged.

**Solution:** Created `PubMinder/PrivacyInfo.xcprivacy` declaring:
- `NSPrivacyTracking: false` — PubMinder does not track users
- `NSPrivacyCollectedDataTypes: []` — no personal data collected
- `NSPrivacyAccessedAPITypes` — `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92LXYZ` (app's own defaults, not for tracking)

**Required action:** The file must be added to the Xcode target manually (File → Add Files, tick the PubMinder target checkbox). See `AppStoreChecklist.md` Step 1.

---

### Supporting documents created

- `PrivacyPolicy.md` — full privacy policy text ready to host publicly. App Store Connect requires a live URL.
- `AppStoreChecklist.md` — step-by-step guide covering everything needed: adding new files to the Xcode target, archiving, App Store Connect listing, screenshots, privacy questionnaire, and submission.

---

### Architecture at end of Session 3

No structural changes — same tab/view architecture as Session 2. The only runtime-visible change is that API keys survive device restores differently (Keychain is not in iCloud backup; keys will need to be re-entered after a restore-from-backup, which is the correct security behaviour for credentials).
