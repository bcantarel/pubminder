import SwiftUI


struct FeaturePage: View {
    @Binding var selectedSubject: String
    var body: some View {
        VStack {
            Text("Details")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.bottom)
            ListOfThings(selectedSubject: $selectedSubject)
        }
        .padding()
    }
}


#Preview {
    StatefulPreviewWrapper("bioinformatics") { binding in
        FeaturePage(selectedSubject: binding)
    }
    .frame(maxHeight: .infinity)
    .background(Gradient(colors: gradientColors))
    .foregroundStyle(.white)
}
