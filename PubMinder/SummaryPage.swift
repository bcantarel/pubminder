import SwiftUI

struct SummaryPage: View {
    @Binding var summaries: [Article]
    @Binding var isLoading: Bool
    var savedArticles: [Article]
    var fetchErrors: [String]
    var onSave: (Article) -> Void
    var onRefresh: () -> Void

    @State private var sourceFilter: String = "All"
    @State private var dismissedErrors: Set<String> = []

    private var visibleErrors: [String] {
        fetchErrors.filter { !dismissedErrors.contains($0) }
    }

    // The distinct sources present in the current summaries, in display order
    private var availableSources: [String] {
        let order = ["biorxiv", "medrxiv", "arxiv", "pubmed"]
        let present = Set(summaries.map { $0.source.isEmpty ? "biorxiv" : $0.source })
        return order.filter { present.contains($0) }
    }

    // Articles filtered by the selected source chip
    private var filteredSummaries: [Article] {
        guard sourceFilter != "All" else { return summaries }
        return summaries.filter {
            ($0.source.isEmpty ? "biorxiv" : $0.source) == sourceFilter
        }
    }

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
                    VStack(spacing: 16) {
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
                        if !hasAISummarization() {
                            NoAINotice()
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {

                            // ── No AI notice ──────────────────────────────────
                            if !hasAISummarization() {
                                NoAINotice()
                                    .padding(.top, 4)
                            }

                            // ── Error banner ─────────────────────────────────
                            if !visibleErrors.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(visibleErrors, id: \.self) { error in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.orange)
                                                .font(.subheadline)
                                            Text(error)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Spacer()
                                            Button {
                                                dismissedErrors.insert(error)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(12)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                            }

                            // ── Source filter chips ──────────────────────────
                            if availableSources.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        FilterChip(label: "All",
                                                   isSelected: sourceFilter == "All") {
                                            sourceFilter = "All"
                                        }
                                        ForEach(availableSources, id: \.self) { src in
                                            FilterChip(label: sourceDisplayName(src),
                                                       color: sourceBadgeColor(src),
                                                       isSelected: sourceFilter == src) {
                                                sourceFilter = src
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .padding(.top, 4)
                            }

                            // ── Loading banner ───────────────────────────────
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Loading more…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }

                            // ── Article cards ────────────────────────────────
                            ForEach(filteredSummaries) { article in
                                ArticleCard(
                                    article: article,
                                    isSaved: savedArticles.contains(article),
                                    onSave: { onSave(article) }
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable { onRefresh() }
                }
            }
            .navigationTitle("Research Assistant")
        }
    }
}

// MARK: - Source helpers (shared by SummaryPage and ArticleCard)

func sourceDisplayName(_ source: String) -> String {
    switch source {
    case "biorxiv": return "bioRxiv"
    case "medrxiv": return "medRxiv"
    case "arxiv":   return "arXiv"
    case "pubmed":  return "PubMed"
    default:        return source.isEmpty ? "bioRxiv" : source
    }
}

func sourceBadgeColor(_ source: String) -> Color {
    switch source {
    case "biorxiv": return .green
    case "medrxiv": return .orange
    case "arxiv":   return Color(red: 0.1, green: 0.55, blue: 0.6) // teal
    case "pubmed":  return .blue
    default:        return .secondary
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let label: String
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline).fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.18) : Color(uiColor: .tertiarySystemFill))
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Article card

struct ArticleCard: View {
    let article: Article
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Title row + bookmark ─────────────────────────────────────
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

            // ── Source badge ─────────────────────────────────────────────
            if !article.source.isEmpty {
                let color = sourceBadgeColor(article.source)
                Text(sourceDisplayName(article.source))
                    .font(.caption2).fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }

            Divider()

            // ── DOI / arXiv ID ───────────────────────────────────────────
            if !article.doi.isEmpty {
                let idLabel = article.source == "arxiv" ? "arXiv ID" : "DOI"
                LabeledRow(icon: "number", label: idLabel, value: article.doi)
            }

            // ── "Read Paper →" button ────────────────────────────────────
            if let url = article.articleURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("Read Paper")
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // ── Summary ──────────────────────────────────────────────────
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

// MARK: - No AI configured notice

struct NoAINotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cpu.fill")
                .foregroundStyle(.purple)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("No AI configured")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("Summaries require either Apple Intelligence (A17 Pro / A18 / M-series, iOS 26+) or a free Groq API key. Add your key in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.25), lineWidth: 1))
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
            summary: "This study compares oral microbiomes across hunter-gatherer and industrialized populations, finding that geography and subsistence practices significantly influence diversity.",
            source: "biorxiv"
        ),
        Article(
            title: "Attention Is All You Need — Revisited",
            doi: "2301.12345",
            link: "https://arxiv.org/abs/2301.12345",
            summary: "A retrospective analysis of the transformer architecture and its impact on modern NLP benchmarks.",
            source: "arxiv"
        )
    ]
    @Previewable @State var loading = false
    SummaryPage(summaries: $summaries, isLoading: $loading, savedArticles: [], fetchErrors: [], onSave: { _ in }, onRefresh: {})
}
