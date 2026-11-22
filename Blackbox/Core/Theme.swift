import UIKit
import SwiftUI

enum Palette {
    static let void = Color(hex: 0x07090A)
    static let panel = Color(hex: 0x0C1110)
    static let panelEdge = Color(hex: 0x1E2A25)
    static let grid = Color(hex: 0x14201C)
    static let acid = Color(hex: 0x7DFF8A)
    static let amber = Color(hex: 0xFFC46B)
    static let blood = Color(hex: 0xFF6B6B)
    static let dim = Color(hex: 0x6E8178)
    static let paper = Color(hex: 0xD8E6DE)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct GridBackdrop: View {
    var spacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            var path = Path()
            stride(from: 0, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: 0, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Palette.grid.opacity(0.55)), lineWidth: 0.5)
        }
        .background(Palette.void)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct Panel<Content: View>: View {
    var tint: Color = Palette.panelEdge
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.panel, Palette.void],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tint.opacity(0.65), lineWidth: 1)
                    )
            )
    }
}

struct LabelCaps: View {
    let text: String
    var tint: Color = Palette.dim

    var body: some View {
        Text(text.uppercased())
            .font(.mono(10, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(tint)
    }
}

struct StatusPill: View {
    let text: String
    var tint: Color = Palette.acid

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(.mono(10, weight: .bold))
                .tracking(1.1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
    }
}

struct DeckButtonStyle: ButtonStyle {
    var tint: Color = Palette.acid
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(13, weight: .bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(filled ? Palette.void : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minWidth: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(filled ? tint : tint.opacity(configuration.isPressed ? 0.22 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(tint.opacity(0.8), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ScreenChrome<Content: View>: View {
    let title: String
    let code: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            GridBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            LabelCaps(text: code, tint: Palette.acid)
                            Text(title)
                                .font(.mono(24, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(Palette.paper)
                        }
                        Spacer()
                    }
                    content
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func hit() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func miss() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}