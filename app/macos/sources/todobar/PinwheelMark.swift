import SwiftUI

struct PinwheelMark: View {
    let size: CGFloat

    private var u: CGFloat { size / 24 }

    var body: some View {
        ZStack {
            petal(cx: 7.4, cy: 7.4, color: Brand.teal)
            petal(cx: 16.6, cy: 7.4, color: Brand.amber)
            petal(cx: 7.4, cy: 16.6, color: Brand.coral)
            petal(cx: 16.6, cy: 16.6, color: Brand.blue)
            checkmark
        }
        .frame(width: size, height: size)
    }

    private func petal(cx: CGFloat, cy: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2.6 * u, style: .continuous)
            .fill(color)
            .frame(width: 10.4 * u, height: 10.4 * u)
            .rotationEffect(.degrees(45))
            .position(x: cx * u, y: cy * u)
    }

    private var checkmark: some View {
        Path { path in
            path.move(to: CGPoint(x: 14.2 * u, y: 7.6 * u))
            path.addLine(to: CGPoint(x: 16.0 * u, y: 9.4 * u))
            path.addLine(to: CGPoint(x: 19.2 * u, y: 6.0 * u))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.9 * u, lineCap: .round, lineJoin: .round))
    }
}
