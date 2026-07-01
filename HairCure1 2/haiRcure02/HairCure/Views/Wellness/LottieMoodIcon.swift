import SwiftUI
#if canImport(Lottie)
import Lottie
#endif

struct LottieMoodIcon: View {
    let animationName: String
    let isActive: Bool
    
    var body: some View {
        #if canImport(Lottie)
        LottieAnimationWrapper(animationName: animationName, isActive: isActive)
        #else
        ZStack {
            Circle()
                .fill(isActive ? Color.mindEasePurple.opacity(0.2) : Color.hcBrown.opacity(0.1))
            Image(systemName: fallbackIcon(for: animationName))
                .font(.system(size: 24))
                .foregroundStyle(isActive ? Color.mindEasePurple : .secondary)
        }
        #endif
    }
    
    private func fallbackIcon(for name: String) -> String {
        if name.contains("calm") { return "face.smiling" }
        if name.contains("stressed") { return "face.dashed" }
        if name.contains("tired") { return "zzz" }
        if name.contains("anxious") { return "eyes" }
        return "circle"
    }
}

#if canImport(Lottie)
struct LottieAnimationWrapper: UIViewRepresentable {
    let animationName: String
    let isActive: Bool
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: animationName)
        view.contentMode = .scaleAspectFit
        view.backgroundBehavior = .pauseAndRestore
        
        // CRITICAL FIX: Prevent the animation from expanding beyond its SwiftUI frame!
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        return view
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if isActive {
            uiView.loopMode = .loop
            if !uiView.isAnimationPlaying {
                uiView.play()
            }
        } else {
            uiView.loopMode = .playOnce
            // Optional: pause or slow down when inactive to save resources
        }
    }
}
#endif
