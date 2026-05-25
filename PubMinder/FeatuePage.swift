import SwiftUI

// The Saved tab — shows bookmarked articles as full cards with a remove button.
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
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(savedArticles) { article in
                                SavedArticleCard(article: article, onRemove: { onRemove(article) })
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Saved Articles")
        }
    }
}

struct SavedArticleCard: View {
    let article: Article
    let onRemove: () -> Void

    // Formatted text shared via the iOS share sheet.
    private var shareContent: String {
        var parts: [String] = []
        if !article.title.isEmpty { parts.append(article.title) }
        if !article.summary.isEmpty { parts.append(article.summary) }
        if !article.link.isEmpty { parts.append(article.link) }
        return parts.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title row + share + remove buttons
            HStack(alignment: .top, spacing: 8) {
                Text(article.title.isEmpty ? "Untitled" : article.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                ShareLink(item: shareContent) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // DOI
            if !article.doi.isEmpty {
                LabeledRow(icon: "number", label: "DOI", value: article.doi)
            }

            // Link (tappable)
            if let url = article.articleURL {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Link(article.link, destination: url)
                        .font(.caption)
                        .foregroundStyle(Color.linkBlue)
                        .lineLimit(2)
                }
            }

            // Summary
            if !article.summary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summary")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(article.summary)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    SavedPage(
        savedArticles: [
            Article(title: "A study on gene expression", doi: "10.1101/2024.01.01",
                    link: "https://biorxiv.org", summary: "A sample summary about gene regulation and expression patterns in cancer cells."),
            Article(title: "Bioinformatics pipeline advances", doi: "10.1101/2024.02.01",
                    link: "https://biorxiv.org", summary: "Another summary describing a novel alignment tool.")
        ],
        onRemove: { _ in }
    )
}
