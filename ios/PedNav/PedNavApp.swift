import SwiftUI

@main
struct PedNavApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
                .onAppear {
                    viewModel.loadGraph()
                }
        }
    }
}
