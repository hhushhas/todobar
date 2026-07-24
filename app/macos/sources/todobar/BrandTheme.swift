import SwiftUI

enum Brand {
    static let teal = Color(red: 0x16 / 255, green: 0xA7 / 255, blue: 0x99 / 255)
    static let amber = Color(red: 0xF7 / 255, green: 0xB3 / 255, blue: 0x12 / 255)
    static let coral = Color(red: 0xF4 / 255, green: 0x50 / 255, blue: 0x3C / 255)
    static let blue = Color(red: 0x2E / 255, green: 0x7F / 255, blue: 0xE5 / 255)

    static let petals = [teal, amber, coral, blue]

    static func petal(for index: Int) -> Color {
        petals[((index % 4) + 4) % 4]
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
