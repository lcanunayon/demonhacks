import SwiftUI

// MARK: - Design system colors

extension Color {
    static let pedBg     = Color(hex: "#111416")
    static let pedSurf   = Color(hex: "#1C1F23")
    static let pedSurf2  = Color(hex: "#252A2F")
    static let pedBorder = Color(hex: "#2E3338")
    static let pedText   = Color(hex: "#EAEAEA")
    static let pedMuted  = Color(hex: "#8A9099")
    static let pedAccent = Color(hex: "#2196F3")
    static let pedFrom   = Color(hex: "#4CAF50")
    static let pedTo     = Color(hex: "#F44336")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let (a, r, g, b): (UInt64, UInt64, UInt64, UInt64) = hex.count == 8
            ? (int >> 24, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
            : (0xff,      (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                // Main layout
                VStack(spacing: 0) {
                    SearchHeaderView()

                    FilterBarView()

                    // Main content area
                    ZStack {
                        switch viewModel.currentView {
                        case .map:
                            MapCanvasRepresentable()
                                .ignoresSafeArea(edges: .bottom)
                        case .ar:
                            ARCameraView()
                                .ignoresSafeArea(edges: .bottom)
                        }

                        // Loading overlay
                        if !viewModel.isLoaded {
                            loadingOverlay
                        }

                        // Empty state when AR has no route
                        if viewModel.currentView == .ar && viewModel.steps.isEmpty {
                            arNoRouteOverlay
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.pedBg)

                // Route panel — slides in from right
                if viewModel.isRoutePanelOpen {
                    RoutePanelView()
                        .frame(width: min(320, geo.size.width * 0.85))
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isRoutePanelOpen)
    }

    // MARK: - Auxiliary overlays

    private var loadingOverlay: some View {
        ZStack {
            Color.pedBg.opacity(0.85)
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.pedAccent)
                    .scaleEffect(1.4)
                Text("Loading Pedway Map…")
                    .font(.subheadline)
                    .foregroundColor(.pedMuted)
            }
        }
        .ignoresSafeArea()
    }

    private var arNoRouteOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                .font(.system(size: 44))
                .foregroundColor(.pedAccent.opacity(0.7))
            Text("No active route")
                .font(.headline)
                .foregroundColor(.pedText)
            Text("Select a From and To location\nto calculate a route first.")
                .font(.subheadline)
                .foregroundColor(.pedMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color.pedSurf.opacity(0.9))
        .cornerRadius(16)
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
