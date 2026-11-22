import SwiftUI

struct DeckView: View {
    @EnvironmentObject private var log: CaseLog

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            GridBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    ForEach(ModuleGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                LabelCaps(text: group.rawValue, tint: Palette.amber)
                                Rectangle()
                                    .fill(Palette.panelEdge)
                                    .frame(height: 1)
                            }
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(ModuleID.inGroup(group)) { module in
                                    NavigationLink(value: module) {
                                        ModuleCard(module: module)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    footer
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationDestination(for: ModuleID.self) { module in
            ModuleRouter.view(for: module)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BLACKBOX")
                        .font(.mono(30, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Palette.paper)
                    LabelCaps(text: "field deck / case \(log.caseNumber)")
                }
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Palette.acid)
            }

            HStack(spacing: 8) {
                StatusPill(text: "\(log.summary.hosts) hosts", tint: log.summary.hosts > 0 ? Palette.acid : Palette.dim)
                StatusPill(text: "\(log.summary.findings) findings", tint: log.summary.findings > 0 ? Palette.amber : Palette.dim)
            }

            Text("Hold the phone like a tool, not a screen. Every module writes into the case file.")
                .font(.mono(12))
                .foregroundStyle(Palette.dim)
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        Panel {
            VStack(alignment: .leading, spacing: 6) {
                LabelCaps(text: "Rules of engagement")
                Text("Scan only networks and gadgets you own or have permission to poke. Nothing here attacks anything.")
                    .font(.mono(11))
                    .foregroundStyle(Palette.dim)
            }
        }
    }
}

private struct ModuleCard: View {
    let module: ModuleID

    var body: some View {
        Panel(tint: Palette.acid.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: module.glyph)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.acid)
                    Spacer()
                    Text(module.code)
                        .font(.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Palette.dim)
                }
                Text(module.title)
                    .font(.mono(14, weight: .bold))
                    .foregroundStyle(Palette.paper)
                Text(module.blurb)
                    .font(.mono(10))
                    .foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        }
    }
}

enum ModuleRouter {
    @ViewBuilder
    static func view(for module: ModuleID) -> some View {
        switch module {
        case .lanSweep: SweepView()
        case .bonjour: BonjourView()
        case .wifi: WiFiView()
        case .bleed: BLEView()
        case .nfc: NFCView()
        case .capture: CaptureView()
        case .encode: EncodeView()
        case .hash: HashView()
        case .osint: OSINTView()
        }
    }
}