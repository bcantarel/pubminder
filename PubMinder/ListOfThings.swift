//
//  ListOfThings.swift
//  PubMinder
//
//  Created by Brandi Cantarel on 10/27/24.
//
import SwiftUI


struct ListOfThings: View {
    @Binding var selectedSubject: String
    @State private var names: [String] = ["genomics", "bioinformatics", "evolutionary_biology", "synthetic_biology", "systems_biology"]
    @State private var pickedName = ""

    var body: some View {
        VStack {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .foregroundStyle(.gradientBottom)
                    .symbolRenderingMode(.hierarchical)
                Text("Subjects")
            }
            .font(.title)
            .bold()
            Text(pickedName.isEmpty ? " " : pickedName)
                .font(.title2)
                .bold()
                .foregroundStyle(.tint)
            
            List {
                ForEach(names, id: \.description) { name in
                    Button(action: {
                        pickedName = name
                        selectedSubject = name // Update the shared state
                    }) {
                        FeatureCard(iconName: "newspaper.fill", description: name)
                            .background(Color("GradientBottom"))
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Add a button for random subject selection
            Button(action: {
                if let randomName = names.randomElement() {
                    pickedName = randomName
                    selectedSubject = randomName // Update the shared state
                } else {
                    pickedName = ""
                    selectedSubject = ""
                }
            }) {
                Text("Pick A Subject")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderedProminent)
            .font(.title2)
        }
        .padding()
    }
}

#Preview {
    StatefulPreviewWrapper("bioinformatics") { binding in
        ListOfThings(selectedSubject: binding)
    }
}

// Helper struct for providing @State in SwiftUI previews
struct StatefulPreviewWrapper<Value: Equatable, Content: View>: View {
    @State private var value: Value
    private var content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
