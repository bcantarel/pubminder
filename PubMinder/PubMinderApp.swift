//
//  PubMinderApp.swift
//  PubMinder
//

import SwiftUI
import StoreKit

@main
struct PubMinderApp: App {
    // Comma-separated selected subjects in "source:slug" format, e.g. "biorxiv:genomics,medrxiv:oncology"
    @AppStorage("selectedSubjectsV2")   private var selectedSubjectsRaw: String = ""
    @AppStorage("savedArticlesData")    private var savedArticlesRaw: String = "[]"
    @AppStorage("hasSeenOnboarding")    private var hasSeenOnboarding: Bool = false
    @AppStorage("digestEnabled")        private var digestEnabled: Bool = false
    @AppStorage("digestHour")           private var digestHour: Int = 8
    @AppStorage("digestMinute")         private var digestMinute: Int = 0

    /// Manages the one-time IAP that unlocks preprint sources.
    @StateObject private var store = StoreKitManager()

    @State private var summaries: [Article] = []
    @State private var isLoading: Bool = false
    @State private var fetchErrors: [String] = []
    @State private var loadTask: Task<Void, Never>?

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
        // Cancel any in-flight load so a fresh call (e.g. after premium is confirmed
        // asynchronously by StoreKit) always wins with the correct isPremium value.
        loadTask?.cancel()
        summaries   = []
        fetchErrors = []
        isLoading   = true

        // Snapshot isPremium now, on the main actor, so async task closures below
        // all see the same value even if StoreKit updates isPremium mid-flight.
        let isPremium = store.isPremium

        let subjects = Array(selectedSubjects)
        let pubmedSearches = loadPubMedSearches()

        guard !subjects.isEmpty || !pubmedSearches.isEmpty else {
            isLoading = false
            return
        }

        loadTask = Task {
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

                    group.addTask { await fetchAndSummarizeRSSFeed(feedURL: feedURL, source: source, isPremium: isPremium) }
                }

                // ── PubMed keyword searches ──────────────────────────────────
                for search in pubmedSearches {
                    group.addTask { await fetchAndSummarizePubMed(search, isPremium: isPremium) }
                }

                for await outcome in group {
                    // Skip stale results if this load was superseded by a newer call.
                    guard !Task.isCancelled else { continue }
                    await MainActor.run {
                        summaries.append(contentsOf: outcome.articles)
                        if let msg = outcome.errorMessage, !fetchErrors.contains(msg) {
                            fetchErrors.append(msg)
                        }
                    }
                }
            }

            // Only clear the loading flag if this task wasn't cancelled.
            // The replacement task that cancelled us manages isLoading itself.
            if !Task.isCancelled {
                await MainActor.run { isLoading = false }
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
                fetchErrors: fetchErrors,
                onSave: saveArticle,
                onRemove: removeArticle,
                onToggleSubject: toggleSubject,
                onRefresh: loadSummaries
            )
            .environmentObject(store)
            .onAppear {
                let hasSource = !selectedSubjects.isEmpty || !loadPubMedSearches().isEmpty
                // Auto-load when onboarding is done, at least one source is selected,
                // and at least one AI backend is available (Apple Intelligence OR Groq key).
                if hasSeenOnboarding && hasAISummarization() && hasSource { loadSummaries() }

                // Re-schedule the daily digest on each launch in case the user
                // revoked and re-granted notification permission in iOS Settings.
                if digestEnabled && store.isPremium {
                    Task {
                        await NotificationManager.shared.refreshStatus()
                        if NotificationManager.shared.authorizationStatus == .authorized {
                            NotificationManager.shared.scheduleDailyDigest(hour: digestHour, minute: digestMinute)
                        }
                    }
                }
            }
            // When premium status is confirmed after app launch (StoreKit verification
            // completes asynchronously), reload so articles get real AI summaries
            // instead of the "Upgrade to Pro" placeholder from the initial load.
            .onChange(of: store.isPremium) { _, newValue in
                if newValue {
                    let hasSource = !selectedSubjects.isEmpty || !loadPubMedSearches().isEmpty
                    if hasSeenOnboarding && hasAISummarization() && hasSource { loadSummaries() }
                }
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
