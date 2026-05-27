import SwiftUI

let gradientColors: [Color] = [.gradientTop, .gradientBottom]

struct ContentView: View {
    @Binding var summaries: [Article]
    @Binding var isLoading: Bool
    var selectedSubjects: Set<String>
    var savedArticles: [Article]
    var fetchErrors: [String]
    var onSave: (Article) -> Void
    var onRemove: (Article) -> Void
    var onToggleSubject: (String) -> Void
    var onRefresh: () -> Void

    var body: some View {
        TabView {
            Tab("Summary", systemImage: "list.clipboard") {
                SummaryPage(
                    summaries: $summaries,
                    isLoading: $isLoading,
                    savedArticles: savedArticles,
                    fetchErrors: fetchErrors,
                    onSave: onSave,
                    onRefresh: onRefresh
                )
            }
            Tab("Saved", systemImage: "bookmark.fill") {
                SavedPage(savedArticles: savedArticles, onRemove: onRemove)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsPage(
                    selectedSubjects: selectedSubjects,
                    onToggle: onToggleSubject,
                    onRefresh: onRefresh,
                    isLoading: isLoading
                )
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
