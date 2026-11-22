import SwiftUI

struct CaseView: View {
    @EnvironmentObject private var log: CaseLog

    var body: some View {
        ZStack {
            GridBackdrop()
            VStack(spacing: 0) {
                header
                if log.entries.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Palette.dim)
                        Text("Case file is empty.\nRun a module.")
                            .multilineTextAlignment(.center)
                            .font(.mono(12))
                            .foregroundStyle(Palette.dim)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(log.entries.reversed()) { entry in
                                row(entry)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CASE \(log.caseNumber)")
                        .font(.mono(20, weight: .heavy))
                        .foregroundStyle(Palette.paper)
                    LabelCaps(text: "\(log.entries.count) entries")
                }
                Spacer()
            }
            HStack(spacing: 8) {
                CaseExportButton(log: log)
                Button("Wipe") {
                    Haptics.miss()
                    log.clear()
                }
                .buttonStyle(DeckButtonStyle(tint: Palette.blood))
            }
        }
        .padding(16)
        .background(Palette.void)
    }

    private func row(_ entry: CaseEntry) -> some View {
        Panel(tint: tint(entry.kind).opacity(0.45)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.date.formatted(date: .omitted, time: .standard))
                        .font(.mono(10))
                        .foregroundStyle(Palette.dim)
                    Text(entry.module)
                        .font(.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(tint(entry.kind))
                    Spacer()
                    Text(entry.kind.rawValue.uppercased())
                        .font(.mono(8, weight: .bold))
                        .foregroundStyle(tint(entry.kind))
                }
                Text(entry.message)
                    .font(.mono(12))
                    .foregroundStyle(Palette.paper)
                    .textSelection(.enabled)
                if !entry.fields.isEmpty {
                    Text(entry.fields.sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" }
                        .joined(separator: "  "))
                        .font(.mono(10))
                        .foregroundStyle(Palette.dim)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func tint(_ kind: CaseEntry.Kind) -> Color {
        switch kind {
        case .finding: return Palette.amber
        case .error: return Palette.blood
        case .note, .observation: return Palette.acid
        }
    }
}