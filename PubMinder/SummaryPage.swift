import SwiftUI

struct SummaryPage: View {
    @Binding var summaries: [Article]
    @Binding var isLoading: Bool
    var savedArticles: [Article]
    var onSave: (Article) -> Void

    var body: some View {
        NavigationView {
            Group {
                if isLoading && summaries.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.4)
                        Text("Fetching papers…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if summaries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No papers loaded yet")
                            .font(.title3).bold()
                        Text("Go to Settings, select subjects, and tap Refresh Feed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Loading more…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                            ForEach(summaries) { article in
                                ArticleCard(
                                    article: article,
                                    isSaved: savedArticles.contains(article),
                                    onSave: { onSave(article) }
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Research Assistant")
        }
    }
}

struct ArticleCard: View {
    let article: Article
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title row + bookmark button
            HStack(alignment: .top, spacing: 8) {
                Text(article.title.isEmpty ? "Untitled" : article.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(action: onSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20))
                        .foregroundStyle(isSaved ? Color.blue : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isSaved)
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

struct LabeledRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    @Previewable @State var summaries: [Article] = [
        Article(
            title: "Evolutionary Histories Shape Oral Microbiomes",
            doi: "10.64898/2026.05.20.726600",
            link: "https://www.biorxiv.org/content/10.64898/2026.05.20.726600v1",
            summary: "This study compares oral microbiomes across hunter-gatherer and industrialized populations, finding that geography and subsistence practices significantly influence diversity."
        )
    ]
    @Previewable @State var loading = false
    SummaryPage(summaries: $summaries, isLoading: $loading, savedArticles: [], onSave: { _ in })
}
