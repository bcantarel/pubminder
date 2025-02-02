import SwiftUI
let backgroundGradient = LinearGradient(
    colors: [Color.white, Color.blue],
    startPoint: .top, endPoint: .bottom)
let gradientColors: [Color] = [
    .gradientTop,
    .gradientBottom
]
import SwiftUI


struct ContentView: View {
    @Binding var selectedSubject: String
    @Binding var summary: String
    var body: some View {
        TabView() {
            Tab("Summary", systemImage: "list.clipboard") {
                SummaryPage(summaries: $summary)
            }
            Tab("Saved", systemImage: "square.and.arrow.down.on.square.fill") {
                FeaturePage(selectedSubject: $selectedSubject)
                    .frame(maxHeight: .infinity)
                    .background(Gradient(colors: gradientColors))
                    .foregroundStyle(.white)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

struct ContentView_Previews: PreviewProvider {
    @State static var previewSelectedSubject = "bioinformatics"
    @State static var previewSummary = "This is a sample summary text."

    static var previews: some View {
        ContentView(selectedSubject: $previewSelectedSubject, summary: $previewSummary)
    }
}
