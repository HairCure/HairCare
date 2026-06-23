import SwiftUI

struct HairFolliclePointer: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            
            Path { path in
                path.addArc(center: CGPoint(x: 12, y: 16), radius: 4, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            }
            .fill(Color.orange) // Use orange for testing
            
            Path { path in
                path.move(to: CGPoint(x: 12, y: 12))
                path.addCurve(to: CGPoint(x: 12, y: 4), control1: CGPoint(x: 8, y: 8), control2: CGPoint(x: 16, y: 6))
            }
            .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .frame(width: 24, height: 24)
    }
}
