import SwiftUI

@main
struct BlackboxApp: App {
    @StateObject private var log = CaseLog.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(log)
                .preferredColorScheme(.dark)
                .tint(Palette.acid)
        }
    }
}