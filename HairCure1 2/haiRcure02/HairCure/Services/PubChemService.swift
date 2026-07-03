import Foundation

// MARK: - Cached Chemical Data
struct CachedChemical: Codable {
    let name: String
    let cid: Int?
    let signalWord: String?
    let ghsCodes: [String]
    let hazardStatements: [String]
}

// MARK: - PubChem API Service
actor PubChemService {
    static let shared = PubChemService()
    
    private var cache: [String: CachedChemical] = [:]
    private let cacheFileName = "pubchem_ingredient_cache.json"
    
    private var cacheFileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(cacheFileName)
    }
    
    private init() {
        // Load cache on initialization. Since loadCache is synchronous and executes on initialization, we can load it.
        // But loadCache() reads a file, which is quick. Let's do it safely.
        loadCache()
    }
    
    // MARK: - Cache Helpers
    
    private func loadCache() {
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoded = try JSONDecoder().decode([String: CachedChemical].self, from: data)
            self.cache = decoded
            print("PubChemService: Loaded \(decoded.count) ingredients from local cache.")
        } catch {
            print("PubChemService: Starting fresh, no local cache found.")
            self.cache = [:]
        }
    }
    
    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            print("PubChemService: Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Main API Entry Point
    
    /// Analyzes a raw ingredient name. Checks local cache first, otherwise queries PubChem.
    func analyzeIngredient(_ rawName: String, against scalp: ScalpCondition) async -> FlaggedIngredient {
        let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanName.isEmpty else {
            return FlaggedIngredient(
                name: rawName,
                cid: nil,
                rating: .safe,
                signalWord: nil,
                ghsCodes: [],
                hazardStatements: [],
                explanation: "Empty ingredient name.",
                researchLinks: []
            )
        }
        
        let chemical: CachedChemical
        if let cached = cache[cleanName] {
            chemical = cached
        } else {
            chemical = await fetchChemicalFromPubChem(cleanName: cleanName)
            cache[cleanName] = chemical
            saveCache()
        }
        
        return evaluateChemical(chemical, rawName: rawName, for: scalp)
    }
    
    // MARK: - PubChem API Client
    
    private func fetchChemicalFromPubChem(cleanName: String) async -> CachedChemical {
        guard let encodedName = cleanName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let cidUrl = URL(string: "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/\(encodedName)/cids/JSON") else {
            return CachedChemical(name: cleanName, cid: nil, signalWord: nil, ghsCodes: [], hazardStatements: [])
        }
        
        do {
            // Step 1: Find the Compound ID (CID)
            let (cidData, _) = try await URLSession.shared.data(from: cidUrl)
            struct CIDLookupResponse: Decodable {
                struct IdentifierList: Decodable {
                    let CID: [Int]?
                }
                let IdentifierList: IdentifierList?
            }
            
            let cidResponse = try JSONDecoder().decode(CIDLookupResponse.self, from: cidData)
            guard let cid = cidResponse.IdentifierList?.CID?.first else {
                return CachedChemical(name: cleanName, cid: nil, signalWord: nil, ghsCodes: [], hazardStatements: [])
            }
            
            // Step 2: Fetch GHS Classification
            guard let ghsUrl = URL(string: "https://pubchem.ncbi.nlm.nih.gov/rest/pug_view/data/compound/\(cid)/JSON?heading=GHS+Classification") else {
                return CachedChemical(name: cleanName, cid: cid, signalWord: nil, ghsCodes: [], hazardStatements: [])
            }
            
            let (ghsData, _) = try await URLSession.shared.data(from: ghsUrl)
            
            // Decodable models to parse hierarchical JSON
            struct PubChemRecordResponse: Decodable {
                let Record: RecordData?
            }
            struct RecordData: Decodable {
                let Section: [SectionData]?
            }
            struct SectionData: Decodable {
                let TOCHeading: String?
                let Section: [SectionData]?
                let Information: [InformationData]?
            }
            struct InformationData: Decodable {
                let Name: String?
                let Value: ValueData?
            }
            struct ValueData: Decodable {
                let StringWithMarkup: [StringWithMarkupData]?
            }
            struct StringWithMarkupData: Decodable {
                let String: String?
            }
            
            let recordResponse = try JSONDecoder().decode(PubChemRecordResponse.self, from: ghsData)
            
            // Helper to recursively find the section with TOCHeading "GHS Classification"
            func findGHSSection(sections: [SectionData]) -> SectionData? {
                for s in sections {
                    if s.TOCHeading == "GHS Classification" {
                        return s
                    }
                    if let nested = s.Section, let found = findGHSSection(sections: nested) {
                        return found
                    }
                }
                return nil
            }
            
            var signalWord: String? = nil
            var ghsCodes: [String] = []
            var hazardStatements: [String] = []
            
            if let rootSections = recordResponse.Record?.Section,
               let ghsSection = findGHSSection(sections: rootSections),
               let informationList = ghsSection.Information {
                
                for info in informationList {
                    if info.Name == "Signal", let markup = info.Value?.StringWithMarkup?.first?.String {
                        signalWord = markup.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    if info.Name == "GHS Hazard Statements", let markupList = info.Value?.StringWithMarkup {
                        for markup in markupList {
                            if let statement = markup.String {
                                // e.g. "H315 (100%): Causes skin irritation..."
                                let parts = statement.components(separatedBy: ":")
                                if parts.count >= 2 {
                                    let codePart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                                    let statementPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    if let code = codePart.components(separatedBy: " ").first, code.hasPrefix("H") {
                                        ghsCodes.append(code)
                                        let cleanStatement = statementPart.components(separatedBy: "[").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? statementPart
                                        hazardStatements.append("\(code): \(cleanStatement)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            return CachedChemical(
                name: cleanName,
                cid: cid,
                signalWord: signalWord,
                ghsCodes: Array(Set(ghsCodes)),
                hazardStatements: Array(Set(hazardStatements))
            )
            
        } catch {
            print("PubChemService: Error looking up '\(cleanName)': \(error.localizedDescription)")
            return CachedChemical(name: cleanName, cid: nil, signalWord: nil, ghsCodes: [], hazardStatements: [])
        }
    }
    
    // MARK: - Scalp Hazard Evaluation
    
    private func evaluateChemical(_ chemical: CachedChemical, rawName: String, for scalp: ScalpCondition) -> FlaggedIngredient {
        var rating = CompatibilityRating.safe
        var explanation = "This ingredient was checked in the NIH PubChem database and has no registered hazard codes for scalp skin contact."
        
        let codes = chemical.ghsCodes
        
        // Critical skin sensitizers/severe irritants:
        // H314 (skin burns), H317 (allergic skin reaction), H318 (serious eye damage), H340/H350/H360 (mutagen/carcinogen/repro toxicity)
        let severeCodes = ["H314", "H317", "H318", "H340", "H350", "H360"]
        let hasSevere = codes.contains(where: { code in severeCodes.contains(code) })
        
        // Moderate skin/eye irritants: H315 (skin irritation), H319 (serious eye irritation)
        let irritantCodes = ["H315", "H319"]
        let hasIrritant = codes.contains(where: { code in irritantCodes.contains(code) })
        
        // Mild warnings: H335 (respiratory irritation)
        let hasMild = codes.contains(where: { code in code == "H335" })
        
        if hasSevere {
            switch scalp {
            case .normal, .notAssessed:
                rating = .caution
                explanation = "NIH PubChem GHS registers severe contact alert codes (like skin sensitizer or damage warnings). Use with caution."
            default:
                rating = .hazard
                explanation = "NIH PubChem GHS flags this chemical as a severe contact hazard/allergen, which is unsafe for your \(scalp.rawValue) scalp."
            }
        } else if hasIrritant {
            switch scalp {
            case .dry, .inflamed:
                rating = .hazard
                explanation = "NIH PubChem GHS flags this as a skin irritant, which is highly likely to worsen your dry or inflamed scalp."
            default:
                rating = .caution
                explanation = "NIH PubChem GHS flags this as a skin/eye irritant. Recommended to monitor scalp reaction."
            }
        } else if hasMild {
            rating = .caution
            explanation = "NIH PubChem GHS flags this compound with mild hazard warning notices."
        }
        
        var links: [ResearchLink] = []
        if let cid = chemical.cid {
            links.append(ResearchLink(source: "NIH PubChem Info", url: "https://pubchem.ncbi.nlm.nih.gov/compound/\(cid)"))
            links.append(ResearchLink(source: "NIH GHS Classification", url: "https://pubchem.ncbi.nlm.nih.gov/compound/\(cid)#section=GHS-Classification"))
        }
        
        return FlaggedIngredient(
            name: rawName,
            cid: chemical.cid,
            rating: rating,
            signalWord: chemical.signalWord,
            ghsCodes: chemical.ghsCodes,
            hazardStatements: chemical.hazardStatements,
            explanation: explanation,
            researchLinks: links
        )
    }
}
