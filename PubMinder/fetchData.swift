import Foundation
import FeedKit
import SwiftUI

#if canImport(FoundationNetworking)
import FoundationNetworking
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

// Summarize an abstract via Groq. Only the abstract text is sent — no title, no metadata.
func summarizeText(inputText: String, completion: @escaping (String?) -> Void) {
    let key = groqAPIKey
    guard !key.isEmpty else {
        print("Groq API key not set. Enter your key in Settings.")
        completion(nil); return
    }
    guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
        completion(nil); return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

    let payload: [String: Any] = [
        "model": "llama-3.3-70b-versatile",
        "temperature": 0,
        "messages": [
            ["role": "system", "content": "You are a graduate research assistant. Summarize the following scientific abstract for your peers in 2–3 sentences. Be specific about the key finding."],
            ["role": "user", "content": inputText]
        ]
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
        completion(nil); return
    }
    request.httpBody = jsonData

    URLSession.shared.dataTask(with: request) { data, _, error in
        guard let data = data, error == nil else {
            print("Groq error: \(error?.localizedDescription ?? "unknown")")
            completion(nil); return
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            completion(content)
        } else {
            print("Unexpected Groq response: \(String(data: data, encoding: .utf8) ?? "unreadable")")
            completion(nil)
        }
    }.resume()
}

// Fetch and parse an RSS feed, summarize matching articles via Groq.
// Title, DOI, and link are read directly from the RSS item fields.
// Only the abstract (item.description) is sent to Groq.
// - onArticle: called once per completed Article
// - onDone:    called once when all articles for this feed are processed
func fetchAndSummarizeRSSFeed(feedURL: String,
                               onArticle: @escaping (Article) -> Void,
                               onDone: @escaping () -> Void) {
    guard let url = URL(string: feedURL) else { onDone(); return }
    let parser = FeedParser(URL: url)

    parser.parseAsync { result in
        switch result {
        case .success(let feed):
            guard let rssFeed = feed.rssFeed else { onDone(); return }

            // Collect up to 3 items whose abstract matches the keyword filter
            var candidates: [(title: String, link: String, doi: String, abstract: String)] = []
            for item in rssFeed.items ?? [] {
                guard let abstract = item.description else { continue }
                guard searchKeywords(in: abstract) else { continue }
                // bioRxiv sometimes puts the article URL in <guid> rather than <link>.
                // Trim whitespace/newlines that RSS parsers occasionally leave in the field —
                // a single stray space causes URL(string:) to return nil.
                let link = (item.link ?? item.guid?.value ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                print("RSS item — title: \(item.title ?? "nil"), link: '\(link)'")
                candidates.append((
                    title:    item.title ?? "Untitled",
                    link:     link,
                    doi:      extractDOI(from: link),
                    abstract: abstract
                ))
                if candidates.count >= 3 { break }
            }

            guard !candidates.isEmpty else { onDone(); return }

            var remaining = candidates.count
            for candidate in candidates {
                // Send only the abstract to Groq — title and metadata stay from RSS
                summarizeText(inputText: candidate.abstract) { summary in
                    let article = Article(
                        title:   candidate.title,
                        doi:     candidate.doi,
                        link:    candidate.link,
                        summary: summary ?? "Summary unavailable."
                    )
                    onArticle(article)
                    remaining -= 1
                    if remaining == 0 { onDone() }
                }
            }

        case .failure(let error):
            print("RSS parse error: \(error.localizedDescription)")
            onDone()
        }
    }
}
