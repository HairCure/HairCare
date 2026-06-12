import Foundation
import Observation

// MARK: - HairInsightsDataStore

@Observable
class HairInsightsDataStore {
    
    // MARK: - Properties
    
    var careTips: [CareTip]              = []
    var homeRemedies: [HomeRemedy]       = []
    var hairCareRoutines: [HairCareRoutine] = []
    var userFavorites: [UserFavorite]    = []
    
    // MARK: - Init
    
    init() {
        seedCareTips()
        seedRemedies()
        seedRoutines()
    }
    
    // MARK: - Load Content from Backend
    
    func loadContent(hairType: String? = nil) async {
        async let remoteTips     = BackendService.shared.fetchCareTips()
        async let remoteRemedies = BackendService.shared.fetchHomeRemedies()
        
        let (tips, remedies) = await (remoteTips, remoteRemedies)
        
        await MainActor.run {
            if !tips.isEmpty     { self.careTips = tips }
            if !remedies.isEmpty { self.homeRemedies = remedies }
            // hairCareRoutines intentionally uses seed data — the DB may have
            // stale rows. Seed contains all 7 routines with correct hair_types.
        }
        print("Loaded \(tips.count) tips, \(remedies.count) remedies from backend | routines from seed (\(self.hairCareRoutines.count))")
    }
    
    // MARK: - Personalised Content Filters

    /// Returns routines matching the user's AI-detected hair type.
    /// Empty hairTypes array = universal (shown to all).
    func filteredRoutines(for hairType: String?) -> [HairCareRoutine] {
        let active = hairCareRoutines.filter(\.isActive)
        guard let ht = hairType?.lowercased().trimmingCharacters(in: .whitespaces),
              !ht.isEmpty else { return active }
        return active.filter { r in
            r.hairTypes.isEmpty || r.hairTypes.contains(where: { $0.lowercased() == ht })
        }
    }

    /// Returns care tips personalised for the given hair type.
    func filteredCareTips(for hairType: String?) -> [CareTip] {
        let active = careTips.filter(\.isActive)
        guard let ht = hairType?.lowercased().trimmingCharacters(in: .whitespaces),
              !ht.isEmpty else { return active }
        return active.filter { t in
            t.hairTypes.isEmpty || t.hairTypes.contains(where: { $0.lowercased() == ht })
        }
    }

    /// Returns home remedies personalised for the given hair type.
    func filteredHomeRemedies(for hairType: String?) -> [HomeRemedy] {
        let active = homeRemedies.filter(\.isActive)
        guard let ht = hairType?.lowercased().trimmingCharacters(in: .whitespaces),
              !ht.isEmpty else { return active }
        return active.filter { r in
            r.hairTypes.isEmpty || r.hairTypes.contains(where: { $0.lowercased() == ht })
        }
    }
    
    // MARK: - Favourite Helpers
    
    func isFavorite(contentId: UUID) -> Bool {
        userFavorites.contains { $0.contentId == contentId }
    }
    
    var userId: UUID = UUID()
    
    func toggleFavorite(contentId: UUID, userId: UUID) {
        // Routines are read-only — do not allow favouriting them.
        guard !hairCareRoutines.contains(where: { $0.id == contentId }) else { return }
        
        if let idx = userFavorites.firstIndex(where: { $0.contentId == contentId }) {
            userFavorites.remove(at: idx)
            Task {
                await BackendService.shared.deleteFavourite(
                    userId: userId,
                    contentId: contentId
                )
            }
        } else {
            let contentType: String
            if careTips.contains(where: { $0.id == contentId }) {
                contentType = "care_tip"
            } else if homeRemedies.contains(where: { $0.id == contentId }) {
                contentType = "home_remedy"
            } else {
                contentType = "hair_care_routine"
            }
            
            userFavorites.append(UserFavorite(
                id: UUID(),
                contentId: contentId,
                savedAt: Date()
            ))
            Task {
                await BackendService.shared.saveFavourite(
                    userId: userId,
                    contentId: contentId,
                    contentType: contentType
                )
            }
        }
    }
    
    func loadFavourites(userId: UUID) async {
        let rows = await BackendService.shared.fetchFavourites(userId: userId)
        await MainActor.run {
            self.userFavorites = rows.map { row in
                UserFavorite(
                    id: UUID(),
                    contentId: row.contentId,
                    savedAt: row.savedAt
                )
            }
        }
        print("Loaded \(rows.count) favourites")
    }
    
    // Deprecated stub kept for binary compatibility — use filteredCareTips(for:) instead
    func personalizedTips(for hairType: String) -> [CareTip] {
        return filteredCareTips(for: hairType)
    }
    
    // MARK: - Favourited Content Resolvers
    
    func favouritedCareTips() -> [CareTip] {
        let ids = userFavorites
            .sorted { $0.savedAt > $1.savedAt }
            .map(\.contentId)
        return ids.compactMap { id in careTips.first { $0.id == id } }
    }
    
    func favouritedHomeRemedies() -> [HomeRemedy] {
        let ids = userFavorites
            .sorted { $0.savedAt > $1.savedAt }
            .map(\.contentId)
        return ids.compactMap { id in homeRemedies.first { $0.id == id } }
    }
    
    func favouritedHairCareRoutines() -> [HairCareRoutine] {
        let ids = userFavorites
            .sorted { $0.savedAt > $1.savedAt }
            .map(\.contentId)
        return ids.compactMap { id in hairCareRoutines.first { $0.id == id } }
    }
    
    func allFavourites() -> [AnyFavouriteItem] {
        let tips     = favouritedCareTips().map    { AnyFavouriteItem.careTip($0) }
        let remedies = favouritedHomeRemedies().map { AnyFavouriteItem.remedy($0) }
        // Routines are intentionally excluded — read-only content, not favouritable.
        return tips + remedies
    }
    
    // MARK: - Fallback Seed Data (stable UUIDs for offline use)
    
    private func seedCareTips() {
        careTips = [
            // Universal
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000001")!,
                title: "Oil Massage",
                tipDescription: "A warm oil massage before washing increases blood flow to hair follicles, promoting growth and reducing shedding.",
                mediaURL: nil,
                steps: [
                    "Warm 2–3 tbsp of coconut, castor, or bhringraj oil until lukewarm.",
                    "Part your hair into sections to expose the scalp.",
                    "Apply oil to the scalp using fingertips.",
                    "Massage in circular motions for 5–10 minutes.",
                    "Leave on for at least 30 minutes, then wash off with mild shampoo."
                ],
                frequency: "2× per week",
                precautions: "Use lukewarm oil, not hot. Avoid if scalp is inflamed.",
                researchURL: "https://pmc.ncbi.nlm.nih.gov/articles/PMC4740347/",
                hairTypes: [],
                isActive: true
            ),
            // Universal
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000002")!,
                title: "Silk Pillowcase",
                tipDescription: "Sleeping on silk reduces friction and prevents hair breakage and split ends overnight.",
                mediaURL: nil,
                steps: [
                    "Replace your cotton pillowcase with a 100% mulberry silk pillowcase.",
                    "Loosely braid or tie hair in a low ponytail before sleeping.",
                    "Wash the silk pillowcase weekly with gentle detergent."
                ],
                frequency: "Every night",
                precautions: nil,
                researchURL: "https://www.triprinceton.org/post/everyone-is-talking-about-silk-pillowcases",
                hairTypes: [],
                isActive: true
            ),
            // Straight + Wavy
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000003")!,
                title: "Cold Water Rinse",
                tipDescription: "Finishing your wash with cold water seals the hair cuticle for added shine and less frizz.",
                mediaURL: nil,
                steps: [
                    "Wash hair with your regular shampoo and conditioner using warm water.",
                    "Rinse out the conditioner completely with warm water first.",
                    "Switch to the coldest water setting you can tolerate.",
                    "Rinse hair for 30–60 seconds to close the cuticle."
                ],
                frequency: "Every wash",
                precautions: "Not recommended in very cold weather.",
                researchURL: "https://www.hims.com/blog/is-cold-water-good-for-hair",
                hairTypes: ["straight", "wavy"],
                isActive: true
            ),
            // Universal
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000004")!,
                title: "Scalp Massage",
                tipDescription: "A 5-minute daily scalp massage stimulates follicles and may increase hair thickness over time.",
                mediaURL: nil,
                steps: [
                    "Sit comfortably and relax your shoulders.",
                    "Place fingertips (not nails) on the scalp at the temples.",
                    "Apply gentle pressure and move in small, slow circles.",
                    "Work across the entire scalp — sides, crown, and nape — for 5 minutes.",
                    "Use a scalp massager tool for extra stimulation if preferred."
                ],
                frequency: "Daily",
                precautions: "Use gentle pressure. Avoid scratching the scalp.",
                researchURL: "https://pmc.ncbi.nlm.nih.gov/articles/PMC4740347/",
                hairTypes: [],
                isActive: true
            ),
            // Curly + Coily
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000005")!,
                title: "Finger Detangling",
                tipDescription: "Use fingers instead of a brush on dry curly or coily hair to prevent breakage along the curl pattern.",
                mediaURL: nil,
                steps: [
                    "Apply a leave-in conditioner or detangling spray to damp hair.",
                    "Work in sections, starting from the ends and moving upward.",
                    "Gently separate knots with your fingers — never pull.",
                    "Follow with a wide-tooth comb only if needed."
                ],
                frequency: "Every wash day",
                precautions: "Never detangle dry curly or coily hair — it causes breakage.",
                researchURL: nil,
                hairTypes: ["curly", "coily"],
                isActive: true
            ),
            // Straight + Wavy
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000006")!,
                title: "Heat Protectant Before Styling",
                tipDescription: "Always apply a thermal protectant before using a flat iron or blow dryer to prevent structural hair damage above 150 °C.",
                mediaURL: nil,
                steps: [
                    "Towel-dry hair until 70–80% dry — not dripping.",
                    "Spray or apply heat protectant 15–20 cm away, focusing on mid-lengths and ends.",
                    "Comb through to distribute evenly.",
                    "Wait 1–2 minutes before using any heat tool."
                ],
                frequency: "Every time a heat tool is used",
                precautions: "Do not skip on low heat settings — damage still occurs.",
                researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4387693/",
                hairTypes: ["straight", "wavy"],
                isActive: true
            ),
            // Curly + Coily
            CareTip(
                id: UUID(uuidString: "a1b2c3d4-0001-0001-0001-000000000007")!,
                title: "Pineapple Hair at Night",
                tipDescription: "Loosely gathering curls at the top of the head (pineapple) before bed protects the curl pattern and reduces morning frizz.",
                mediaURL: nil,
                steps: [
                    "Flip hair upside down and gather all curls at the very top of the head.",
                    "Secure loosely with a satin scrunchie — never a tight elastic.",
                    "Sleep on a satin pillowcase for extra protection.",
                    "Release in the morning and scrunch lightly to refresh curls."
                ],
                frequency: "Every night",
                precautions: "Keep the band very loose to avoid a crease at the roots.",
                researchURL: nil,
                hairTypes: ["curly", "coily"],
                isActive: true
            ),
        ]
    }
    
    private func seedRemedies() {
        homeRemedies = [
            // Universal (good for all hair types)
            HomeRemedy(
                id: UUID(uuidString: "b2c3d4e5-0002-0002-0002-000000000001")!,
                title: "Aloe Vera Scalp Mask",
                remedyDescription: "A soothing natural mask to hydrate the scalp and calm irritation using fresh aloe vera gel.",
                mediaURL: nil,
                videoDurationSeconds: 120,
                videoURL: nil,
                ingredients: ["4–5 tbsp fresh aloe vera gel", "2–3 drops tea tree essential oil"],
                steps: [
                    "Scoop fresh aloe vera gel into a bowl.",
                    "Add 2–3 drops of tea tree oil and mix well.",
                    "Do a patch test behind the ear — wait 10 minutes.",
                    "Apply directly to scalp in sections, massage gently for 2–3 minutes.",
                    "Leave on for 20–30 minutes.",
                    "Rinse thoroughly with lukewarm water."
                ],
                benefits: "Soothes itchy scalp, reduces dandruff, balances pH, and hydrates the hair shaft.",
                frequency: "1–2 times per week",
                precautions: "Always patch-test first. Rinse completely — residue causes white flaking.",
                researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4158629/",
                hairTypes: [],
                isActive: true
            ),
            // Universal
            HomeRemedy(
                id: UUID(uuidString: "b2c3d4e5-0002-0002-0002-000000000002")!,
                title: "Onion Juice Massage",
                remedyDescription: "Sulphur-rich onion juice boosts collagen production and reduces hair thinning.",
                mediaURL: nil,
                videoDurationSeconds: 105,
                videoURL: nil,
                ingredients: ["2 medium onions", "Strainer or cheesecloth"],
                steps: [
                    "Peel and chop 2 onions.",
                    "Blend until smooth.",
                    "Strain the juice using cheesecloth.",
                    "Apply juice directly to scalp.",
                    "Leave for 15 minutes.",
                    "Wash off thoroughly with shampoo."
                ],
                benefits: "Rich in sulphur which boosts collagen production and reduces hair thinning.",
                frequency: "2× per week",
                precautions: "Strong smell — rinse thoroughly. Avoid if you have scalp wounds.",
                researchURL: "https://pubmed.ncbi.nlm.nih.gov/12126069/",
                hairTypes: [],
                isActive: true
            ),
            // Straight + Wavy (protein treatment)
            HomeRemedy(
                id: UUID(uuidString: "b2c3d4e5-0002-0002-0002-000000000003")!,
                title: "Egg & Honey Protein Mask",
                remedyDescription: "A protein-packed DIY mask to strengthen the hair shaft, reduce breakage, and add volume.",
                mediaURL: nil,
                videoDurationSeconds: 150,
                videoURL: nil,
                ingredients: ["2 whole eggs", "2 tbsp raw honey", "1 tbsp olive oil"],
                steps: [
                    "Whisk eggs with honey and olive oil until smooth.",
                    "Lightly mist hair with water — do not soak.",
                    "Apply from roots to tips in sections.",
                    "Leave for 20–30 minutes under a shower cap.",
                    "Rinse with COOL water only — hot water cooks the egg.",
                    "Follow with a moisturising conditioner."
                ],
                benefits: "Fills damaged cuticle gaps, improves tensile strength, reduces breakage, adds shine.",
                frequency: "Once every 2–3 weeks",
                precautions: "ALWAYS rinse with cool water. Avoid if you have egg allergies. Overuse causes brittleness.",
                researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6164340/",
                hairTypes: ["straight", "wavy"],
                isActive: true
            ),
            // Dry + Coily + Curly
            HomeRemedy(
                id: UUID(uuidString: "b2c3d4e5-0002-0002-0002-000000000004")!,
                title: "Coconut Oil Pre-Wash",
                remedyDescription: "Pre-wash coconut oil penetrates the hair shaft to reduce protein loss and deeply moisturise.",
                mediaURL: nil,
                videoDurationSeconds: nil,
                videoURL: nil,
                ingredients: ["2–3 tbsp virgin coconut oil", "3–4 drops rosemary essential oil (optional)"],
                steps: [
                    "Melt coconut oil in a warm water bath if solid.",
                    "Mix in rosemary oil if using.",
                    "Apply from ends upward, then lightly coat the scalp.",
                    "Massage scalp for 3–4 minutes.",
                    "Cover with a shower cap for 30–60 minutes (or overnight).",
                    "Shampoo twice to remove all residue."
                ],
                benefits: "Reduces protein loss during washing, deeply moisturises the cortex, adds natural lustre.",
                frequency: "Once a week",
                precautions: "Can cause buildup on fine/low-porosity hair. Use clarifying shampoo monthly if hair feels heavy.",
                researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4387693/",
                hairTypes: ["curly", "coily"],
                isActive: true
            ),
            // Wavy + Straight
            HomeRemedy(
                id: UUID(uuidString: "b2c3d4e5-0002-0002-0002-000000000005")!,
                title: "Green Tea Scalp Rinse",
                remedyDescription: "A light antioxidant rinse that reduces excess oil and scalp inflammation without stripping moisture.",
                mediaURL: nil,
                videoDurationSeconds: nil,
                videoURL: nil,
                ingredients: ["2 green tea bags", "2 cups hot water", "1 tsp apple cider vinegar (optional)"],
                steps: [
                    "Steep 2 green tea bags in 2 cups hot water for 5 minutes. Let cool.",
                    "Add apple cider vinegar if using and stir.",
                    "After shampooing, pour the tea rinse over your scalp and hair.",
                    "Massage gently for 2 minutes.",
                    "Leave on for 5 minutes, then rinse with cool water."
                ],
                benefits: "Reduces scalp inflammation, controls excess oil, and adds a subtle shine.",
                frequency: "Once a week",
                precautions: "Avoid undiluted apple cider vinegar on a sensitive scalp.",
                researchURL: nil,
                hairTypes: ["straight", "wavy"],
                isActive: true
            ),
        ]
    }
    
    private func seedRoutines() {
        hairCareRoutines = [
            
            // ── Universal (all hair types) ──
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000001")!,
                cardHeading: "Balanced Wash Routine",
                applyingFrequency: "Every 2–3 days",
                summary: "Use a mild, pH-balanced shampoo to maintain your scalp's healthy oil levels and keep follicles clean.",
                benefits: "Maintains natural oil balance, prevents buildup, keeps hair healthy and clean.",
                steps: [
                    "Wet hair thoroughly with lukewarm water.",
                    "Apply a small amount of sulphate-free shampoo.",
                    "Massage scalp gently for 2 minutes.",
                    "Rinse completely and follow with conditioner on ends only."
                ],
                precautions: "Avoid hot water — it strips natural oils.",
                researchURL: nil,
                hairTypes: [],          // universal
                isActive: true
            ),
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000002")!,
                cardHeading: "Nourishing Oil Pre-Wash",
                applyingFrequency: "1–2× per week",
                summary: "Coconut or bhringraj oil pre-wash to maintain follicle strength and support healthy hair growth cycles.",
                benefits: "Strengthens hair roots, reduces breakage, promotes growth.",
                steps: [
                    "Warm coconut or bhringraj oil slightly.",
                    "Part hair into sections.",
                    "Apply oil to scalp and massage for 5 minutes.",
                    "Leave for at least 30 minutes or overnight.",
                    "Wash with mild shampoo."
                ],
                precautions: "Don't apply too much — a little goes a long way.",
                researchURL: nil,
                hairTypes: [],          // universal
                isActive: true
            ),
            
            // ── Curly hair ──
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000003")!,
                cardHeading: "Curl-Defining Deep Condition",
                applyingFrequency: "Once a week",
                summary: "Hydrate and define curls with a rich deep conditioner, keeping curls bouncy and frizz-free.",
                benefits: "Restores moisture, reduces frizz, and enhances curl definition.",
                steps: [
                    "Shampoo with a sulphate-free cleanser.",
                    "Apply a generous amount of deep conditioner from mid-length to ends.",
                    "Cover with a shower cap and leave for 20–30 minutes.",
                    "Rinse with cool water.",
                    "Apply leave-in conditioner and scrunch out curls while damp."
                ],
                precautions: "Avoid combing curls when dry — use a wide-tooth comb on wet, conditioned hair only.",
                researchURL: nil,
                hairTypes: ["curly"],
                isActive: true
            ),
            
            // ── Coily hair ──
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000004")!,
                cardHeading: "LOC Method Moisture Lock",
                applyingFrequency: "Every wash day",
                summary: "Lock in moisture with the LOC (Liquid–Oil–Cream) method to keep coily strands hydrated for days.",
                benefits: "Long-lasting hydration, reduced shrinkage, and improved elasticity.",
                steps: [
                    "Apply a water-based leave-in conditioner to damp hair (Liquid).",
                    "Seal with a lightweight oil like jojoba or castor oil (Oil).",
                    "Smooth over a shea butter or curl cream to lock moisture in (Cream).",
                    "Stretch or twist hair and let air-dry to reduce shrinkage."
                ],
                precautions: "Use products in thin layers to avoid buildup on dense coils.",
                researchURL: nil,
                hairTypes: ["coily"],
                isActive: true
            ),
            
            // ── Wavy hair ──
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000005")!,
                cardHeading: "Wavy Hair Enhancing Routine",
                applyingFrequency: "Every 2–3 days",
                summary: "Enhance natural waves while controlling frizz using lightweight products that won't weigh hair down.",
                benefits: "Defined waves, reduced frizz, and light hold without stiffness.",
                steps: [
                    "Wash with a lightweight, sulphate-free shampoo.",
                    "Apply a light conditioner from mid-length to ends.",
                    "Rinse, then scrunch hair gently with a microfibre towel.",
                    "Apply a wave-enhancing mousse or gel while hair is soaking wet.",
                    "Scrunch upward to encourage the wave pattern and diffuse or air-dry."
                ],
                precautions: "Avoid heavy creams — they can flatten waves.",
                researchURL: nil,
                hairTypes: ["wavy"],
                isActive: true
            ),
            
            // ── Straight hair ──
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000006")!,
                cardHeading: "Smooth & Shine Routine",
                applyingFrequency: "Every 2–3 days",
                summary: "Keep straight hair sleek, shiny, and free of oil buildup with regular cleansing and lightweight conditioning.",
                benefits: "Reduces oiliness, adds shine, and keeps hair healthy and smooth.",
                steps: [
                    "Wet hair and apply a clarifying shampoo to the scalp only.",
                    "Massage and rinse thoroughly — avoid rough rubbing.",
                    "Apply a lightweight conditioner to ends only.",
                    "Rinse with cool water to seal the cuticle.",
                    "Pat dry gently and apply a heat protectant before styling."
                ],
                precautions: "Don't over-condition the scalp — straight hair is prone to greasiness.",
                researchURL: nil,
                hairTypes: ["straight"],
                isActive: true
            ),
            
            // ── Coily hair ──
            HairCareRoutine(
                id: UUID(uuidString: "c3d4e5f6-0003-0003-0003-000000000007")!,
                cardHeading: "Moisture-First Wash Day",
                applyingFrequency: "Once a week",
                summary: "Coily hair craves moisture. A co-wash followed by deep conditioning restores hydration and reduces shrinkage.",
                benefits: "Maximises moisture retention, minimises breakage, and keeps coils defined.",
                steps: [
                    "Pre-poo with an oil or conditioner for 20 minutes to protect strands.",
                    "Co-wash with a cleansing conditioner or mild shampoo.",
                    "Section hair into 4 parts and apply deep conditioner generously.",
                    "Leave under a heat cap for 30 minutes, then rinse with cool water.",
                    "Apply leave-in conditioner and seal with a butter or oil."
                ],
                precautions: "Detangle only with a wide-tooth comb on wet, conditioned hair.",
                researchURL: nil,
                hairTypes: ["coily"],
                isActive: true
            ),
        ]
    }
}

// MARK: - AnyFavouriteItem

enum AnyFavouriteItem: Identifiable {
    case careTip(CareTip)
    case remedy(HomeRemedy)
    case routine(HairCareRoutine)
    
    var id: UUID {
        switch self {
        case .careTip(let t): return t.id
        case .remedy(let r):  return r.id
        case .routine(let r): return r.id
        }
    }
    
    var title: String {
        switch self {
        case .careTip(let t): return t.title
        case .remedy(let r):  return r.title
        case .routine(let r): return r.cardHeading
        }
    }
    
    var mediaURL: String? {
        switch self {
        case .careTip(let t): return t.mediaURL
        case .remedy(let r):  return r.mediaURL
        case .routine:        return nil
        }
    }
}

#if DEBUG
extension HairInsightsDataStore {
    static func mock() -> HairInsightsDataStore {
        return HairInsightsDataStore()
    }
}
#endif
