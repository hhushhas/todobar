import AppKit
import SwiftUI

struct TagPill: View {
    let tag: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            Text("#\(tag)")
                .font(.system(size: 10.5, weight: .medium))

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(tag) tag")
            }
        }
        .foregroundStyle(Brand.teal)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(Capsule().fill(Brand.teal.opacity(0.12)))
    }
}

struct CopyDescriptionButton: View {
    let text: String
    var showLabel = false

    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10.5, weight: .medium))
                if showLabel {
                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 10.5, weight: .medium))
                }
            }
            .foregroundStyle(copied ? Brand.teal : Color.secondary)
            .frame(minWidth: showLabel ? 52 : 20, minHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(showLabel ? 0.045 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(copied ? "Description copied" : "Copy description")
        .accessibilityLabel(copied ? "Description copied" : "Copy description")
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > bounds.minX, point.x + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> CGSize {
        var currentWidth: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth > 0, currentWidth + size.width > width {
                totalHeight += lineHeight + spacing
                currentWidth = 0
                lineHeight = 0
            }
            currentWidth += size.width + (currentWidth > 0 ? spacing : 0)
            totalWidth = max(totalWidth, currentWidth)
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: totalWidth, height: totalHeight + lineHeight)
    }
}
