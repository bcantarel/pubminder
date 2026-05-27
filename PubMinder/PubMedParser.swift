import Foundation

// A single parsed article record from the PubMed efetch XML response.
struct PubMedRecord {
    let pmid:     String
    let title:    String
    let abstract: String
    let doi:      String  // empty when the article has no DOI in ArticleIdList
}

// SAX-style XML parser for NCBI efetch responses (retmode=xml).
//
// Handles the two most common abstract structures:
//   • Single <AbstractText>: whole text in one element
//   • Structured <AbstractText Label="BACKGROUND">...<AbstractText Label="METHODS">...:
//     sections are concatenated with their labels, e.g. "BACKGROUND: … METHODS: …"
//
// Uses collecting flags rather than tracking currentElement so that nested
// formatting elements (<i>, <sub>, <sup>, <b>) don't lose surrounding text.
final class PubMedXMLParser: NSObject, XMLParserDelegate {

    private(set) var records: [PubMedRecord] = []

    // Per-article accumulators
    private var pmid     = ""
    private var title    = ""
    private var abstract = ""
    private var doi      = ""

    // Collecting flags (set on element open, cleared on close)
    private var collectingPMID     = false
    private var collectingTitle    = false
    private var collectingAbstract = false
    private var collectingDOI      = false
    private var currentIdType      = ""

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {

        switch elementName {

        case "PubmedArticle":
            // Reset all accumulators for the new article
            pmid = ""; title = ""; abstract = ""; doi = ""

        case "PMID":
            // <PMID> appears again inside <ArticleIdList> — only capture the first one
            if pmid.isEmpty { collectingPMID = true }

        case "ArticleTitle":
            collectingTitle = true

        case "AbstractText":
            // Insert label prefix (BACKGROUND, METHODS, etc.) before each section
            if !abstract.isEmpty { abstract += " " }
            if let label = attributeDict["Label"], !label.isEmpty {
                abstract += "\(label): "
            }
            collectingAbstract = true

        case "ArticleId":
            currentIdType = attributeDict["IdType"] ?? ""
            if currentIdType == "doi" { collectingDOI = true }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collectingPMID     { pmid     += string }
        if collectingTitle    { title    += string }
        if collectingAbstract { abstract += string }
        if collectingDOI      { doi      += string }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {

        switch elementName {

        case "PMID":
            collectingPMID = false

        case "ArticleTitle":
            collectingTitle = false

        case "AbstractText":
            collectingAbstract = false

        case "ArticleId":
            collectingDOI = false
            currentIdType = ""

        case "PubmedArticle":
            guard !pmid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            records.append(PubMedRecord(
                pmid:     pmid.trimmingCharacters(in: .whitespacesAndNewlines),
                title:    title.trimmingCharacters(in: .whitespacesAndNewlines),
                abstract: abstract.trimmingCharacters(in: .whitespacesAndNewlines),
                doi:      doi.trimmingCharacters(in: .whitespacesAndNewlines)
            ))

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("PubMed XML parse error: \(parseError.localizedDescription)")
    }
}
