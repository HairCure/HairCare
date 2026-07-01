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
        // Data is fetched dynamically from backend
    }
    
    // MARK: - Load Content from Backend
    
    func loadContent(hairType: String? = nil) async {
        async let remoteTips     = BackendService.shared.fetchCareTips()
        async let remoteRemedies = BackendService.shared.fetchHomeRemedies()
        async let remoteRoutines = BackendService.shared.fetchHairCareRoutines()
        
        let (tips, remedies, routines) = await (remoteTips, remoteRemedies, remoteRoutines)
        
        await MainActor.run {
            if !tips.isEmpty { self.careTips = tips }
            if !remedies.isEmpty { self.homeRemedies = remedies }
            if !routines.isEmpty { self.hairCareRoutines = routines }
        }
        print("Loaded \(tips.count) tips, \(remedies.count) remedies, and \(routines.count) routines from backend")
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
    
    func toggleFavorite(contentId: UUID, userId: UUID, isGuest: Bool = false) {
        // Routines are read-only — do not allow favouriting them.
        guard !hairCareRoutines.contains(where: { $0.id == contentId }) else { return }
        
        if let idx = userFavorites.firstIndex(where: { $0.contentId == contentId }) {
            userFavorites.remove(at: idx)
            if !isGuest {
                Task {
                    await BackendService.shared.deleteFavourite(
                        userId: userId,
                        contentId: contentId
                    )
                }
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
            if !isGuest {
                Task {
                    await BackendService.shared.saveFavourite(
                        userId: userId,
                        contentId: contentId,
                        contentType: contentType
                    )
                }
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
