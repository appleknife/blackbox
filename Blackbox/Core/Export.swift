import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct CaseExportButton: View {
    @ObservedObject var log: CaseLog
    @State private var sharing = false

    var body: some View {
        Button {
            Haptics.tap()
            sharing = true
        } label: {
            Label("Export case", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(DeckButtonStyle())
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [temporaryFile()])
                .presentationDetents([.medium, .large])
        }
    }

    private func temporaryFile() -> URL {
        let name = "case-\(log.caseNumber).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? log.exportJSON().write(to: url, options: .atomic)
        return url
    }
}