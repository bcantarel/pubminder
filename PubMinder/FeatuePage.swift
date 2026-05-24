import SwiftUI

// The Saved tab — shows bookmarked articles with a delete button each.
struct SavedPage: View {
    var savedArticles: [Article]
    var onRemove: (Article) -> Void

    var body: some View {
        NavigationView {
            Group {
                if savedArticles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No saved articles yet")
                            .font(.title3).bold()
                        Text("Tap the bookmark icon on any Summary card to save it here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(savedArticles) { article in
                            SavedArticleRow(article: article, onRemove: { onRemove(article) })
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Articles")
        }
    }
}

struct SavedArticleRow: View {
    let article: Article
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title.isEmpty ? "Untitled" : article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !article.doi.isEmpty {
                    Text(article.doi)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SavedPage(
        savedArticles: [
            Article(title: "A study on gene expression", doi: "10.1101/2024.01.01",
                    link: "https://biorxiv.org", summary: "A sample summary."),
            Article(title: "Bioinformatics pipeline advances", doi: "10.1101/2024.02.01",
                    link: "https://biorxiv.org", summary: "Another summary.")
        ],
        onRemove: { _ in }
    )
}
