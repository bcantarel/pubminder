//
//  PubMinderApp.swift
//  PubMinder
//

import SwiftUI

@main
struct PubMinderApp: App {
    // Comma-separated selected subjects in "source:slug" format, e.g. "biorxiv:genomics,medrxiv:oncology"
    @AppStorage("selectedSubjectsV2") private var selectedSubjectsRaw: String = "biorxiv:bioinformatics"
    // Saved articles as JSON-encoded [Article], persisted across app launches
    @AppStorage("savedArticlesData") private var savedArticlesRaw: String = "[]"

    @State private var summaries: [Article] = []
    @State private var isLoading: Bool = false

    // MARK: - Computed helpers

    var selectedSubjects: Set<String> {
        Set(selectedSubjectsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    var savedArticles: [Article] {
        (try? JSONDecoder().decode([Article].self, from: Data(savedArticlesRaw.utf8))) ?? []
    }

    // MARK: - Subject management

    func toggleSubject(_ subject: String) {
        var current = selectedSubjects
        if current.contains(subject) { current.remove(subject) } else { current.insert(subject) }
        selectedSubjectsRaw = current.joined(separator: ",")
    }

    // MARK: - Saved article management

    func saveArticle(_ article: Article) {
        var list = savedArticles
        guard !list.contains(article) else { return }
        list.append(article)
        persist(list)
    }

    func removeArticle(_ article: Article) {
        var list = savedArticles
        list.removeAll { $0.id == article.id }
        persist(list)
    }

    private func persist(_ list: [Article]) {
        if let data = try? JSONEncoder().encode(list),
           let str = String(data: data, encoding: .utf8) {
            savedArticlesRaw = str
        }
    }

    // MARK: - Feed loading

    func loadSummaries() {
        summaries = []
        isLoading = true

        let subjects = Array(selectedSubjects)
        guard !subjects.isEmpty else { isLoading = false; return }

        var pending = subjects.count

        for subjectID in subjects {
            let parts = subjectID.split(separator: ":", maxSplits: 1).map(String.init)
            let source = parts.first ?? "biorxiv"
            let slug   = parts.last  ?? subjectID

            let feedURL: String
            switch source {
            case "medrxiv":
                feedURL = "https://connect.medrxiv.org/medrxiv_xml.php?subject=" + slug
            default:
                feedURL = "https://connect.biorxiv.org/biorxiv_xml.php?subject=" + slug
            }

            fetchAndSummarizeRSSFeed(feedURL: feedURL) { article in
                DispatchQueue.main.async { summaries.append(article) }
            } onDone: {
                DispatchQueue.main.async {
                    pending -= 1
                    if pending == 0 { isLoading = false }
                }
            }
        }
    }

    // MARK: - App body

    var body: some Scene {
        WindowGroup {
            ContentView(
                summaries: $summaries,
                isLoading: $isLoading,
                selectedSubjects: selectedSubjects,
                savedArticles: savedArticles,
                onSave: saveArticle,
                onRemove: removeArticle,
                onToggleSubject: toggleSubject,
                onRefresh: loadSummaries
            )
            .onAppear {
                let hasKey = !(UserDefaults.standard.string(forKey: "groqAPIKey") ?? "").isEmpty
                if hasKey { loadSummaries() }
            }
        }
    }
}
