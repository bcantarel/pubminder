import Foundation
import FeedKit
import SwiftUI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Define a function to check if the summary contains relevant keywords
func searchKeywords(in summary: String) -> Bool {
    let keywords = ["genomics", "AI", "phenotype", "transcriptomics", "genotype", "bioinformatics", "gene", "expression", "regulation", "cranofacial", "size", "color", "coat"]
    for keyword in keywords {
        if summary.lowercased().contains(keyword.lowercased()) {
            return true
        }
    }
    return false
}

// Function to summarize text using an external service (Ollama API integration)
func summarizeText(inputText: String, completion: @escaping (String?) -> Void) {
    let url = URL(string: "https://api.ollama.ai/summarize")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let prompt = "Summarize the following: \(inputText)"
    let payload: [String: Any] = [
        "model": "mistral-small",
        "temperature": 0,
        "messages": [
            ["role": "system", "content": "You are a graduate research assistant that summarizes scientific information for your peers in 1 or 2 sentences"],
            ["role": "user", "content": prompt]
        ]
    ]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
        completion(nil)
        return
    }
    request.httpBody = jsonData

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            print("Error during summarization: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
            return
        }
        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let choices = jsonResponse["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            completion(content)
        } else {
            completion(nil)
        }
    }
    task.resume()
}

// Function to fetch and parse RSS feeds using FeedKit
func fetchAndSummarizeRSSFeed(feedURL: String, completion: @escaping (String?) -> Void) {
    guard let url = URL(string: feedURL) else { return }
    let parser = FeedParser(URL: url)

    parser.parseAsync { result in
        switch result {
        case .success(let feed):
            if let rssFeed = feed.rssFeed {
                var count = 0
                for item in rssFeed.items ?? [] {
                    guard let content = item.description else { continue }
                    if !searchKeywords(in: content) { continue }

                    count += 1
                    if count > 3 { break }

                    summarizeText(inputText: content) { summary in
                        guard let summary = summary else {
                            print("An error occurred while generating the summary.")
                            return
                        }
                        let info = "Title: \(item.title ?? "No title")\nLink: \(item.link ?? "No link")\nSummary: \(summary)"
                        completion(info)
                    }
                }
            }
        case .failure(let error):
            print("Failed to parse RSS feed: \(error.localizedDescription)")
        }
    }
}
