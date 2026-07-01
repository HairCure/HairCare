import SwiftUI

struct MoodSliderView: View {
    @Binding var selectedMood: String?
    let moods: [(String, String)]
    
    // Default selection if nil
    private var currentMoodName: String {
        selectedMood ?? "Select Mood"
    }
    
    private var currentMoodAnim: String? {
        if selectedMood == nil { return nil }
        return moods.first(where: { $0.1 == currentMoodName })?.0
    }

    private func getArcPoint(angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let rad = angle * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            let arcCenter = CGPoint(x: width / 2, y: 110)
            let arcRadius = width * 0.38
            let angles: [Double] = [165, 115, 65, 15] // Left to right
            
            ZStack {
                // 1. The glowing track (Arc)
                Path { path in
                    for angle in stride(from: 165.0, through: 15.0, by: -2.0) {
                        let pt = getArcPoint(angle: angle, center: arcCenter, radius: arcRadius)
                        if angle == 165.0 { path.move(to: pt) }
                        else { path.addLine(to: pt) }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.mindEasePurple.opacity(0.1), Color.mindEasePurple.opacity(0.5), Color.mindEasePurple.opacity(0.1)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .shadow(color: Color.mindEasePurple.opacity(0.3), radius: 5, x: 0, y: 0)
                
                // 2. Large Central Selected Mood
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.mindEasePurple.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .shadow(color: Color.mindEasePurple.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        if let anim = currentMoodAnim {
                            LottieMoodIcon(animationName: anim, isActive: true)
                                .frame(width: 120, height: 120)
                                .id(currentMoodName + "center")
                        } else {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(Color.mindEasePurple.opacity(0.4))
                        }
                    }
                    
                    Text(currentMoodName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.mindEasePurple)
                }
                .position(x: arcCenter.x, y: arcCenter.y - 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentMoodName)
                
                // 3. Small Moods on the Arc
                ForEach(Array(moods.enumerated()), id: \.element.1) { idx, mood in
                    let angle = idx < angles.count ? angles[idx] : 90.0
                    let pt = getArcPoint(angle: angle, center: arcCenter, radius: arcRadius)
                    let isSelected = selectedMood == mood.1
                    
                    VStack(spacing: 4) {
                        LottieMoodIcon(animationName: mood.0, isActive: isSelected)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.mindEasePurple.opacity(0.2) : Color.white)
                                    .shadow(color: .black.opacity(0.05), radius: 4)
                            )
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                        
                        Text(mood.1)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.mindEasePurple : .secondary)
                            .opacity(isSelected ? 0 : 0.7)
                    }
                    .position(pt)
                    .onTapGesture {
                        triggerHapticFeedback()
                        if selectedMood != mood.1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedMood = mood.1
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
