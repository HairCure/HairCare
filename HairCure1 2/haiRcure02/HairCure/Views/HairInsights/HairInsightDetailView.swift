import SwiftUI
import AVKit

// MARK: - Reusable AsyncImage Hero

struct HeroAsyncImage: View {
    let urlString: String?
    let fallbackIcon: String
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().fill(Color(.systemGray5))
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: height)
                                .clipped()
                        case .failure:
                            Image(systemName: fallbackIcon)
                                .font(.system(size: 60))
                                .foregroundStyle(Color(.systemGray2))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 60))
                        .foregroundStyle(Color(.systemGray2))
                }
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

struct ImageGalleryView: View {
    let urls: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(urls, id: \.self) { urlString in
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 140)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundStyle(Color(.systemGray3))
                                    )
                            case .empty:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 140)
                                    .overlay(ProgressView())
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct HomeRemedyDetailView: View {
    let remedy: HomeRemedy
    let insightStore: HairInsightsDataStore
    let userId: UUID
    
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
    @State private var playbackTask: Task<Void, Never>?
    @State private var showResearch = false
    
    private var isFav: Bool {
        insightStore.isFavorite(contentId: remedy.id)
    }
    
    private var totalDuration: Double {
        Double(remedy.videoDurationSeconds ?? 120)
    }
    
    private var currentTimeString: String { formatTime(Int(progress)) }
    private var totalTimeString: String    { formatTime(remedy.videoDurationSeconds ?? 120) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: Hero / Video area
                ZStack(alignment: .center) {
                    HeroAsyncImage(urlString: remedy.mediaURL, fallbackIcon: "play.rectangle", height: 280)
                    
                    Button {
                        togglePlayback()
                    } label: {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    // MARK: Favourite row + Frequency badge on same line
                    HStack(alignment: .center) {
                        if let freq = remedy.frequency {
                            Label(freq, systemImage: "calendar")
                                .font(.caption.bold())
                                .foregroundStyle(Color.hcBrown)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.hcBrown.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Button {
                            insightStore.toggleFavorite(contentId: remedy.id, userId: userId)
                        } label: {
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(isFav ? .red : Color(.systemGray2))
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 6) {
                        Slider(value: $progress, in: 0...totalDuration) { editing in
                            if editing {
                                playbackTask?.cancel()
                                playbackTask = nil
                            } else if isPlaying {
                                startPlaybackTask()
                            }
                        }
                        .tint(.primary)
                        
                        HStack {
                            Text(currentTimeString)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(totalTimeString)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    
                    Text(remedy.title)
                        .font(.title3.bold())
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    Text(remedy.benefits)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    if !remedy.ingredients.isEmpty {
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        Text("Ingredients")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(remedy.ingredients, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.hcBrown)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(item)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }
                    
                    if !remedy.steps.isEmpty {
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        Text("How to use")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(remedy.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.hcBrown)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }
                    
                    if let precautions = remedy.precautions {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(precautions)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle(remedy.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if remedy.researchURL != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showResearch = true } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.hcBrown)
                    }
                }
            }
        }
        .sheet(isPresented: $showResearch) {
            if let urlString = remedy.researchURL, let url = URL(string: urlString) {
                ResearchSheetView(url: url, title: remedy.title)
            }
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            await runPlayback()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            isPlaying = false
            playbackTask?.cancel()
            playbackTask = nil
        } else {
            isPlaying = true
            startPlaybackTask()
        }
    }
    
    private func startPlaybackTask() {
        playbackTask?.cancel()
        playbackTask = Task { await runPlayback() }
    }
    
    private func runPlayback() async {
        while progress < totalDuration {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            progress = min(progress + 0.5, totalDuration)
        }
        isPlaying = false
        playbackTask = nil
    }
    
    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d : %02d", seconds / 60, seconds % 60)
    }
}

struct CareTipDetailView: View {
    let tip: CareTip
    let insightStore: HairInsightsDataStore
    let userId: UUID
    
    @State private var showResearch = false
    
    private var isFav: Bool {
        insightStore.isFavorite(contentId: tip.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                HeroAsyncImage(urlString: tip.mediaURL, fallbackIcon: "leaf", height: 240)
                
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Fav row + Frequency badge on same line
                    HStack(alignment: .center) {
                        if let freq = tip.frequency {
                            Label(freq, systemImage: "calendar")
                                .font(.caption.bold())
                                .foregroundStyle(Color.hcBrown)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.hcBrown.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Button {
                            insightStore.toggleFavorite(contentId: tip.id, userId: userId)
                        } label: {
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(isFav ? .red : Color(.systemGray2))
                        }
                    }
                    .padding(.top, 12)
                    
                    Text(tip.title)
                        .font(.title3.bold())
                    
                    Text(tip.tipDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    
                    if !tip.steps.isEmpty {
                        Divider()
                        
                        Text("How to do it")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(tip.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.hcBrown)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let precautions = tip.precautions {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(precautions)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle(tip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tip.researchURL != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showResearch = true } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.hcBrown)
                    }
                }
            }
        }
        .sheet(isPresented: $showResearch) {
            if let urlString = tip.researchURL, let url = URL(string: urlString) {
                ResearchSheetView(url: url, title: tip.title)
            }
        }
    }
}

struct HairCareRoutineDetailView: View {
    let routine: HairCareRoutine
    let insightStore: HairInsightsDataStore
    let userId: UUID
    
    @State private var showResearch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                VStack(alignment: .leading, spacing: 12) {
                    
                    Label(routine.applyingFrequency, systemImage: "calendar")
                        .font(.caption.bold())
                        .foregroundStyle(Color.hcBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.hcBrown.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text(routine.cardHeading)
                        .font(.title3.bold())
                    
                    Text(routine.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    
                    if let benefits = routine.benefits, !benefits.isEmpty {
                        Divider()
                        
                        Text("Benefits")
                            .font(.headline)
                        
                        Text(benefits)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !routine.steps.isEmpty {
                        Divider()
                        
                        Text("How to do it")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(routine.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.hcBrown)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let precautions = routine.precautions {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(precautions)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle(routine.cardHeading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if routine.researchURL != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showResearch = true } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.hcBrown)
                    }
                }
            }
        }
        .sheet(isPresented: $showResearch) {
            if let urlString = routine.researchURL, let url = URL(string: urlString) {
                ResearchSheetView(url: url, title: routine.cardHeading)
            }
        }
    }
}

// MARK: - Reusable Research Sheet

struct ResearchSheetView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.hcBrown)
                Text("Research Reference")
                    .font(.title3.bold())
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Link(destination: url) {
                    Text("Open Study")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.hcBrown)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
            }
            .padding(24)
            .navigationTitle("Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
