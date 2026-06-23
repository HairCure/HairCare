import SwiftUI

struct HairFolliclePointer: View {
    var body: some View {
        ZStack {
            // Shadow / background
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                // Outer Follicle Sheath
                Path { path in
                    path.move(to: CGPoint(x: w * 0.3, y: h * 0.2))
                    path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.6))
                    path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.9), control1: CGPoint(x: w * 0.3, y: h * 0.8), control2: CGPoint(x: w * 0.35, y: h * 0.9))
                    path.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.6), control1: CGPoint(x: w * 0.65, y: h * 0.9), control2: CGPoint(x: w * 0.7, y: h * 0.8))
                    path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.2))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                
                // Inner bulb (root)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.4, y: h * 0.65))
                    path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.75), control1: CGPoint(x: w * 0.4, y: h * 0.7), control2: CGPoint(x: w * 0.45, y: h * 0.75))
                    path.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.65), control1: CGPoint(x: w * 0.55, y: h * 0.75), control2: CGPoint(x: w * 0.6, y: h * 0.7))
                    path.addCurve(to: CGPoint(x: w * 0.4, y: h * 0.65), control1: CGPoint(x: w * 0.6, y: h * 0.5), control2: CGPoint(x: w * 0.4, y: h * 0.5))
                    path.closeSubpath()
                }
                .fill(Color.orange.opacity(0.3))
                
                Path { path in
                    path.move(to: CGPoint(x: w * 0.4, y: h * 0.65))
                    path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.75), control1: CGPoint(x: w * 0.4, y: h * 0.7), control2: CGPoint(x: w * 0.45, y: h * 0.75))
                    path.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.65), control1: CGPoint(x: w * 0.55, y: h * 0.75), control2: CGPoint(x: w * 0.6, y: h * 0.7))
                    path.addCurve(to: CGPoint(x: w * 0.4, y: h * 0.65), control1: CGPoint(x: w * 0.6, y: h * 0.5), control2: CGPoint(x: w * 0.4, y: h * 0.5))
                    path.closeSubpath()
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                
                // Hair shaft
                Path { path in
                    path.move(to: CGPoint(x: w * 0.5, y: h * 0.6))
                    path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.05), control1: CGPoint(x: w * 0.4, y: h * 0.4), control2: CGPoint(x: w * 0.6, y: h * 0.2))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                
                // Dermal papilla
                Path { path in
                    path.move(to: CGPoint(x: w * 0.45, y: h * 0.9))
                    path.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.9), control: CGPoint(x: w * 0.5, y: h * 0.82))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            .frame(width: 22, height: 22)
        }
        .frame(width: 32, height: 32)
    }
}
