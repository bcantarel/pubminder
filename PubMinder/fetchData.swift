import Foundation
import FeedKit
import SwiftUI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// Structured article type — title/doi/link come straight from the RSS feed,
// summary is the only field that Groq touches.
struct Article: Identifiable, Codable, Hashable {
    let title:   String
    let doi:     String   // empty string when not parseable
    let link:    String
    let summary: String

    // Stable identity: prefer DOI, fall back to link
    var id: String { doi.isEmpty ? link : doi }

    // URL with a percent-encoding fallback for feeds that emit unencoded characters
    var articleURL: URL? {
        if let url = URL(string: link) { return url }
        let encoded = link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? link
        return URL(string: encoded)
    }
}

// Reads the Groq API key the user entered in Settings.
// Returns an empty string if not set, which will cause summarizeText to fail gracefully.
var groqAPIKey: String {
    UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
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

// Tries on-device Apple Intelligence first (iOS 18+, eligible hardware).
// Falls back to Groq automatically — no callbacks, just await and get the result.
func summarizeText(inputText: String) async -> String? {
    if #available(iOS 26.0, *) {
        if let result = await summarizeWithAppleAI(inputText: inputText) {
            return result
        }
    }
    return await summarizeWithGroq(inputText: inputText)
}

// MARK: - RSS fetch + parallel summarization

// Fetch one RSS feed and summarize all matching articles in parallel using TaskGroup.
// Returns the finished [Article] array when every summary is done.
// The old callback-based version had a race condition on the `remaining` counter
// (decremented from multiple background threads). TaskGroup eliminates that entirely.
func fetchAndSummarizeRSSFeed(feedURL: String) async -> [Article] {
    guard let url = URL(string: feedURL) else { return [] }
    let parser = FeedParser(URL: url)

    // FeedParser uses callbacks internally, so we bridge it to async/await with
    // withCheckedContinuation — this suspends until the parser calls back, then resumes.
    let candidates: [(title: String, link: String, doi: String, abstract: String)] =
        await withCheckedContinuation { continuation in
            parser.parseAsync { result in
                switch result {
                case .success(let feed):
                    guard let rssFeed = feed.rssFeed else {
                        continuation.resume(returning: [])
                        return
                    }
                    let stored = UserDefaults.standard.integer(forKey: "articlesPerSubject")
                    let articleLimit = stored > 0 ? stored : 3
                    var found: [(title: String, link: String, doi: String, abstract: String)] = []
                    for item in rssFeed.items ?? [] {
                        guard let abstract = item.description else { continue }
                        guard searchKeywords(in: abstract) else { continue }
                        // bioRxiv sometimes puts the article URL in <guid> rather than <link>.
                        // Trim whitespace/newlines that RSS parsers occasionally leave in the field.
                        let link = (item.link ?? item.guid?.value ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        print("RSS item — title: \(item.title ?? "nil"), link: '\(link)'")
                        found.append((
                            title:    item.title ?? "Untitled",
                            link:     link,
                            doi:      extractDOI(from: link),
                            abstract: abstract
                        ))
                        if found.count >= articleLimit { break }
                    }
                    continuation.resume(returning: found)

                case .failure(let error):
                    print("RSS parse error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }

    guard !candidates.isEmpty else { return [] }

    // Summarize every candidate at the same time. TaskGroup launches all the
    // summarizeText calls concurrently and waits for all of them to finish before
    // returning — no manual `remaining` counter, no race conditions.
    return await withTaskGroup(of: Article.self) { group in
        for candidate in candidates {
            group.addTask {
                let summary = await summarizeText(inputText: candidate.abstract)
                return Article(
                    title:   candidate.title,
                    doi:     candidate.doi,
                    link:    candidate.link,
                    summary: summary ?? "Summary unavailable."
                )
            }
        }
        var articles: [Article] = []
        for await article in group {
            articles.append(article)
        }
        return articles
    }
}
