//
//  PubMinderApp.swift
//  PubMinder
//

import SwiftUI

@main
struct PubMinderApp: App {
    // Comma-separated selected subjects in "source:slug" format, e.g. "biorxiv:genomics,medrxiv:oncology"
    @AppStorage("selectedSubjectsV2")   private var selectedSubjectsRaw: String = "biorxiv:bioinformatics"
    @AppStorage("savedArticlesData")    private var savedArticlesRaw: String = "[]"
    @AppStorage("hasSeenOnboarding")    private var hasSeenOnboarding: Bool = false

    @State private var summaries: [Article] = []
    @State private var isLoading: Bool = false
    @State private var fetchErrors: [String] = []

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

    // Reads PubMed searches from UserDefaults (written by SettingsPage).
    // Reads V2 storage (PubMedSearch objects); falls back to legacy [String] if V2 is empty.
    private func loadPubMedSearches() -> [PubMedSearch] {
        let v2Raw = UserDefaults.standard.string(forKey: "pubmedSearchesV2") ?? ""
        if !v2Raw.isEmpty,
           let decoded = try? JSONDecoder().decode([PubMedSearch].self, from: Data(v2Raw.utf8)) {
            return decoded
        }
        // Legacy fallback: plain [String] format from before filter support was added
        let legacyRaw = UserDefaults.standard.string(forKey: "pubmedSearchesRaw") ?? ""
        guard !legacyRaw.isEmpty else { return [] }
        let queries = (try? JSONDecoder().decode([String].self, from: Data(legacyRaw.utf8))) ?? []
        return queries.map { PubMedSearch(query: $0) }
    }

    func loadSummaries() {
        summaries   = []
        fetchErrors = []   // clear previous errors on each refresh
        isLoading   = true

        let subjects       = Array(selectedSubjects)
        let pubmedSearches = loadPubMedSearches()

        guard !subjects.isEmpty || !pubmedSearches.isEmpty else {
            isLoading = false
            return
        }

        Task {
            // All RSS/Atom feeds AND PubMed queries run in a single parallel TaskGroup.
            // Each FetchOutcome is unpacked: articles go to the feed, errors go to the banner.
            await withTaskGroup(of: FetchOutcome.self) { group in

                // ── RSS / Atom feeds (bioRxiv, medRxiv, arXiv) ──────────────
                // Read article limit once — used to cap the arXiv API max_results param.
                let articleLimit = max(1, UserDefaults.standard.integer(forKey: "articlesPerSubject") > 0
                                      ? UserDefaults.standard.integer(forKey: "articlesPerSubject") : 3)

                for subjectID in subjects {
                    let parts  = subjectID.split(separator: ":", maxSplits: 1).map(String.init)
                    let source = parts.first ?? "biorxiv"
                    let slug   = parts.last  ?? subjectID

                    let feedURL: String
                    switch source {
                    case "medrxiv":
                        feedURL = "https://connect.medrxiv.org/medrxiv_xml.php?subject=" + slug
                    case "arxiv":
                        // arXiv RSS (arxiv.org/rss/) is unreliable — use the official Atom API instead.
                        // Results are sorted newest-first; max_results caps at the user's feed size setting.
                        feedURL = "https://export.arxiv.org/api/query?search_query=cat:\(slug)&start=0&max_results=\(articleLimit)&sortBy=submittedDate&sortOrder=descending"
                    default:
                        feedURL = "https://connect.biorxiv.org/biorxiv_xml.php?subject=" + slug
                    }

                    group.addTask { await fetchAndSummarizeRSSFeed(feedURL: feedURL, source: source) }
                }

                // ── PubMed keyword searches ──────────────────────────────────
                for search in pubmedSearches {
                    group.addTask { await fetchAndSummarizePubMed(search) }
                }

                for await outcome in group {
                    await MainActor.run {
                        summaries.append(contentsOf: outcome.articles)
                        if let msg = outcome.errorMessage, !fetchErrors.contains(msg) {
                            fetchErrors.append(msg)
                        }
                    }
                }
            }

            await MainActor.run { isLoading = false }
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
                fetchErrors: fetchErrors,
                onSave: saveArticle,
                onRemove: removeArticle,
                onToggleSubject: toggleSubject,
                onRefresh: loadSummaries
            )
            .onAppear {
                let hasSource = !selectedSubjects.isEmpty || !loadPubMedSearches().isEmpty
                // Auto-load when onboarding is done, at least one source is selected,
                // and at least one AI backend is available (Apple Intelligence OR Groq key).
                if hasSeenOnboarding && hasAISummarization() && hasSource { loadSummaries() }
            }
            .sheet(isPresented: Binding(
                get:  { !hasSeenOnboarding },
                set:  { if !$0 { hasSeenOnboarding = true } }
            )) {
                OnboardingView { chosenSubjects in
                    // Apply the subject preset the user picked, then kick off the first load
                    if !chosenSubjects.isEmpty {
                        selectedSubjectsRaw = chosenSubjects.joined(separator: ",")
                    }
                    hasSeenOnboarding = true
                    // Load if Apple Intelligence is available OR a Groq key was entered
                    if hasAISummarization() { loadSummaries() }
                }
                .interactiveDismissDisabled(true)
            }
        }
    }
}
