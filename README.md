# PubMinder

An iOS app that monitors bioRxiv and medRxiv RSS feeds, filters new preprints by keyword, and uses the Groq API to generate concise AI summaries — so you can stay current with the literature without reading every abstract yourself.

## Features

- **Multi-feed support** — subscribe to any combination of bioRxiv and medRxiv subject categories
- **Keyword filtering** — only surfaces papers whose abstracts match your configured keywords
- **AI summaries** — sends each matching abstract to Groq (llama-3.3-70b-versatile) and returns a 2–3 sentence researcher-grade summary
- **Article cards** — each result shows the full title, DOI, tappable link, and Groq summary
- **Save for later** — bookmark articles to the Saved tab; they persist across app launches
- **Configurable settings** — manage subjects, keywords, and your Groq API key entirely within the app

## Requirements

- iOS 17+
- Xcode 15+
- A free [Groq API key](https://console.groq.com) (no credit card required)

## Setup

1. Clone the repository and open `PubMinder.xcodeproj` in Xcode.
2. Build and run on a simulator or device.
3. Open the **Settings** tab in the app and paste your Groq API key into the API Key field.
4. Select one or more subject categories and tap **Refresh Feed**.

## Usage

| Tab | Purpose |
|-----|---------|
| **Summary** | Fetched and summarized preprints appear here as scrollable cards |
| **Saved** | Articles you've bookmarked; tap the trash icon to remove |
| **Settings** | Configure subjects, keywords, and your Groq API key; trigger a manual refresh |

Keyword filtering is on by default. You can toggle it off or edit the keyword list in Settings. The defaults are tuned for genomics / bioinformatics research:

```
genomics, AI, phenotype, transcriptomics, genotype, bioinformatics,
gene, expression, regulation, craniofacial, size, color, coat
```

## Architecture

```
PubMinderApp          — app entry point, state ownership, feed orchestration
├── ContentView       — tab shell (Summary / Saved / Settings)
├── SummaryPage       — article card list with progressive loading indicator
├── FeatuePage        — saved articles list with remove action
├── SettingsPage      — subject picker, keyword editor, API key input, refresh
└── fetchData.swift   — RSS fetch (FeedKit), keyword filter, Groq summarization
```

Data flow:
1. `loadSummaries()` in `PubMinderApp` builds feed URLs from selected subjects.
2. `fetchAndSummarizeRSSFeed` parses each RSS feed with FeedKit, filters items by keyword, then calls Groq for each matching abstract.
3. Completed `Article` values (title, DOI, link, summary) are appended to `@State var summaries` and rendered immediately — cards appear one at a time as Groq responds.
4. Saved articles are JSON-encoded into `@AppStorage` and survive app restarts.

## Dependencies

| Package | Purpose |
|---------|---------|
| [FeedKit](https://github.com/nmdias/FeedKit) | RSS/Atom feed parsing |
| [swift-collections](https://github.com/apple/swift-collections) | Ordered collections |
| [swift-nio](https://github.com/apple/swift-nio) | Async networking primitives |
| [swift-system](https://github.com/apple/swift-system) | System call wrappers |

## API key note

The Groq API key is stored in `UserDefaults` on-device and is never transmitted anywhere other than `api.groq.com`. For a personal/research app this is fine. If you ever distribute the app publicly, move the key to a server-side proxy so it is not recoverable from the binary.
