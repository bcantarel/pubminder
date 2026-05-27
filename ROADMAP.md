# PubMinder Improvement Roadmap

Captured 2026-05-25 based on user feedback from a tester. Five items requested:
1. Server-side Groq proxy
2. UI polish
3. arXiv support (physics, CS, math)
4. PubMed support (indexed journals)
5. SSRN support (social sciences)

---

## Recommended Implementation Order

| Phase | Item | Effort | Blocks |
|-------|------|--------|--------|
| 1 | Server-side Groq proxy | Low–Medium | Public distribution |
| 2 | arXiv integration | Low | — |
| 3 | UI polish (source badges, link cleanup) | Low | Best done alongside Phase 2 |
| 4 | PubMed integration | Medium | — |
| 5 | Settings search + filter chips | Low | Needed once sources > 3 |
| 6 | SSRN integration | High | — |

---

## Phase 1 — Server-Side Groq Proxy

**Why first:** shipping a public binary with a recoverable API key in `UserDefaults` is a security issue. This unblocks wider distribution.

**Platform:** Cloudflare Workers (free tier, 100k req/day, no credit card, no cold-start latency).

**How it works:**
- The Worker is ~20 lines of JS. It accepts `POST { "text": "abstract" }`, attaches the Groq key server-side, calls `api.groq.com/openai/v1/chat/completions`, and returns the response.
- The iOS app changes one URL constant in `fetchData.swift` — `api.groq.com/...` → `your-worker.workers.dev/summarize`.
- Remove the Groq API key field from `SettingsPage` entirely. End users never see or manage a key.

**Files to change:**
- `fetchData.swift` — update `summarizeWithGroq()` endpoint URL; remove `groqAPIKey` read from `UserDefaults`
- `SettingsPage.swift` — remove the API Key section and `@AppStorage("groqAPIKey")`
- New file: `proxy/worker.js` (deploy separately to Cloudflare)

**Open design question:** keep an "advanced" mode so power users can supply their own Groq key? Recommend removing it by default and re-adding only if users request it.

---

## Phase 2 — arXiv Integration

**Why second:** arXiv uses Atom feeds that FeedKit already handles — least code of the three new sources.

**Feed URLs:** `https://arxiv.org/rss/cs.AI`, `https://arxiv.org/rss/math`, `https://arxiv.org/rss/physics`, etc. ~150 subcategories total; ship a curated subset first.

**Suggested initial categories:**

| Category | Feed slug |
|----------|-----------|
| CS — AI | cs.AI |
| CS — Machine Learning | cs.LG |
| CS — Computer Vision | cs.CV |
| CS — Computation & Language | cs.CL |
| CS — Neural & Evolutionary Computing | cs.NE |
| Mathematics | math |
| Physics — Condensed Matter | cond-mat |
| Physics — High Energy | hep-ph |
| Physics — Quantum Physics | quant-ph |
| Statistics — ML | stat.ML |
| Quantitative Biology | q-bio |

**Files to change:**
- `SettingsPage.swift` — add `source: "arxiv"` case to `FeedSubject.feedURL`; add arXiv subject list
- `fetchData.swift` — `fetchAndSummarizeRSSFeed` needs to handle the Atom feed case: check for `.atom` vs `.rss` in the FeedKit result and read `atomFeed.entries` instead of `rssFeed.items`. Field mapping:
  - Title: `entry.title?.value`
  - Abstract: `entry.summary?.value`
  - Link: `entry.links?.first?.attributes?.href`
  - ID: `entry.id` (format: `http://arxiv.org/abs/2301.12345v1`)
- `fetchData.swift` — add `extractArxivID(from:)` alongside `extractDOI(from:)` since arXiv IDs are not DOIs
- `Article` struct — add `source: String` field (needed for UI badges in Phase 3)

---

## Phase 3 — UI Polish

Best done alongside Phase 2 since `Article` already needs a `source` field.

### Source badges on ArticleCard
- Add `source: String` to `Article` struct (values: `"bioRxiv"`, `"medRxiv"`, `"arXiv"`, `"PubMed"`, `"SSRN"`)
- Propagate `source` through `fetchAndSummarizeRSSFeed` → `Article` init
- In `ArticleCard`, render a small colored chip below the title:

| Source | Color |
|--------|-------|
| bioRxiv | green |
| medRxiv | orange |
| arXiv | teal |
| PubMed | blue |
| SSRN | purple |

### Cleaner link display
- Replace the raw URL `Text`/`Link` in `ArticleCard` with a styled `"Read Paper →"` button
- File: `SummaryPage.swift` — update `ArticleCard.body`

### Pull-to-refresh
- Add `.refreshable { onRefresh() }` to the `ScrollView` in `SummaryPage`
- File: `SummaryPage.swift`

### Subject list search
- Add `.searchable(text: $subjectSearch)` to the `List` in `SettingsPage`
- Filter `bioRxivSubjects` and `medRxivSubjects` (and later arXiv/PubMed) against the search string
- File: `SettingsPage.swift`

### Source filter chips in Summary tab
- Once 3+ sources exist, add a horizontal `ScrollView` of filter chips at the top of `SummaryPage`
- Options: All · bioRxiv · medRxiv · arXiv · PubMed
- Filter `summaries` array client-side; no new network calls needed
- File: `SummaryPage.swift`

---

## Phase 4 — PubMed Integration

**Why medium effort:** PubMed has no subject-category RSS feeds. It uses the **NCBI E-utilities API** — a two-step REST flow, custom XML parsing, and a different UX paradigm.

### API flow
1. **esearch** — find PMIDs matching a query:
   ```
   GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi
       ?db=pubmed&term=QUERY&retmax=N&retmode=json&api_key=KEY
   ```
2. **efetch** — retrieve full records for those PMIDs:
   ```
   GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi
       ?db=pubmed&id=PMID1,PMID2,...&rettype=abstract&retmode=xml&api_key=KEY
   ```

**Rate limits:** 3 req/sec unauthenticated, 10 req/sec with a free API key. Register at [ncbi.nlm.nih.gov/account](https://www.ncbi.nlm.nih.gov/account/) — 2 minutes.

**XML parsing:** The efetch response is PubMed XML. Key fields:
- `<ArticleTitle>` → title
- `<AbstractText>` → abstract (may have multiple sections with `Label` attributes)
- `<PMID>` → use to construct link `https://pubmed.ncbi.nlm.nih.gov/PMID/`
- `<ArticleId IdType="doi">` → DOI

### UX design
PubMed is search-driven, not subject-driven. Recommend a dedicated "PubMed Searches" section in `SettingsPage` with a text field where users enter MeSH terms or keyword queries (e.g. `genomics[MeSH] AND humans[MeSH]`). These are saved as an array, similar to how keywords are saved now.

### Files to change
- `fetchData.swift` — new function `fetchAndSummarizePubMed(query:) async -> [Article]`
- `SettingsPage.swift` — new section for PubMed search terms
- `PubMinderApp.swift` — orchestrate PubMed fetches alongside RSS fetches in `loadSummaries()`
- New file: `PubMedParser.swift` — `XMLParserDelegate` implementation for efetch XML

---

## Phase 5 — Settings Search + Filter Chips

Covered in Phase 3 above. Pulling it out as a named phase as a reminder that by the time Phases 2–4 are complete, the subject list will be long enough that the search field becomes essential rather than optional.

---

## Phase 6 — SSRN Integration

**Status: Experimental / Last Priority**

SSRN has no stable public API (acquired by Elsevier in 2016, no developer program). The closest usable entry point is per-topic RSS at:
```
https://papers.ssrn.com/sol3/topten.cfm?subjectmatterid=X&rss=1
```
The `subjectmatterid` values are undocumented numeric codes that must be catalogued manually from the SSRN website. The feeds surface top-10 papers by download count, not a stream of recent submissions.

**Risks:**
- Elsevier may change or block the feed URL without notice
- Content is top-10 by popularity, not chronological — less useful for staying current
- No abstract field in some feeds — summarization may fall back to title-only

**Recommendation:** implement last, label as "Experimental" in the UI, and accept that it may require periodic maintenance. If SSRN launches a proper developer API in future, rebuild the integration cleanly at that point.

**Files to change (when ready):**
- `SettingsPage.swift` — add SSRN subject list with hardcoded `subjectmatterid` values
- `fetchData.swift` — SSRN feeds are standard RSS, so FeedKit should handle them; may need fallback for missing abstracts

---

## Current Architecture Reference

```
PubMinderApp          — app entry point, state ownership, feed orchestration
├── ContentView       — tab shell (Summary / Saved / Settings)
├── SummaryPage       — article card list with progressive loading
│   └── ArticleCard   — individual paper card (title, DOI, link, summary)
├── FeatuePage        — saved articles list with remove action
├── SettingsPage      — subject picker, keyword editor, API key, refresh
│   └── FeedSubject   — source/slug/displayName/feedURL model
└── fetchData.swift   — RSS fetch (FeedKit), keyword filter, Groq summarization
    ├── summarizeWithAppleAI()       — on-device, iOS 26+
    ├── summarizeWithGroq()          — cloud fallback
    ├── summarizeText()              — router: Apple AI → Groq
    └── fetchAndSummarizeRSSFeed()   — fetch + parallel TaskGroup summarization
```

## Dependencies

| Package | Purpose |
|---------|---------|
| FeedKit | RSS + Atom feed parsing |
| swift-collections | Ordered collections |
| swift-nio | Async networking primitives |
| swift-system | System call wrappers |
| Cloudflare Workers *(Phase 1)* | Server-side Groq proxy |
| NCBI E-utilities *(Phase 4)* | PubMed search + fetch |
