import SwiftUI

struct CenterRingView: View {
    let progress: CGFloat
    let color: Color
    
    var body: some View {
        Circle()
            .stroke(color.opacity(0.12), lineWidth: 9)
        Circle()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
