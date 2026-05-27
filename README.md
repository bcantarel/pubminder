# PubMinder

An iOS app that monitors scientific preprint and journal feeds, filters articles by keyword, and uses AI to generate concise summaries — so you can stay current with the literature without reading every abstract yourself.

Supports **bioRxiv**, **medRxiv**, **arXiv**, and **PubMed**. Summarization runs on-device via Apple Intelligence (iOS 26+, eligible hardware) or via the free [Groq API](https://console.groq.com) as a fallback.

---

## Features

- **Four sources** — subscribe to any combination of bioRxiv (27 subjects), medRxiv (50 subjects), arXiv (11 subjects), and PubMed keyword searches
- **Apple Intelligence** — on-device summarization on iOS 26+ with A17 Pro / A18 / M-series chips; no API key needed on eligible devices
- **Groq fallback** — cloud summarization via llama-3.3-70b-versatile for older devices; free, no credit card required
- **PubMed filters** — per-search date range (last 7 days → all time) and article type (all / research articles / reviews) configured directly in Settings
- **Keyword filtering** — only surfaces articles whose title or abstract matches your configured keywords
- **Source filter chips** — in the Summary tab, filter the feed by source with a single tap
- **Error banners** — network and API errors appear inline, per-source, and are individually dismissible
- **Pull-to-refresh** — swipe down in the Summary tab to reload all feeds
- **Article cards** — each result shows the title, source badge, DOI/arXiv ID, a tappable "Read Paper →" button, and the AI summary
- **Save for later** — bookmark articles to the Saved tab; they persist across app launches
- **Guided onboarding** — first-launch flow sets up your AI backend and subject preferences in three steps

---

## Requirements

- **iOS 17+** (runs on any modern iPhone; Groq key required for summarization)
- **iOS 26+ with Apple Intelligence** (on-device summarization, no API key needed)
- Xcode 16+
- A free [Groq API key](https://console.groq.com) — only required if Apple Intelligence is unavailable on your device

---

## Setup

1. Clone the repository and open `PubMinder.xcodeproj` in Xcode.
2. Build and run on a simulator or device (iOS 17+).
3. Complete the three-step onboarding that appears on first launch:
   - **Step 1** — Welcome screen
   - **Step 2** — AI setup: the app detects whether Apple Intelligence is available. If it is, you're done. If not, paste your free Groq API key.
   - **Step 3** — Pick a subject preset (Life Sciences, Medicine & Health, or AI & Computing) to seed your initial feed.
4. Tap **Explore PubMinder** — the first fetch begins automatically.

You can change subjects, keywords, and API keys at any time in the **Settings** tab.

---

## Usage

| Tab | Purpose |
|-----|---------|
| **Summary** | Fetched and summarized articles appear here as scrollable cards. Use the source chips to filter by bioRxiv, medRxiv, arXiv, or PubMed. Pull down to refresh. |
| **Saved** | Articles you've bookmarked. Tap the trash icon to remove. |
| **Settings** | Configure subjects, PubMed searches, keyword filter, feed size, and API keys. Tap **Refresh Feed** to reload. |

### PubMed searches

Add keyword queries or MeSH terms in the **PubMed Searches** section of Settings. Each saved search has two filter menus underneath it:

- **Date range** — Last 7 days / Last 30 days / Last 90 days (default) / Last year / All time
- **Article type** — All types (default) / Research articles / Reviews

Changes to these filters take effect on the next refresh.

### Keyword filter

Keyword filtering is on by default and applies to bioRxiv, medRxiv, and arXiv feeds (PubMed results are already scoped by your search query). Only articles whose title or abstract contains at least one keyword are fetched and summarized. You can toggle the filter off, edit the list, or reset to defaults in Settings.

Default keywords: `genomics, AI, transcriptomics, bioinformatics, gene, expression, regulation`

---

## Architecture

```
PubMinderApp          — app entry point, state ownership, feed orchestration
├── ContentView       — tab shell (Summary / Saved / Settings)
├── SummaryPage       — article feed: source filter chips, error banners, pull-to-refresh
│   ├── ArticleCard   — individual paper card (title, source badge, DOI, link, summary)
│   └── FilterChip    — source filter chip component
├── FeatuePage        — saved articles list with remove action
├── SettingsPage      — subject picker, PubMed searches, keyword editor, API key, refresh
│   ├── FeedSubject   — source / slug / displayName / feedURL model
│   └── PubMedSearchRow — per-search row with date + article-type Menu pickers
├── OnboardingView    — 3-page first-launch sheet (Welcome → AI setup → Subject picker)
└── fetchData.swift   — data layer: fetch, filter, summarize
    ├── Article               — Codable model (title, doi, link, summary, source)
    ├── FetchOutcome          — (articles, errorMessage?) result wrapper
    ├── PubMedSearch          — Codable search config (query, dateRange, articleType)
    ├── fetchAndSummarizeRSSFeed()   — FeedKit RSS+Atom fetch with parallel TaskGroup summarization
    ├── fetchAndSummarizePubMed()    — NCBI esearch → efetch → XML parse → summarize
    ├── summarizeText()              — router: Apple Intelligence → Groq
    ├── summarizeWithAppleAI()       — FoundationModels, iOS 26+
    └── summarizeWithGroq()          — Groq API, llama-3.3-70b-versatile

PubMedParser.swift    — XMLParserDelegate for NCBI efetch PubMed XML
```

### Data flow

1. `loadSummaries()` in `PubMinderApp` fires a `TaskGroup` with one task per selected subject feed and one per PubMed search — all run in parallel.
2. Each feed task returns a `FetchOutcome` containing successfully parsed articles and an optional error message.
3. For RSS/Atom feeds: FeedKit parses the feed, the keyword filter runs, matching articles are summarized concurrently in a nested `TaskGroup`.
4. For PubMed: `esearch` resolves the query + filters to PMIDs; `efetch` retrieves PubMed XML; `PubMedXMLParser` extracts title, abstract, DOI, and PMID; keyword filter runs; matching records are summarized concurrently.
5. Summarization tries Apple Intelligence first (`FoundationModels`, iOS 26+); falls back to Groq if unavailable or the device is not eligible.
6. Completed `Article` values are appended to `@State var summaries` on the main actor and rendered immediately — cards appear as each fetch completes.
7. Errors are collected into `@State var fetchErrors` and displayed as dismissible banners at the top of the Summary tab.
8. Saved articles are JSON-encoded into `@AppStorage` and survive app restarts.

---

## Dependencies

| Package | Purpose |
|---------|---------|
| [FeedKit](https://github.com/nmdias/FeedKit) | RSS (bioRxiv / medRxiv) and Atom (arXiv) feed parsing |
| NCBI E-utilities | PubMed article search and fetch (no package — plain URLSession) |
| FoundationModels *(iOS 26+)* | On-device Apple Intelligence summarization |
| Groq API | Cloud summarization fallback (llama-3.3-70b-versatile) |

---

## Security note

The Groq API key is stored in `UserDefaults` on-device and is only ever sent to `api.groq.com`. It is never logged or transmitted elsewhere. For a personal research app this is fine. If you distribute publicly, consider moving the key to a server-side proxy so it cannot be recovered from the binary.

The NCBI API key (optional) is stored and used the same way — only sent to `eutils.ncbi.nlm.nih.gov`.
