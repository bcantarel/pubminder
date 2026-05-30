import Foundation
import FeedKit
import SwiftUI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// Structured article type — title/doi/link come straight from the feed,
// summary is the only field that Groq (or Apple AI) touches.
struct Article: Identifiable, Codable, Hashable {
    let title:   String
    let doi:     String   // DOI for bioRxiv/medRxiv; arXiv ID for arXiv; empty when not parseable
    let link:    String
    let summary: String
    let source:  String   // "biorxiv", "medrxiv", or "arxiv"; empty for legacy saved articles

    // Stable identity: prefer DOI/ID, fall back to link
    var id: String { doi.isEmpty ? link : doi }

    // URL with a percent-encoding fallback for feeds that emit unencoded characters
    var articleURL: URL? {
        if let url = URL(string: link) { return url }
        let encoded = link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? link
        return URL(string: encoded)
    }

    // Memberwise init — source defaults to empty so existing call sites don't need updating
    init(title: String, doi: String, link: String, summary: String, source: String = "") {
        self.title = title; self.doi = doi; self.link = link
        self.summary = summary; self.source = source
    }

    // Custom Codable decode: handles saved articles that pre-date the source field
    enum CodingKeys: String, CodingKey { case title, doi, link, summary, source }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title   = try c.decode(String.self, forKey: .title)
        doi     = try c.decode(String.self, forKey: .doi)
        link    = try c.decode(String.self, forKey: .link)
        summary = try c.decode(String.self, forKey: .summary)
        source  = (try? c.decode(String.self, forKey: .source)) ?? ""
    }
}

// Reads the Groq API key from the Keychain (stored there by SettingsPage / OnboardingView).
// Returns an empty string if not set, which will cause summarizeText to fail gracefully.
var groqAPIKey: String {
    KeychainHelper.load(forKey: "groqAPIKey") ?? ""
}

// Default keywords used on first launch before the user configures their own.
let defaultKeywords = [
    "genomics", "AI", "transcriptomics",
    "bioinformatics", "gene", "expression", "regulation"
]

// Returns true if the article abstract passes the keyword filter.
// Reads filter settings from UserDefaults so the user can configure them in Settings.
func searchKeywords(in text: String) -> Bool {
    let filterEnabled = UserDefaults.standard.object(forKey: "filterKeywordsEnabled") as? Bool ?? true
    guard filterEnabled else { return true }

    let stored = UserDefaults.standard.string(forKey: "filterKeywordsRaw") ?? ""
    let keywords: [String]
    if stored.isEmpty {
        keywords = defaultKeywords
    } else {
        keywords = (try? JSONDecoder().decode([String].self, from: Data(stored.utf8))) ?? defaultKeywords
    }

    guard !keywords.isEmpty else { return true }
    return keywords.contains { text.lowercased().contains($0.lowercased()) }
}

// Extract a DOI from a bioRxiv/medRxiv URL.
// URL format: https://www.biorxiv.org/content/10.XXXX/YYYYv1?rss=1
func extractDOI(from link: String) -> String {
    guard let contentRange = link.range(of: "/content/") else { return "" }
    var doi = String(link[contentRange.upperBound...])
    if let qRange = doi.range(of: "?") { doi = String(doi[..<qRange.lowerBound]) }
    if let vMatch = doi.range(of: #"v\d+$"#, options: .regularExpression) {
        doi = String(doi[..<vMatch.lowerBound])
    }
    return doi
}

// Extract an arXiv ID from an arXiv abstract URL.
// URL format: http://arxiv.org/abs/2301.12345v1
func extractArxivID(from link: String) -> String {
    guard let absRange = link.range(of: "/abs/") else { return "" }
    var arxivID = String(link[absRange.upperBound...])
    // Strip version suffix (v1, v2, …)
    if let vMatch = arxivID.range(of: #"v\d+$"#, options: .regularExpression) {
        arxivID = String(arxivID[..<vMatch.lowerBound])
    }
    return arxivID
}

// The system prompt shared by both AI backends.
private let summarizationSystemPrompt = "You are a graduate research assistant. Summarize the following scientific abstract for your peers in 2–3 sentences. Be specific about the key finding."

// MARK: - Apple Intelligence (on-device, iOS 18+)

// Tries to summarize using the on-device Foundation Models framework.
// Returns nil if Apple Intelligence is unavailable or the device isn't eligible,
// so the caller can fall back to Groq.
@available(iOS 26.0, *)
func summarizeWithAppleAI(inputText: String) async -> String? {
    let model = SystemLanguageModel.default
    guard model.availability == .available else {
        switch model.availability {
        case .unavailable(.deviceNotEligible):
            print("Apple AI: device not eligible (requires A17 Pro / M1 or later).")
        case .unavailable(.appleIntelligenceNotEnabled):
            print("Apple AI: Apple Intelligence is off — enable it in Settings → Apple Intelligence.")
        case .unavailable(.modelNotReady):
            print("Apple AI: model is still downloading, will retry next time.")
        default:
            print("Apple AI: unavailable.")
        }
        return nil
    }

    let session = LanguageModelSession(instructions: summarizationSystemPrompt)
    do {
        let response = try await session.respond(to: inputText)
        print("Apple AI: summarized successfully (on-device).")
        return response.content
    } catch {
        print("Apple AI error: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Groq (cloud fallback)

// Summarize via the Groq API (llama-3.3-70b). Used when Apple Intelligence
// is unavailable or on older devices. Fully async — no callbacks.
func summarizeWithGroq(inputText: String) async -> String? {
    let key = groqAPIKey
    guard !key.isEmpty else {
        print("Groq API key not set. Enter your key in Settings.")
        return nil
    }
    guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return nil }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

    let payload: [String: Any] = [
        "model": "llama-3.3-70b-versatile",
        "temperature": 0,
        "messages": [
            ["role": "system", "content": summarizationSystemPrompt],
            ["role": "user", "content": inputText]
        ]
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
    request.httpBody = jsonData

    do {
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        print("Unexpected Groq response: \(String(data: data, encoding: .utf8) ?? "unreadable")")
        return nil
    } catch {
        print("Groq error: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Smart router: Apple AI first, Groq fallback

/// Returns true when at least one summarization backend will produce output.
/// Use this to gate the Refresh button and auto-load — avoids fetching articles
/// that would all come back "Summary unavailable."
func hasAISummarization() -> Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
        if SystemLanguageModel.default.availability == .available { return true }
    }
    #endif
    return !groqAPIKey.isEmpty
}

// Tries on-device Apple Intelligence first (iOS 26+, eligible hardware).
// Falls back to Groq automatically — no callbacks, just await and get the result.
// Returns nil immediately for free users — callers show an upgrade prompt instead.
func summarizeText(inputText: String, isPremium: Bool) async -> String? {
    guard isPremium else { return nil }
    if #available(iOS 26.0, *) {
        if let result = await summarizeWithAppleAI(inputText: inputText) {
            return result
        }
    }
    return await summarizeWithGroq(inputText: inputText)
}

// MARK: - Error surface

// Wraps the result of a single fetch task so errors can be shown in the UI
// alongside whatever articles were successfully loaded.
struct FetchOutcome {
    let articles: [Article]
    let errorMessage: String?

    init(articles: [Article] = [], errorMessage: String? = nil) {
        self.articles = articles
        self.errorMessage = errorMessage
    }
}

// Converts a URLError into a short, human-readable sentence.
private func friendlyNetworkError(_ error: Error, source: String) -> String {
    let label = sourceDisplayName(source)
    if let urlErr = error as? URLError {
        switch urlErr.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "No internet connection — couldn't load \(label)."
        case .timedOut:
            return "\(label) connection timed out. Try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "\(label) server is unreachable. Try again later."
        default:
            break
        }
    }
    return "Couldn't load \(label): \(error.localizedDescription)"
}

private struct FeedFetchError: Error { let message: String }

// MARK: - Feed fetch + parallel summarization

// Fetch one RSS or Atom feed and summarize all matching articles in parallel using TaskGroup.
// `source` is "biorxiv", "medrxiv", or "arxiv" — used to tag each Article and pick the
// right parser branch (bioRxiv/medRxiv return RSS; arXiv returns Atom).
func fetchAndSummarizeRSSFeed(feedURL: String, source: String = "biorxiv", isPremium: Bool = false) async -> FetchOutcome {
    guard let url = URL(string: feedURL) else {
        return FetchOutcome(errorMessage: "Invalid feed URL for \(source).")
    }
    let parser = FeedParser(URL: url)
    let articleLimit = max(1, UserDefaults.standard.integer(forKey: "articlesPerSubject") > 0
                          ? UserDefaults.standard.integer(forKey: "articlesPerSubject") : 3)

    typealias Candidate = (title: String, link: String, identifier: String, abstract: String)

    // FeedParser uses callbacks internally — bridge to async/await with a continuation.
    // The result is either a list of candidates or an error message (nil = parse ok but empty).
    let parseResult: Result<[Candidate], FeedFetchError> =
        await withCheckedContinuation { continuation in
            parser.parseAsync { result in
                switch result {
                case .success(let feed):
                    var found: [Candidate] = []

                    // ── RSS path: bioRxiv / medRxiv ──────────────────────────
                    if let rssFeed = feed.rssFeed {
                        for item in rssFeed.items ?? [] {
                            guard let abstract = item.description else { continue }
                            guard searchKeywords(in: abstract) else { continue }
                            // bioRxiv sometimes puts the article URL in <guid> not <link>
                            let link = (item.link ?? item.guid?.value ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            print("RSS item — title: \(item.title ?? "nil"), link: '\(link)'")
                            found.append((
                                title:      item.title ?? "Untitled",
                                link:       link,
                                identifier: extractDOI(from: link),
                                abstract:   abstract
                            ))
                            if found.count >= articleLimit { break }
                        }

                    // ── Atom path: arXiv ─────────────────────────────────────
                    } else if let atomFeed = feed.atomFeed {
                        for entry in atomFeed.entries ?? [] {
                            guard let abstract = entry.summary?.value, !abstract.isEmpty else { continue }
                            guard searchKeywords(in: abstract) else { continue }
                            let link  = entry.links?.first?.attributes?.href ?? ""
                            let title = entry.title ?? "Untitled"
                            // arXiv entry.id looks like "http://arxiv.org/abs/2301.12345v1"
                            let arxivID = extractArxivID(from: entry.id ?? link)
                            print("Atom entry — title: \(title), link: '\(link)'")
                            found.append((
                                title:      title,
                                link:       link,
                                identifier: arxivID,
                                abstract:   abstract
                            ))
                            if found.count >= articleLimit { break }
                        }
                    } else {
                        // FeedKit returned success but recognised neither RSS nor Atom
                        continuation.resume(returning: .failure(FeedFetchError(message: "Unrecognised feed format from \(sourceDisplayName(source)).")))
                        return
                    }

                    continuation.resume(returning: .success(found))

                case .failure(let error):
                    print("Feed parse error (\(source)): \(error.localizedDescription)")
                    continuation.resume(returning: .failure(FeedFetchError(message: friendlyNetworkError(error, source: source))))
                }
            }
        }

    switch parseResult {
    case .failure(let err):
        return FetchOutcome(errorMessage: err.message)
    case .success(let candidates):
        guard !candidates.isEmpty else { return FetchOutcome() }

        // Summarize every candidate concurrently — no race conditions, no manual counters.
        let articles = await withTaskGroup(of: Article.self) { group in
            for candidate in candidates {
                group.addTask {
                    let summary = await summarizeText(inputText: candidate.abstract, isPremium: isPremium)
                    return Article(
                        title:   candidate.title,
                        doi:     candidate.identifier,
                        link:    candidate.link,
                        summary: summary ?? (isPremium ? "Summary unavailable." : "Upgrade to Pro for AI summaries."),
                        source:  source
                    )
                }
            }
            var results: [Article] = []
            for await article in group { results.append(article) }
            return results
        }
        return FetchOutcome(articles: articles)
    }
}

// MARK: - PubMed filter model

/// How far back to search in PubMed. Maps directly to NCBI's `reldate` parameter.
enum PubMedDateRange: String, Codable, CaseIterable, Identifiable {
    case week        = "7"
    case month       = "30"
    case threeMonths = "90"
    case year        = "365"
    case allTime     = "0"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:        return "Last 7 days"
        case .month:       return "Last 30 days"
        case .threeMonths: return "Last 90 days"
        case .year:        return "Last year"
        case .allTime:     return "All time"
        }
    }

    /// Returns the reldate integer, or nil when no date restriction should be applied.
    var reldate: Int? { rawValue == "0" ? nil : Int(rawValue) }
}

/// Which publication type to request from PubMed.
enum PubMedArticleType: String, Codable, CaseIterable, Identifiable {
    case all      = "all"
    case research = "research"
    case review   = "review"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:      return "All types"
        case .research: return "Research articles"
        case .review:   return "Reviews"
        }
    }

    /// PubMed publication-type filter appended to the user's query with AND.
    var queryTag: String? {
        switch self {
        case .all:      return nil
        case .research: return "Journal Article[pt]"
        case .review:   return "(Review[pt] OR Systematic Review[pt])"
        }
    }
}

/// A saved PubMed keyword search with per-search filter settings.
struct PubMedSearch: Codable, Identifiable, Equatable {
    var id:          UUID               = UUID()
    var query:       String
    var dateRange:   PubMedDateRange    = .threeMonths
    var articleType: PubMedArticleType  = .all
}

// MARK: - PubMed fetch + parallel summarization

// Two-step NCBI E-utilities flow:
//   1. esearch  → JSON list of PMIDs matching the user's query + filters
//   2. efetch   → PubMed XML for those PMIDs, parsed by PubMedXMLParser
// Articles that pass the keyword filter are then summarized in a parallel TaskGroup.
//
// Pass an NCBI API key via UserDefaults key "pubmedAPIKey" to raise rate limits
// from 3 req/sec to 10 req/sec. Free to obtain at ncbi.nlm.nih.gov/account.
func fetchAndSummarizePubMed(_ search: PubMedSearch, isPremium: Bool = false) async -> FetchOutcome {
    let query = search.query.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return FetchOutcome() }

    let articleLimit = max(1, UserDefaults.standard.integer(forKey: "articlesPerSubject") > 0
                          ? UserDefaults.standard.integer(forKey: "articlesPerSubject") : 3)
    let apiKey = UserDefaults.standard.string(forKey: "pubmedAPIKey") ?? ""

    // Build the effective query: user text + optional article-type tag
    let effectiveQuery: String
    if let tag = search.articleType.queryTag {
        effectiveQuery = "\(query) AND \(tag)"
    } else {
        effectiveQuery = query
    }

    // ── Step 1: esearch — resolve query to a list of PMIDs ──────────────────
    var esearchItems: [URLQueryItem] = [
        URLQueryItem(name: "db",      value: "pubmed"),
        URLQueryItem(name: "term",    value: effectiveQuery),
        URLQueryItem(name: "retmax",  value: "\(articleLimit)"),
        URLQueryItem(name: "retmode", value: "json"),
        URLQueryItem(name: "sort",    value: "date"),
    ]
    // Apply relative date window if set
    if let days = search.dateRange.reldate {
        esearchItems.append(URLQueryItem(name: "reldate",  value: "\(days)"))
        esearchItems.append(URLQueryItem(name: "datetype", value: "pdat"))
    }
    if !apiKey.isEmpty { esearchItems.append(URLQueryItem(name: "api_key", value: apiKey)) }

    var esearchComps = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi")!
    esearchComps.queryItems = esearchItems
    guard let esearchURL = esearchComps.url else { return FetchOutcome() }

    let pmids: [String]
    do {
        let (data, _) = try await URLSession.shared.data(from: esearchURL)
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result  = json["esearchresult"] as? [String: Any],
              let idList  = result["idlist"] as? [String],
              !idList.isEmpty else {
            print("PubMed esearch: no results for '\(query)'")
            return FetchOutcome()   // empty result — not an error worth showing
        }
        pmids = idList
    } catch {
        print("PubMed esearch error: \(error.localizedDescription)")
        return FetchOutcome(errorMessage: friendlyNetworkError(error, source: "pubmed"))
    }

    // ── Step 2: efetch — retrieve full records as PubMed XML ─────────────────
    var efetchItems: [URLQueryItem] = [
        URLQueryItem(name: "db",      value: "pubmed"),
        URLQueryItem(name: "id",      value: pmids.joined(separator: ",")),
        URLQueryItem(name: "rettype", value: "abstract"),
        URLQueryItem(name: "retmode", value: "xml"),
    ]
    if !apiKey.isEmpty { efetchItems.append(URLQueryItem(name: "api_key", value: apiKey)) }

    var efetchComps = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi")!
    efetchComps.queryItems = efetchItems
    guard let efetchURL = efetchComps.url else { return FetchOutcome() }

    let records: [PubMedRecord]
    do {
        let (data, _) = try await URLSession.shared.data(from: efetchURL)
        let delegate  = PubMedXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        xmlParser.parse()
        records = delegate.records
    } catch {
        print("PubMed efetch error: \(error.localizedDescription)")
        return FetchOutcome(errorMessage: friendlyNetworkError(error, source: "pubmed"))
    }

    // ── Step 3: keyword filter ───────────────────────────────────────────────
    let candidates = records.filter {
        searchKeywords(in: $0.abstract) || searchKeywords(in: $0.title)
    }
    guard !candidates.isEmpty else { return FetchOutcome() }

    // ── Step 4: parallel summarization ──────────────────────────────────────
    let articles = await withTaskGroup(of: Article.self) { group in
        for record in candidates {
            group.addTask {
                let textToSummarize = record.abstract.isEmpty ? record.title : record.abstract
                let summary = await summarizeText(inputText: textToSummarize, isPremium: isPremium)
                return Article(
                    title:   record.title,
                    doi:     record.doi,
                    link:    "https://pubmed.ncbi.nlm.nih.gov/\(record.pmid)/",
                    summary: summary ?? (isPremium ? "Summary unavailable." : "Upgrade to Pro for AI summaries."),
                    source:  "pubmed"
                )
            }
        }
        var results: [Article] = []
        for await article in group { results.append(article) }
        return results
    }
    return FetchOutcome(articles: articles)
}
