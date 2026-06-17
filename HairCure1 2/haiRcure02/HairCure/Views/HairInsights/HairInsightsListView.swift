import SwiftUI

// MARK: - HomeRemediesListView

struct HomeRemediesListView: View {
    let insightStore: HairInsightsDataStore
    let hairType: String?
    let userId: UUID

    private var displayedRemedies: [HomeRemedy] {
        insightStore.filteredHomeRemedies(for: hairType)
    }

    var body: some View {
        List {
            ForEach(displayedRemedies) { remedy in
                NavigationLink {
                    HomeRemedyDetailView(remedy: remedy, insightStore: insightStore, userId: userId)
                } label: {
                    HomeRemedyRowView(remedy: remedy)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.hcCream)
        .navigationTitle("Home Remedies")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - HomeRemedyRowView

struct HomeRemedyRowView: View {
    let remedy: HomeRemedy
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 80)
                
                if let urlString = remedy.mediaURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Image(systemName: "play.circle")
                                .font(.title)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "play.circle")
                        .font(.title)
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(remedy.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(remedy.remedyDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if let seconds = remedy.videoDurationSeconds {
                    Label(formatDuration(seconds), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - CareTipsListView

struct CareTipsListView: View {
    let insightStore: HairInsightsDataStore
    let hairType: String?
    let userId: UUID

    private var displayedTips: [CareTip] {
        insightStore.filteredCareTips(for: hairType)
    }

    var body: some View {
        List {
            ForEach(displayedTips) { tip in
                NavigationLink {
                    CareTipDetailView(tip: tip, insightStore: insightStore , userId: userId)
                } label: {
                    CareTipRowView(tip: tip)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.hcCream)
        .navigationTitle("Care Tips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let ht = hairType {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Care Tips").font(.headline)
                        Text("For \(ht.capitalized) Hair").font(.caption).foregroundStyle(Color.hcBrown)
                    }
                }
            }
        }
    }
}

// MARK: - CareTipRowView

struct CareTipRowView: View {
    let tip: CareTip
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 72)
                
                if let urlString = tip.mediaURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Image(systemName: "leaf")
                                .font(.title)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "leaf")
                        .font(.title)
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(tip.tipDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - FavouritesListView

struct FavouritesListView: View {
    let insightStore: HairInsightsDataStore
    let userPlan: UserPlan?
    let userId : UUID
    private var allFavs: [AnyFavouriteItem] {
        insightStore.allFavourites()
    }
    
    var body: some View {
        Group {
            if allFavs.isEmpty {
                
                ContentUnavailableView(
                    "No Favourites Yet",
                    systemImage: "heart",
                    description: Text("Tap ♡ on any tip or remedy to save it here.")
                    
                )
                
                .background(Color.hcCream)
            } else {
                List {
                    ForEach(allFavs) { item in
                        NavigationLink {
                            detailView(for: item)
                        } label: {
                            FavouriteItemRowView(item: item, onRemove: {
                                insightStore.toggleFavorite(contentId: item.id, userId: userId)
                            })
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                .scrollContentBackground(.hidden) 
                .background(Color.hcCream)
            }
        }
        .navigationTitle("Your Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    
    @ViewBuilder
    private func detailView(for item: AnyFavouriteItem) -> some View {
        switch item {
        case .careTip(let t):
            CareTipDetailView(tip: t, insightStore: insightStore, userId: userId)
        case .remedy(let r):
            HomeRemedyDetailView(remedy: r, insightStore: insightStore , userId: userId)
        case .routine(let r):
            HairCareRoutineDetailView(routine: r, insightStore: insightStore, userId: userId)
        }
    }
}

// MARK: - FavouriteItemRowView

struct FavouriteItemRowView: View {
    let item: AnyFavouriteItem
    let onRemove: () -> Void
    
    private var typeLabel: String {
        switch item {
        case .careTip:  return "Care Tip"
        case .remedy:   return "Home Remedy"
        case .routine:  return "Care Routine"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                
                if let urlString = item.mediaURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .failure:
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red.opacity(0.4))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red.opacity(0.4))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}
#Preview {
    NavigationStack {
        HomeRemediesListView(insightStore: .mock(), hairType: nil, userId: UUID())
    }
}

#Preview {
    NavigationStack {
        CareTipsListView(insightStore: .mock(), hairType: nil, userId: UUID())
    }
}

#Preview {
    NavigationStack {
        FavouritesListView(insightStore: .mock(), userPlan: nil, userId: UUID())
    }
}
