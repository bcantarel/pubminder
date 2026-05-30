import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// Subject presets offered on the quick-pick page.
// Each preset sets a curated selection of subjects across sources.
private struct SubjectPreset: Identifiable {
    let id       = UUID()
    let label:     String
    let icon:      String
    let color:     Color
    let subjects:  [String]   // "source:slug" format
}

private let subjectPresets: [SubjectPreset] = [
    SubjectPreset(
        label:    "Cancer Biology",
        icon:     "cross.case.fill",
        color:    .red,
        subjects: ["biorxiv:cancer_biology", "medrxiv:oncology"]
    ),
    SubjectPreset(
        label:    "Immunology",
        icon:     "shield.lefthalf.filled",
        color:    .orange,
        subjects: ["biorxiv:immunology", "medrxiv:allergy_and_immunology"]
    ),
    SubjectPreset(
        label:    "Neuroscience",
        icon:     "brain.head.profile",
        color:    .purple,
        subjects: ["biorxiv:neuroscience", "medrxiv:neurology"]
    ),
    SubjectPreset(
        label:    "Genomics & Bioinformatics",
        icon:     "helix",
        color:    .green,
        subjects: ["biorxiv:genomics", "biorxiv:bioinformatics"]
    ),
    SubjectPreset(
        label:    "AI / Machine Learning",
        icon:     "cpu.fill",
        color:    Color(red: 0.1, green: 0.55, blue: 0.6),
        subjects: ["arxiv:cs.AI", "arxiv:cs.LG", "arxiv:cs.CL"]
    ),
    SubjectPreset(
        label:    "Clinical Medicine",
        icon:     "stethoscope",
        color:    .blue,
        subjects: ["medrxiv:cardiovascular_medicine", "medrxiv:infectious_diseases"]
    ),
    SubjectPreset(
        label:    "Cell & Molecular Biology",
        icon:     "allergens",
        color:    .teal,
        subjects: ["biorxiv:cell_biology", "biorxiv:molecular_biology"]
    ),
    SubjectPreset(
        label:    "Genetics",
        icon:     "ladybug.fill",
        color:    Color(red: 0.6, green: 0.3, blue: 0.7),
        subjects: ["biorxiv:genetics", "medrxiv:genetic_and_genomic_medicine"]
    ),
    SubjectPreset(
        label:    "Microbiology & Infectious Disease",
        icon:     "microbe.fill",
        color:    .yellow,
        subjects: ["biorxiv:microbiology", "medrxiv:infectious_diseases"]
    ),
    SubjectPreset(
        label:    "Psychiatry & Neurology",
        icon:     "figure.mind.and.body",
        color:    .indigo,
        subjects: ["medrxiv:psychiatry_and_clinical_psychology", "medrxiv:neurology"]
    ),
]

// MARK: - Main onboarding container

struct OnboardingView: View {
    /// Called when the user completes or skips onboarding.
    var onComplete: (Set<String>) -> Void

    // API key is stored in the Keychain; loaded on .onAppear and saved on .onChange.
    @State private var groqAPIKey: String = ""

    @State private var page: Int = 0
    @State private var selectedPresets: Set<UUID> = []
    @State private var isKeyVisible: Bool = false

    // Subjects collected from the chosen presets
    private var chosenSubjects: Set<String> {
        Set(subjectPresets
            .filter { selectedPresets.contains($0.id) }
            .flatMap { $0.subjects }
        )
    }

    var body: some View {
        TabView(selection: $page) {
            WelcomePage(onNext: { page = 1 })
                .tag(0)
            GroqKeyPage(
                groqAPIKey: $groqAPIKey,
                isKeyVisible: $isKeyVisible,
                onNext: { page = 2 }
            )
            .tag(1)
            SubjectPickerPage(
                presets: subjectPresets,
                selectedPresets: $selectedPresets,
                onComplete: {
                    // Fall back to a default set if the user skipped picking
                    let subjects = chosenSubjects.isEmpty
                        ? Set(["biorxiv:bioinformatics", "biorxiv:genomics"])
                        : chosenSubjects
                    onComplete(subjects)
                }
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: page)
        // Load Groq key from Keychain on first appear (migrates legacy UserDefaults value if present).
        .onAppear {
            KeychainHelper.migrateFromUserDefaults(userDefaultsKey: "groqAPIKey", keychainKey: "groqAPIKey")
            groqAPIKey = KeychainHelper.load(forKey: "groqAPIKey") ?? ""
        }
        // Persist any key the user types during onboarding back to the Keychain.
        .onChange(of: groqAPIKey) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { KeychainHelper.delete(forKey: "groqAPIKey") }
            else               { KeychainHelper.save(trimmed, forKey: "groqAPIKey") }
        }
        // Dots progress indicator
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: i == page ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: page)
                }
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(22)
                    .shadow(radius: 8)

                VStack(spacing: 8) {
                    Text("Welcome to PubMinder")
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)

                    Text("Your AI-powered research feed.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                FeatureRow(icon: "newspaper.fill",      color: .blue,
                           text: "Latest preprints from bioRxiv, medRxiv, arXiv, and PubMed")
                FeatureRow(icon: "brain.head.profile",  color: .purple,
                           text: "AI summaries in 2–3 sentences — on-device or via Groq")
                FeatureRow(icon: "bookmark.fill",       color: .orange,
                           text: "Save papers to read later and share with one tap")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 72)   // room for page dots
        }
    }
}

private struct FeatureRow: View {
    let icon:  String
    let color: Color
    let text:  String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Page 2: Groq Key (adaptive — detects Apple Intelligence at runtime)

private struct GroqKeyPage: View {
    @Binding var groqAPIKey: String
    @Binding var isKeyVisible: Bool
    var onNext: () -> Void

    var body: some View {
        Group {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *),
               SystemLanguageModel.default.availability == .available {
                AppleAIReadyPage(
                    groqAPIKey: $groqAPIKey,
                    isKeyVisible: $isKeyVisible,
                    onNext: onNext
                )
            } else {
                GroqKeySetupPage(
                    groqAPIKey: $groqAPIKey,
                    isKeyVisible: $isKeyVisible,
                    onNext: onNext
                )
            }
            #else
            GroqKeySetupPage(
                groqAPIKey: $groqAPIKey,
                isKeyVisible: $isKeyVisible,
                onNext: onNext
            )
            #endif
        }
    }
}

// MARK: - Apple Intelligence available path

private struct AppleAIReadyPage: View {
    @Binding var groqAPIKey: String
    @Binding var isKeyVisible: Bool
    var onNext: () -> Void

    @State private var showGroqSection: Bool = false
    private var hasKey: Bool { !groqAPIKey.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                }

                VStack(spacing: 8) {
                    Text("You're all set!")
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)

                    Text("Your iPhone summarizes papers on-device using Apple Intelligence — no API key needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Optional Groq disclosure for power users
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3)) { showGroqSection.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.secondary)
                        Text("Add a Groq API key (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showGroqSection ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                if showGroqSection {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Groq is a cloud AI — useful as a fallback if on-device AI is busy or unavailable.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                            Group {
                                if isKeyVisible {
                                    TextField("gsk_…", text: $groqAPIKey)
                                } else {
                                    SecureField("gsk_…", text: $groqAPIKey)
                                }
                            }
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))

                            Button { isKeyVisible.toggle() } label: {
                                Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .cornerRadius(10)

                        if hasKey {
                            Label("Groq key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(.green)
                        }

                        if let url = URL(string: "https://console.groq.com") {
                            Link("Get a free key at console.groq.com →", destination: url)
                                .font(.caption)
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 72)
        }
    }
}

// MARK: - Groq key required path (older devices / Apple AI unavailable)

private struct GroqKeySetupPage: View {
    @Binding var groqAPIKey: String
    @Binding var isKeyVisible: Bool
    var onNext: () -> Void

    private var hasKey: Bool { !groqAPIKey.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Set up AI Summaries")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)

                Text("PubMinder uses Groq's free AI to summarize papers. You'll need a free API key — no credit card required.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                // Step instructions
                VStack(alignment: .leading, spacing: 6) {
                    StepRow(number: "1", text: "Go to console.groq.com and sign up")
                    StepRow(number: "2", text: "Open API Keys → Create API Key")
                    StepRow(number: "3", text: "Paste the key below (starts with gsk_)")
                }

                if let url = URL(string: "https://console.groq.com") {
                    Link("Open console.groq.com →", destination: url)
                        .font(.footnote).padding(.bottom, 4)
                }

                // Key input
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                    Group {
                        if isKeyVisible {
                            TextField("gsk_…", text: $groqAPIKey)
                        } else {
                            SecureField("gsk_…", text: $groqAPIKey)
                        }
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))

                    Button { isKeyVisible.toggle() } label: {
                        Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)

                // Status
                if hasKey {
                    Label("API key saved", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Label("No key yet", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text(hasKey ? "Continue" : "Continue without key")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasKey ? Color.blue : Color(uiColor: .secondarySystemBackground))
                        .foregroundStyle(hasKey ? .white : .secondary)
                        .cornerRadius(14)
                }

                if !hasKey {
                    Text("You can add your key later in Settings.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 72)
        }
    }
}

private struct StepRow: View {
    let number: String
    let text:   String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Page 3: Subject quick-pick

private struct SubjectPickerPage: View {
    let presets: [SubjectPreset]
    @Binding var selectedPresets: Set<UUID>
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("What field are you in?")
                    .font(.largeTitle).bold()
                Text("Pick one or more areas. You can always adjust this in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()

            ScrollView {
            VStack(spacing: 14) {
                ForEach(presets) { preset in
                    let selected = selectedPresets.contains(preset.id)
                    Button {
                        if selected { selectedPresets.remove(preset.id) }
                        else        { selectedPresets.insert(preset.id) }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: preset.icon)
                                .font(.title2)
                                .foregroundStyle(selected ? .white : preset.color)
                                .frame(width: 44, height: 44)
                                .background(selected ? preset.color : preset.color.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.label)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(preset.subjects.count) subjects")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? preset.color : .secondary.opacity(0.4))
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selected ? preset.color.opacity(0.6) : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            } // ScrollView

            Spacer()

            Button(action: onComplete) {
                Text("Explore PubMinder →")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 72)
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
