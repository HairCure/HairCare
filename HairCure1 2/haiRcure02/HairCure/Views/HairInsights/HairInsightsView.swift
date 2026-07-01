
import SwiftUI

// MARK: - HairInsightsView

struct HairInsightsView: View {
    
    @Environment(AppDataStore.self)  private var store
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var routineScrollPosition = ScrollPosition(idType: Int.self)
    
    @State private var pushGuestGate  = false
    @State private var showAuthSheet  = false
    @State private var guestGateConfig: GuestGateConfig = GuestGateConfig(icon: "", title: "", message: "")
    
    private var insightStore: HairInsightsDataStore { store.hairInsightsStore }
    private var userPlan: UserPlan? { store.activePlan }

    /// AI-detected hair type from the latest scan report
    private var detectedHairType: String? {
        store.latestScanReport?.hairType
    }
    
    private var routineCards: [HairCareRoutine] {
        insightStore.filteredRoutines(for: detectedHairType)
    }

    private var personalizedTips: [CareTip] {
        insightStore.filteredCareTips(for: detectedHairType)
    }

    private var personalizedRemedies: [HomeRemedy] {
        insightStore.filteredHomeRemedies(for: detectedHairType)
    }
    
    private var allFavourites: [AnyFavouriteItem] {
        insightStore.allFavourites()
    }
    
    private var routineIndex: Int {
        routineScrollPosition.viewID(type: Int.self) ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    cleanShelfBannerSection
                    routineSection
                    favouritesSection
                    careTipsSection
                    homeRemediesSection
                    Spacer(minLength: 20)
                }
            }
            .background(Color.hcCream.ignoresSafeArea())
            .navigationTitle("Hair Insights")
            .navigationBarTitleDisplayMode(.large)

            .task {
                await insightStore.loadContent(hairType: detectedHairType)
            }
            .navigationDestination(isPresented: $pushGuestGate) {
                GuestGatePage(
                    config: guestGateConfig,
                    onSignUp: {
                        pushGuestGate = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showAuthSheet = true
                        }
                    },
                    onDismiss: { pushGuestGate = false }
                )
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthLandingView(hideGuestButton: true, onProceed: {
                    showAuthSheet = false
                })
            }
        }
    }
    
    // MARK: - Clean Shelf Section
    
    private var cleanShelfBannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Compatibility")
                .font(.title3.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            NavigationLink(destination: MyShelfView()) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: [Color.hcBrown, Color.hcBrownLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clean Shelf Analyzer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Scan ingredients to check compatibility with your \(store.latestScanReport?.scalpCondition.rawValue.capitalized ?? "normal") scalp.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 3)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Routine Section
    
    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended")
                .font(.title3.bold())
                .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if routineCards.isEmpty {
                Text("Complete your scalp scan to get routines personalised for your hair type.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(routineCards.indices, id: \.self) { i in
                            if authVM.isGuestMode {
                                Button {
                                    guestGateConfig = GuestGateConfig(
                                        icon: "sparkles",
                                        title: "Personalised Routines",
                                        message: "Create a free account to get personalised hair care routines for your hair type."
                                    )
                                    pushGuestGate = true
                                } label: {
                                    RoutineCardView(routine: routineCards[i])
                                        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                        .id(i)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    HairCareRoutineDetailView(
                                        routine: routineCards[i],
                                        insightStore: insightStore,
                                        userId: store.currentUserId
                                    )
                                } label: {
                                    RoutineCardView(routine: routineCards[i])
                                        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                        .id(i)
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition($routineScrollPosition)
                
                HStack(spacing: 6) {
                    ForEach(routineCards.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == routineIndex ? Color.black : Color.black.opacity(0.18))
                            .frame(width: i == routineIndex ? 18 : 7, height: 7)
                            .animation(.spring(duration: 0.35), value: routineIndex)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Favourites Section
    
    @ViewBuilder
    private var favouritesSection: some View {
        if !allFavourites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                
                if authVM.isGuestMode {
                    Button {
                        guestGateConfig = GuestGateConfig(
                            icon: "heart.fill",
                            title: "Save Your Favourites",
                            message: "Create a free account to save routines, tips, and remedies to your favourites."
                        )
                        pushGuestGate = true
                    } label: {
                        HStack {
                            Text("Your Favourites")
                                .font(.title3.bold())
                                .foregroundStyle(.black)
                            Image(systemName: "chevron.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(.black.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    NavigationLink {
                        FavouritesListView(insightStore: insightStore, userPlan: userPlan, userId: store.currentUserId)
                    } label: {
                        HStack {
                            Text("Your Favourites")
                                .font(.title3.bold())
                                .foregroundStyle(.black)
                            Image(systemName: "chevron.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(.black.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(allFavourites) { item in
                            if authVM.isGuestMode {
                                Button {
                                    guestGateConfig = GuestGateConfig(
                                        icon: "heart.fill",
                                        title: "Save Your Favourites",
                                        message: "Create a free account to save routines, tips, and remedies to your favourites."
                                    )
                                    pushGuestGate = true
                                } label: {
                                    FavouriteCardView(item: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    destinationView(for: item)
                                } label: {
                                    FavouriteCardView(item: item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Care Tips Section
    
    private var careTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
           
            if authVM.isGuestMode {
                Button {
                    guestGateConfig = GuestGateConfig(
                        icon: "lightbulb.fill",
                        title: "Personalised Care Tips",
                        message: "Create a free account to get expert care tips tailored to your hair type."
                    )
                    pushGuestGate = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Care Tips")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                NavigationLink {
                    CareTipsListView(
                        insightStore: insightStore,
                        hairType: detectedHairType,
                        userId: store.currentUserId
                    )
                } label: {
                    HStack(spacing: 8) {
                        Text("Care Tips")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }

            if personalizedTips.isEmpty {
                Text("No care tips found for your hair type yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(personalizedTips) { tip in
                            if authVM.isGuestMode {
                                Button {
                                    guestGateConfig = GuestGateConfig(
                                        icon: "lightbulb.fill",
                                        title: "Personalised Care Tips",
                                        message: "Create a free account to get expert care tips tailored to your hair type."
                                    )
                                    pushGuestGate = true
                                } label: {
                                    InsightMediaCardView(
                                        title: tip.title,
                                        mediaURL: tip.mediaURL,
                                        hairTypeBadge: tip.hairTypes.isEmpty ? nil : tip.hairTypes.first?.capitalized
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    CareTipDetailView(tip: tip, insightStore: insightStore, userId: store.currentUserId)
                                } label: {
                                    InsightMediaCardView(
                                        title: tip.title,
                                        mediaURL: tip.mediaURL,
                                        hairTypeBadge: tip.hairTypes.isEmpty ? nil : tip.hairTypes.first?.capitalized
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Home Remedies Section
    
    private var homeRemediesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            if authVM.isGuestMode {
                Button {
                    guestGateConfig = GuestGateConfig(
                        icon: "leaf.fill",
                        title: "Natural Home Remedies",
                        message: "Create a free account to discover natural home remedies for your hair health."
                    )
                    pushGuestGate = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Home Remedies")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                NavigationLink {
                    HomeRemediesListView(
                        insightStore: insightStore,
                        hairType: detectedHairType,
                        userId: store.currentUserId
                    )
                } label: {
                    HStack(spacing: 8) {
                        Text("Home Remedies")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }

            if personalizedRemedies.isEmpty {
                Text("No home remedies found for your hair type yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(personalizedRemedies) { remedy in
                            if authVM.isGuestMode {
                                Button {
                                    guestGateConfig = GuestGateConfig(
                                        icon: "leaf.fill",
                                        title: "Natural Home Remedies",
                                        message: "Create a free account to discover natural home remedies for your hair health."
                                    )
                                    pushGuestGate = true
                                } label: {
                                    InsightMediaCardView(
                                        title: remedy.title,
                                        mediaURL: remedy.mediaURL,
                                        hairTypeBadge: remedy.hairTypes.isEmpty ? nil : remedy.hairTypes.first?.capitalized
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    HomeRemedyDetailView(remedy: remedy, insightStore: insightStore, userId: store.currentUserId)
                                } label: {
                                    InsightMediaCardView(
                                        title: remedy.title,
                                        mediaURL: remedy.mediaURL,
                                        hairTypeBadge: remedy.hairTypes.isEmpty ? nil : remedy.hairTypes.first?.capitalized
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Destination Router
   
    @ViewBuilder
    private func destinationView(for item: AnyFavouriteItem) -> some View {
        switch item {
        case .careTip(let t):
            CareTipDetailView(tip: t, insightStore: insightStore, userId: store.currentUserId)
        case .remedy(let r):
            HomeRemedyDetailView(remedy: r, insightStore: insightStore, userId: store.currentUserId)
        case .routine(let r):
            HairCareRoutineDetailView(routine: r, insightStore: insightStore, userId: store.currentUserId)
        }
    }
}

// MARK: - RoutineCardView

struct RoutineCardView: View {
    let routine: HairCareRoutine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Row: Icon | VStack(Title Row & Tag Row)
            HStack(alignment: .center, spacing: 12) {

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.hcBrown.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hcBrown)
                }

                // Text Stack: Balance Line (Title) + Chevron on top row, and Tag below it
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        // Balance line (Title)
                        Text(routine.cardHeading)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        Spacer()

                        // Chevron beside the balance line to its right
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.hcBrown.opacity(0.55))
                    }

                    // Tag (Frequency pill) just below the balance line
                    Label(routine.applyingFrequency, systemImage: "calendar")
                        .font(.caption.bold())
                        .foregroundStyle(Color.hcBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.hcBrown.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Description
            Text(routine.summary)
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.55))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hcBrown.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.hcBrown.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - InsightMediaCardView

struct InsightMediaCardView: View {
    let title: String
    let mediaURL: String?
    var hairTypeBadge: String? = nil   // nil = universal (no badge shown)
    
    /// Shows only the first three words so the label is always clean with no truncation dots.
    private var shortTitle: String {
        let words = title.split(separator: " ", omittingEmptySubsequences: true)
        return words.prefix(3).joined(separator: " ")
    }
    
    private let cardWidth: CGFloat = 180
    private let imageHeight: CGFloat = 140
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color(.systemGray5)
                    if let urlString = mediaURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: cardWidth, height: imageHeight)
                                    .clipped()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color(.systemGray3))
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
                .frame(width: cardWidth, height: imageHeight)
                .clipped()

                // Hair-type badge (shown only for non-universal content)
                if let badge = hairTypeBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.hcBrown.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            
            Text(shortTitle)
                .font(.subheadline.bold())
                .foregroundStyle(.black)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .frame(height: 36)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .frame(width: cardWidth, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - FavouriteCardView

struct FavouriteCardView: View {
    let item: AnyFavouriteItem
    
    private let cardWidth: CGFloat = 140
    private let imageHeight: CGFloat = 120
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color(.systemGray5)
                if let urlString = item.mediaURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardWidth, height: imageHeight)
                                .clipped()
                        case .failure:
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            .frame(width: cardWidth, height: imageHeight)
            .clipped()
            
            Text(item.title)
                .font(.caption.bold())
                .foregroundStyle(.black)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 30)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .frame(width: cardWidth)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - EmptyFavouritesView

struct EmptyFavouritesView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.title2)
                .foregroundStyle(Color(.systemGray3))
            Text("Tap ♡ on any tip or remedy to save it here.")
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Preview

#Preview {
    let store = AppDataStore()
    return HairInsightsView()
        .environment(store)
}
