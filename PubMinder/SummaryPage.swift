import SwiftUI

struct SummaryPage: View {
    @Binding var summaries: String
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Feed Management Section
                        HStack {
                            Button(action: {
                                // Action to organize feeds
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 24))
                                Text("Organize Feeds")
                            }
                        }
                        .padding(.horizontal)

                        ForEach(summaries, id: \.self) { summary in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.title)
                                    .bold()
                                Text(summary)
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Save, Share, Bookmark buttons
                        HStack {
                            Button(action: {
                                // Save action
                            }) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 24))
                            }
                            Spacer()
                            Button(action: {
                                // Share action
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 24))
                            }
                            Spacer()
                            Button(action: {
                                // Bookmark action
                            }) {
                                Image(systemName: "star")
                                    .font(.system(size: 24))
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Research Assistant")
            .background(Gradient(colors: gradientColors))
            .foregroundStyle(Color(uiColor: UIColor.red))
        }
    }
}


// Placeholder views for navigation
struct HomeView: View {
    var body: some View {
        Text("Home")
    }
}

struct FeedsView: View {
    var body: some View {
        Text("Feeds")
    }
}

struct SavedView: View {
    var body: some View {
        Text("Saved")
    }
}

struct ProfileView: View {
    var body: some View {
        Text("Profile")
    }
}
#Preview {
    @Previewable @State var previewSummary = "This is a sample summary text."
    SummaryPage(summaries: $previewSummary)
}
