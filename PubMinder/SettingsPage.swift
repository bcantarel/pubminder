import SwiftUI

// A single subject that can be fetched from either bioRxiv or medRxiv.
// Storage key format: "biorxiv:genomics" or "medrxiv:oncology"
struct FeedSubject: Identifiable, Hashable {
    let source: String       // "biorxiv" or "medrxiv"
    let slug: String         // URL-safe name, e.g. "animal_behavior_and_cognition"
    let displayName: String  // Human-readable, e.g. "Animal Behavior and Cognition"

    var id: String { "\(source):\(slug)" }

    var feedURL: String {
        switch source {
        case "medrxiv":
            return "https://connect.medrxiv.org/medrxiv_xml.php?subject=\(slug)"
        case "arxiv":
            return "https://export.arxiv.org/api/query?search_query=cat:\(slug)&sortBy=submittedDate&sortOrder=descending"
        default:
            return "https://connect.biorxiv.org/biorxiv_xml.php?subject=\(slug)"
        }
    }
}

// Complete subject lists scraped directly from connect.biorxiv.org and connect.medrxiv.org
private let bioRxivSubjects: [FeedSubject] = [
    FeedSubject(source: "biorxiv", slug: "animal_behavior_and_cognition",       displayName: "Animal Behavior and Cognition"),
    FeedSubject(source: "biorxiv", slug: "biochemistry",                         displayName: "Biochemistry"),
    FeedSubject(source: "biorxiv", slug: "bioengineering",                       displayName: "Bioengineering"),
    FeedSubject(source: "biorxiv", slug: "bioinformatics",                       displayName: "Bioinformatics"),
    FeedSubject(source: "biorxiv", slug: "biophysics",                           displayName: "Biophysics"),
    FeedSubject(source: "biorxiv", slug: "cancer_biology",                       displayName: "Cancer Biology"),
    FeedSubject(source: "biorxiv", slug: "cell_biology",                         displayName: "Cell Biology"),
    FeedSubject(source: "biorxiv", slug: "clinical_trials",                      displayName: "Clinical Trials"),
    FeedSubject(source: "biorxiv", slug: "developmental_biology",                displayName: "Developmental Biology"),
    FeedSubject(source: "biorxiv", slug: "ecology",                              displayName: "Ecology"),
    FeedSubject(source: "biorxiv", slug: "epidemiology",                         displayName: "Epidemiology"),
    FeedSubject(source: "biorxiv", slug: "evolutionary_biology",                 displayName: "Evolutionary Biology"),
    FeedSubject(source: "biorxiv", slug: "genetics",                             displayName: "Genetics"),
    FeedSubject(source: "biorxiv", slug: "genomics",                             displayName: "Genomics"),
    FeedSubject(source: "biorxiv", slug: "immunology",                           displayName: "Immunology"),
    FeedSubject(source: "biorxiv", slug: "microbiology",                         displayName: "Microbiology"),
    FeedSubject(source: "biorxiv", slug: "molecular_biology",                    displayName: "Molecular Biology"),
    FeedSubject(source: "biorxiv", slug: "neuroscience",                         displayName: "Neuroscience"),
    FeedSubject(source: "biorxiv", slug: "paleontology",                         displayName: "Paleontology"),
    FeedSubject(source: "biorxiv", slug: "pathology",                            displayName: "Pathology"),
    FeedSubject(source: "biorxiv", slug: "pharmacology_and_toxicology",          displayName: "Pharmacology and Toxicology"),
    FeedSubject(source: "biorxiv", slug: "physiology",                           displayName: "Physiology"),
    FeedSubject(source: "biorxiv", slug: "plant_biology",                        displayName: "Plant Biology"),
    FeedSubject(source: "biorxiv", slug: "scientific_communication_and_education", displayName: "Scientific Communication and Education"),
    FeedSubject(source: "biorxiv", slug: "synthetic_biology",                    displayName: "Synthetic Biology"),
    FeedSubject(source: "biorxiv", slug: "systems_biology",                      displayName: "Systems Biology"),
    FeedSubject(source: "biorxiv", slug: "zoology",                              displayName: "Zoology"),
]

private let medRxivSubjects: [FeedSubject] = [
    FeedSubject(source: "medrxiv", slug: "addiction_medicine",                             displayName: "Addiction Medicine"),
    FeedSubject(source: "medrxiv", slug: "allergy_and_immunology",                         displayName: "Allergy and Immunology"),
    FeedSubject(source: "medrxiv", slug: "anesthesia",                                     displayName: "Anesthesia"),
    FeedSubject(source: "medrxiv", slug: "cardiovascular_medicine",                        displayName: "Cardiovascular Medicine"),
    FeedSubject(source: "medrxiv", slug: "dentistry_and_oral_medicine",                    displayName: "Dentistry and Oral Medicine"),
    FeedSubject(source: "medrxiv", slug: "dermatology",                                    displayName: "Dermatology"),
    FeedSubject(source: "medrxiv", slug: "emergency_medicine",                             displayName: "Emergency Medicine"),
    FeedSubject(source: "medrxiv", slug: "endocrinology",                                  displayName: "Endocrinology"),
    FeedSubject(source: "medrxiv", slug: "epidemiology",                                   displayName: "Epidemiology"),
    FeedSubject(source: "medrxiv", slug: "forensic_medicine",                              displayName: "Forensic Medicine"),
    FeedSubject(source: "medrxiv", slug: "gastroenterology",                               displayName: "Gastroenterology"),
    FeedSubject(source: "medrxiv", slug: "genetic_and_genomic_medicine",                   displayName: "Genetic and Genomic Medicine"),
    FeedSubject(source: "medrxiv", slug: "geriatric_medicine",                             displayName: "Geriatric Medicine"),
    FeedSubject(source: "medrxiv", slug: "health_economics",                               displayName: "Health Economics"),
    FeedSubject(source: "medrxiv", slug: "health_informatics",                             displayName: "Health Informatics"),
    FeedSubject(source: "medrxiv", slug: "health_policy",                                  displayName: "Health Policy"),
    FeedSubject(source: "medrxiv", slug: "health_systems_and_quality_improvement",         displayName: "Health Systems and Quality Improvement"),
    FeedSubject(source: "medrxiv", slug: "hematology",                                     displayName: "Hematology"),
    FeedSubject(source: "medrxiv", slug: "hiv_aids",                                       displayName: "HIV / AIDS"),
    FeedSubject(source: "medrxiv", slug: "infectious_diseases",                            displayName: "Infectious Diseases"),
    FeedSubject(source: "medrxiv", slug: "intensive_care_and_critical_care_medicine",      displayName: "Intensive Care and Critical Care Medicine"),
    FeedSubject(source: "medrxiv", slug: "medical_education",                              displayName: "Medical Education"),
    FeedSubject(source: "medrxiv", slug: "medical_ethics",                                 displayName: "Medical Ethics"),
    FeedSubject(source: "medrxiv", slug: "nephrology",                                     displayName: "Nephrology"),
    FeedSubject(source: "medrxiv", slug: "neurology",                                      displayName: "Neurology"),
    FeedSubject(source: "medrxiv", slug: "nursing",                                        displayName: "Nursing"),
    FeedSubject(source: "medrxiv", slug: "nutrition",                                      displayName: "Nutrition"),
    FeedSubject(source: "medrxiv", slug: "obstetrics_and_gynecology",                      displayName: "Obstetrics and Gynecology"),
    FeedSubject(source: "medrxiv", slug: "occupational_and_environmental_health",          displayName: "Occupational and Environmental Health"),
    FeedSubject(source: "medrxiv", slug: "oncology",                                       displayName: "Oncology"),
    FeedSubject(source: "medrxiv", slug: "ophthalmology",                                  displayName: "Ophthalmology"),
    FeedSubject(source: "medrxiv", slug: "orthopedics",                                    displayName: "Orthopedics"),
    FeedSubject(source: "medrxiv", slug: "otolaryngology",                                 displayName: "Otolaryngology"),
    FeedSubject(source: "medrxiv", slug: "pain_medicine",                                  displayName: "Pain Medicine"),
    FeedSubject(source: "medrxiv", slug: "palliative_medicine",                            displayName: "Palliative Medicine"),
    FeedSubject(source: "medrxiv", slug: "pathology",                                      displayName: "Pathology"),
    FeedSubject(source: "medrxiv", slug: "pediatrics",                                     displayName: "Pediatrics"),
    FeedSubject(source: "medrxiv", slug: "pharmacology_and_therapeutics",                  displayName: "Pharmacology and Therapeutics"),
    FeedSubject(source: "medrxiv", slug: "primary_care_research",                          displayName: "Primary Care Research"),
    FeedSubject(source: "medrxiv", slug: "psychiatry_and_clinical_psychology",             displayName: "Psychiatry and Clinical Psychology"),
    FeedSubject(source: "medrxiv", slug: "public_and_global_health",                       displayName: "Public and Global Health"),
    FeedSubject(source: "medrxiv", slug: "radiology_and_imaging",                          displayName: "Radiology and Imaging"),
    FeedSubject(source: "medrxiv", slug: "rehabilitation_medicine_and_physical_therapy",   displayName: "Rehabilitation Medicine and Physical Therapy"),
    FeedSubject(source: "medrxiv", slug: "respiratory_medicine",                           displayName: "Respiratory Medicine"),
    FeedSubject(source: "medrxiv", slug: "rheumatology",                                   displayName: "Rheumatology"),
    FeedSubject(source: "medrxiv", slug: "sexual_and_reproductive_health",                 displayName: "Sexual and Reproductive Health"),
    FeedSubject(source: "medrxiv", slug: "sports_medicine",                                displayName: "Sports Medicine"),
    FeedSubject(source: "medrxiv", slug: "surgery",                                        displayName: "Surgery"),
    FeedSubject(source: "medrxiv", slug: "toxicology",                                     displayName: "Toxicology"),
    FeedSubject(source: "medrxiv", slug: "transplantation",                                displayName: "Transplantation"),
    FeedSubject(source: "medrxiv", slug: "urology",                                        displayName: "Urology"),
]

private let arxivSubjects: [FeedSubject] = [
    FeedSubject(source: "arxiv", slug: "cs.AI",    displayName: "CS — Artificial Intelligence"),
    FeedSubject(source: "arxiv", slug: "cs.LG",    displayName: "CS — Machine Learning"),
    FeedSubject(source: "arxiv", slug: "cs.CV",    displayName: "CS — Computer Vision"),
    FeedSubject(source: "arxiv", slug: "cs.CL",    displayName: "CS — Computation & Language"),
    FeedSubject(source: "arxiv", slug: "cs.NE",    displayName: "CS — Neural & Evolutionary Computing"),
    FeedSubject(source: "arxiv", slug: "math",     displayName: "Mathematics"),
    FeedSubject(source: "arxiv", slug: "cond-mat", displayName: "Physics — Condensed Matter"),
    FeedSubject(source: "arxiv", slug: "hep-ph",   displayName: "Physics — High Energy"),
    FeedSubject(source: "arxiv", slug: "quant-ph", displayName: "Physics — Quantum Physics"),
    FeedSubject(source: "arxiv", slug: "stat.ML",  displayName: "Statistics — ML"),
    FeedSubject(source: "arxiv", slug: "q-bio",    displayName: "Quantitative Biology"),
]

struct SettingsPage: View {
    var selectedSubjects: Set<String>
    var onToggle: (String) -> Void
    var onRefresh: () -> Void
    var isLoading: Bool

    // API keys are stored in the Keychain (not UserDefaults) for security.
    // @State is loaded once from Keychain in .onAppear; writes go back on .onChange.
    @State private var groqAPIKey: String = ""
    @State private var pubmedAPIKey: String = ""

    @AppStorage("filterKeywordsEnabled") private var filterEnabled: Bool = true
    @AppStorage("filterKeywordsRaw")     private var keywordsRaw: String = ""
    @AppStorage("articlesPerSubject")    private var articlesPerSubject: Int = 3
    @AppStorage("pubmedSearchesV2")      private var pubmedSearchesV2Raw: String = ""
    @AppStorage("pubmedSearchesRaw")     private var pubmedSearchesLegacyRaw: String = ""   // read-only for migration

    @State private var isKeyVisible: Bool = false
    @State private var newKeyword: String = ""
    @State private var newPubMedSearch: String = ""
    @State private var subjectSearch: String = ""

    // Returns only subjects whose display name matches the search string (or all if empty)
    private func filtered(_ subjects: [FeedSubject]) -> [FeedSubject] {
        guard !subjectSearch.isEmpty else { return subjects }
        return subjects.filter { $0.displayName.localizedCaseInsensitiveContains(subjectSearch) }
    }

    // Decode the stored JSON array, falling back to defaults on first launch
    private var keywords: [String] {
        guard !keywordsRaw.isEmpty,
              let decoded = try? JSONDecoder().decode([String].self, from: Data(keywordsRaw.utf8))
        else { return defaultKeywords }
        return decoded
    }

    private func saveKeywords(_ list: [String]) {
        if let data = try? JSONEncoder().encode(list),
           let str = String(data: data, encoding: .utf8) {
            keywordsRaw = str
        }
    }

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !keywords.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            newKeyword = ""
            return
        }
        saveKeywords(keywords + [trimmed])
        newKeyword = ""
    }

    private func removeKeyword(at offsets: IndexSet) {
        var list = keywords
        list.remove(atOffsets: offsets)
        saveKeywords(list)
    }

    // ── PubMed search helpers ──────────────────────────────────────────────

    /// Loads [PubMedSearch] from V2 storage, migrating from the old [String] format if needed.
    private var pubmedSearches: [PubMedSearch] {
        // V2 storage has data — decode it directly
        if !pubmedSearchesV2Raw.isEmpty,
           let decoded = try? JSONDecoder().decode([PubMedSearch].self, from: Data(pubmedSearchesV2Raw.utf8)) {
            return decoded
        }
        // V2 empty — try to migrate from legacy [String] storage
        if !pubmedSearchesLegacyRaw.isEmpty,
           let oldList = try? JSONDecoder().decode([String].self, from: Data(pubmedSearchesLegacyRaw.utf8)) {
            let migrated = oldList.map { PubMedSearch(query: $0) }
            savePubMedSearches(migrated)   // write into V2 so we only migrate once
            return migrated
        }
        return []
    }

    private func savePubMedSearches(_ list: [PubMedSearch]) {
        if let data = try? JSONEncoder().encode(list),
           let str = String(data: data, encoding: .utf8) {
            pubmedSearchesV2Raw = str
        }
    }

    private func addPubMedSearch() {
        let trimmed = newPubMedSearch.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !pubmedSearches.contains(where: { $0.query.lowercased() == trimmed.lowercased() }) else {
            newPubMedSearch = ""
            return
        }
        savePubMedSearches(pubmedSearches + [PubMedSearch(query: trimmed)])
        newPubMedSearch = ""
    }

    private func removePubMedSearch(at offsets: IndexSet) {
        var list = pubmedSearches
        list.remove(atOffsets: offsets)
        savePubMedSearches(list)
    }

    /// Returns a Binding to a single PubMedSearch that writes back to storage on change.
    private func bindingFor(index i: Int) -> Binding<PubMedSearch> {
        Binding(
            get: { pubmedSearches[i] },
            set: { updated in
                var list = pubmedSearches
                list[i] = updated
                savePubMedSearches(list)
            }
        )
    }

    // ── Refresh guard ──────────────────────────────────────────────────────

    private var canRefresh: Bool {
        let hasSource = !selectedSubjects.isEmpty || !pubmedSearches.isEmpty
        return hasAISummarization() && hasSource && !isLoading
    }

    var body: some View {
        NavigationView {
            List {
                // Note: API key state is loaded from Keychain in .onAppear below.

                // ── API Key ────────────────────────────────────────────────
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        if isKeyVisible {
                            TextField("gsk_...", text: $groqAPIKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("gsk_...", text: $groqAPIKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button(action: { isKeyVisible.toggle() }) {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    if groqAPIKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("No API key entered", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    } else {
                        Label("API key saved", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                } header: {
                    Text("Groq API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PubMinder uses Groq to summarize papers with AI. Groq is **free** — no credit card required.")
                        Text("1. Go to **console.groq.com** and sign up")
                        Text("2. Open **API Keys** → **Create API Key**")
                        Text("3. Paste the key (starts with gsk_) above")
                        if let url = URL(string: "https://console.groq.com") {
                            Link("Open console.groq.com →", destination: url)
                                .font(.footnote).padding(.top, 2)
                        }
                    }
                    .font(.footnote)
                }

                // ── Keyword filter ─────────────────────────────────────────
                Section {
                    Toggle("Filter articles by keywords", isOn: $filterEnabled)

                    if filterEnabled {
                        // Existing keywords (swipe-to-delete)
                        ForEach(keywords, id: \.self) { keyword in
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text(keyword)
                                    .foregroundColor(.primary)
                            }
                        }
                        .onDelete(perform: removeKeyword)

                        // Add new keyword
                        HStack {
                            TextField("Add keyword…", text: $newKeyword)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onSubmit { addKeyword() }
                            Button(action: addKeyword) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.blue.opacity(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1.0))
                            }
                            .buttonStyle(.plain)
                            .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        // Reset to defaults
                        Button("Reset to defaults") {
                            saveKeywords(defaultKeywords)
                        }
                        .foregroundStyle(.orange)
                        .font(.footnote)
                    }
                } header: {
                    Text("Keyword Filter")
                } footer: {
                    if filterEnabled {
                        Text("Only articles whose title or abstract contain at least one of these keywords will be fetched and summarized. Swipe left on a keyword to delete it. Tap the + to add your own.")
                    } else {
                        Text("Keyword filtering is off — all articles from selected subjects will be summarized (up to the Feed Size limit per subject).")
                    }
                }

                // ── Articles per subject ───────────────────────────────────
                Section {
                    Stepper(value: $articlesPerSubject, in: 1...20) {
                        HStack {
                            Text("Articles per subject")
                            Spacer()
                            Text("\(articlesPerSubject)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Feed Size")
                } footer: {
                    let total = selectedSubjects.isEmpty ? 0 : selectedSubjects.count * articlesPerSubject
                    if selectedSubjects.isEmpty {
                        Text("Select subjects below, then set how many articles to fetch per subject.")
                    } else {
                        Text("Up to \(articlesPerSubject) article\(articlesPerSubject == 1 ? "" : "s") × \(selectedSubjects.count) subject\(selectedSubjects.count == 1 ? "" : "s") = \(total) articles per refresh. Higher numbers take longer and use more API calls.")
                    }
                }

                // ── PubMed searches ────────────────────────────────────────
                Section {
                    // Saved searches with per-search filter pickers
                    ForEach(pubmedSearches.indices, id: \.self) { i in
                        PubMedSearchRow(search: bindingFor(index: i))
                    }
                    .onDelete(perform: removePubMedSearch)

                    // Add new search query
                    HStack {
                        TextField("e.g. CRISPR, genomics[MeSH] AND cancer", text: $newPubMedSearch)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { addPubMedSearch() }
                        Button(action: addPubMedSearch) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(
                                    newPubMedSearch.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.blue.opacity(0.3) : Color.blue
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(newPubMedSearch.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    // Optional NCBI API key (raises rate limit from 3 → 10 req/sec)
                    DisclosureGroup("NCBI API Key (optional)") {
                        TextField("Paste key here…", text: $pubmedAPIKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 2)
                        Text("Register free at ncbi.nlm.nih.gov/account to get a key. Without one, PubMed allows 3 requests/sec — plenty for personal use.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("PubMed Searches")
                } footer: {
                    Text("Enter keyword queries or MeSH terms. Use the date and type menus to narrow each search. Swipe left on a query to delete it.")
                        .font(.footnote)
                }

                // ── arXiv subjects ─────────────────────────────────────────
                subjectSection(
                    title: "arXiv Subjects",
                    footer: "Physics, mathematics, and computer science preprints from arxiv.org",
                    subjects: filtered(arxivSubjects)
                )

                // ── bioRxiv subjects ───────────────────────────────────────
                subjectSection(
                    title: "bioRxiv Subjects",
                    footer: "Biological and life science preprints from biorxiv.org",
                    subjects: filtered(bioRxivSubjects)
                )

                // ── medRxiv subjects ───────────────────────────────────────
                subjectSection(
                    title: "medRxiv Subjects",
                    footer: "Clinical and health science preprints from medrxiv.org",
                    subjects: filtered(medRxivSubjects)
                )

                // ── Refresh ────────────────────────────────────────────────
                Section {
                    Button(action: onRefresh) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().padding(.trailing, 8)
                                Text("Refreshing…").fontWeight(.semibold)
                            } else {
                                Image(systemName: "arrow.clockwise").fontWeight(.semibold)
                                Text("Refresh Feed").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .foregroundStyle(canRefresh ? Color.blue : Color.secondary)
                    }
                    .disabled(!canRefresh)
                } footer: {
                    if !hasAISummarization() {
                        Text("No AI configured. Add a Groq API key above, or use an Apple Intelligence-capable device (A17 Pro / A18 / M-series, iOS 26+).")
                    } else if selectedSubjects.isEmpty && pubmedSearches.isEmpty {
                        Text("Select subjects or add a PubMed search above.")
                    } else {
                        let subjectCount = selectedSubjects.count
                        let searchCount  = pubmedSearches.count
                        let parts = [
                            subjectCount > 0 ? "\(subjectCount) subject\(subjectCount == 1 ? "" : "s")" : nil,
                            searchCount  > 0 ? "\(searchCount) PubMed search\(searchCount == 1 ? "" : "es")" : nil
                        ].compactMap { $0 }.joined(separator: " · ")
                        Text(parts + " configured.")
                    }
                }
            }
            .searchable(text: $subjectSearch, prompt: "Search subjects…")
            .navigationTitle("Settings")
            // Load API keys from Keychain on first appear; migrate any legacy UserDefaults values.
            .onAppear {
                KeychainHelper.migrateFromUserDefaults(userDefaultsKey: "groqAPIKey",    keychainKey: "groqAPIKey")
                KeychainHelper.migrateFromUserDefaults(userDefaultsKey: "pubmedAPIKey",  keychainKey: "pubmedAPIKey")
                groqAPIKey   = KeychainHelper.load(forKey: "groqAPIKey")   ?? ""
                pubmedAPIKey = KeychainHelper.load(forKey: "pubmedAPIKey") ?? ""
            }
            // Persist changes back to Keychain whenever either field is edited.
            .onChange(of: groqAPIKey) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { KeychainHelper.delete(forKey: "groqAPIKey") }
                else               { KeychainHelper.save(trimmed, forKey: "groqAPIKey") }
            }
            .onChange(of: pubmedAPIKey) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { KeychainHelper.delete(forKey: "pubmedAPIKey") }
                else               { KeychainHelper.save(trimmed, forKey: "pubmedAPIKey") }
            }
        }
    }

    // Reusable section builder for a list of subjects
    @ViewBuilder
    private func subjectSection(title: String, footer: String, subjects: [FeedSubject]) -> some View {
        Section {
            ForEach(subjects) { subject in
                Button(action: { onToggle(subject.id) }) {
                    HStack {
                        Image(systemName: selectedSubjects.contains(subject.id)
                              ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selectedSubjects.contains(subject.id) ? .blue : .secondary)
                            .font(.system(size: 20))
                        Text(subject.displayName)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }
}

// MARK: - Per-search row with inline filter pickers

struct PubMedSearchRow: View {
    @Binding var search: PubMedSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Query text
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(search.query)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            // Filter chips — date range + article type
            HStack(spacing: 8) {
                // Date range picker
                Menu {
                    Picker("Date range", selection: $search.dateRange) {
                        ForEach(PubMedDateRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(search.dateRange.label)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Article type picker
                Menu {
                    Picker("Article type", selection: $search.articleType) {
                        ForEach(PubMedArticleType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text(search.articleType.label)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsPage(
        selectedSubjects: ["biorxiv:bioinformatics", "medrxiv:oncology"],
        onToggle: { _ in },
        onRefresh: {},
        isLoading: false
    )
}
