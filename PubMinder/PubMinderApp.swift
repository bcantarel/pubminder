//
//  PubMinderApp.swift
//  PubMinder
//
//  Created by Brandi Cantarel on 10/27/24.
//

import SwiftUI

@main
struct PubMinderApp: App {
    @State private var selectedSubject: String = "bioinformatics"
    @State private var summary: String = ""

    var body: some Scene {
        WindowGroup {
            VStack {
                ListOfThings(selectedSubject: $selectedSubject)
                    .onAppear {
                        if !selectedSubject.isEmpty {
                            loadSummary(for: selectedSubject)
                        }
                    }
                ContentView(selectedSubject: $selectedSubject, summary: $summary)
            }
        }
    }

    private func loadSummary(for subject: String) {
        let baseURL = "http://connect.biorxiv.org/biorxiv_xml.php?subject="
        let feedURL = baseURL + subject
        
        fetchAndSummarizeRSSFeed(feedURL: feedURL) { info in
            guard let info = info else {
                print("An error occurred while generating the summary.")
                return
            }
            DispatchQueue.main.async {
                // Update the summary state on the main thread
                self.summary = info
                print("Summary fetched: \(info)")
            }
        }
    }
}

struct PubMinderApp_Preview: View {
    @State private var selectedSubject: String = "bioinformatics"
    @State private var summary: String = "This is a sample summary for previewing purposes."

    var body: some View {
        VStack {
            ListOfThings(selectedSubject: $selectedSubject)
            ContentView(selectedSubject: $selectedSubject, summary: $summary)
        }
    }
}

struct PubMinderApp_Previews: PreviewProvider {
    static var previews: some View {
        PubMinderApp_Preview()
    }
}
