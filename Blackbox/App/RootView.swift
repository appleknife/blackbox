import SwiftUI

struct RootView: View {
    enum Tab: String, CaseIterable {
        case deck = "Deck"
        case log = "Case"
        case about = "Scope"

        var glyph: String {
            switch self {
            case .deck: return "square.grid.2x2"
            case .log: return "list.bullet.rectangle"
            case .about: return "info.circle"
            }
        }
    }

    @State private var tab: Tab = .deck

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .deck:
                    NavigationStack { DeckView() }
                case .log:
                    NavigationStack { CaseView() }
                case .about:
                    NavigationStack { ScopeView() }
                }
            }
            tabBar
        }
        .background(Palette.void.ignoresSafeArea())
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    Haptics.tap()
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.glyph)
                            .font(.system(size: 17, weight: .semibold))
                        Text(item.rawValue.uppercased())
                            .font(.mono(9, weight: .bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(tab == item ? Palette.acid : Palette.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Palette.panel
                .overlay(alignment: .top) { Rectangle().fill(Palette.panelEdge).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}