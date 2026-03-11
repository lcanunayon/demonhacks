import SwiftUI
import Combine

enum AppView { case map, ar }
enum ActiveInput { case from, to }

@MainActor
class AppViewModel: ObservableObject {
    @Published var currentView: AppView = .map
    @Published var nodes: [MapNode] = []
    @Published var activeInput: ActiveInput = .from
    @Published var fromNode: MapNode? = nil
    @Published var toNode: MapNode? = nil
    @Published var route: [String] = []          // node IDs in order
    @Published var steps: [NavStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var isRoutePanelOpen: Bool = false
    @Published var filterType: String = "all"    // "all", "exit", "transit", etc.
    @Published var isLoaded: Bool = false
    @Published var edges: [(from: String, to: String)] = []

    let core = PedNavCore()

    var filteredNodes: [MapNode] {
        if filterType == "all" { return nodes }
        return nodes.filter { $0.type == filterType }
    }

    var nodesByType: [String: [MapNode]] {
        Dictionary(grouping: nodes) { $0.type }
    }

    // Grouped for picker display (same order as web app)
    var pickerGroups: [(groupName: String, type: String, nodes: [MapNode])] {
        let order: [(String, String)] = [
            ("Exits",      "exit"),
            ("Transit",    "transit"),
            ("Buildings",  "landmark"),
            ("Food",       "restaurant"),
            ("Shops",      "retail"),
            ("Restrooms",  "restroom"),
            ("Parking",    "parking"),
        ]
        return order.compactMap { (name, type) in
            let group = nodes.filter { $0.type == type }.sorted { $0.name < $1.name }
            if group.isEmpty { return nil }
            return (name, type, group)
        }
    }

    func loadGraph() {
        guard let url = Bundle.main.url(forResource: "pedway_graph", withExtension: "json"),
              let jsonString = try? String(contentsOf: url, encoding: .utf8) else {
            print("PedNav: Failed to load pedway_graph.json from bundle")
            return
        }
        let success = core.loadGraph(fromJSON: jsonString)
        if success {
            nodes = core.allNodes().map { MapNode(from: $0) }
            edges = core.allEdges().map { (from: $0["from"] ?? "", to: $0["to"] ?? "") }
            isLoaded = true
            print("PedNav: Loaded \(nodes.count) nodes, \(edges.count) edges")
        } else {
            print("PedNav: core.loadGraphFromJSON returned false")
        }
    }

    func calculateRoute() {
        guard let from = fromNode, let to = toNode else { return }
        let path = core.findPath(from: from.id, to: to.id)
        route = path
        let rawSteps = core.steps(forPath: path)
        steps = rawSteps.map { NavStep(from: $0) }
        currentStepIndex = 0
        isRoutePanelOpen = !steps.isEmpty
    }

    func clearRoute() {
        route = []
        steps = []
        fromNode = nil
        toNode = nil
        isRoutePanelOpen = false
        currentStepIndex = 0
    }

    func selectNode(_ node: MapNode) {
        if activeInput == .from {
            fromNode = node
            activeInput = .to
        } else {
            toNode = node
            activeInput = .from
        }
        if fromNode != nil && toNode != nil {
            calculateRoute()
        }
    }

    var currentStep: NavStep? {
        guard !steps.isEmpty, currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    func nextStep() {
        if currentStepIndex < steps.count - 1 { currentStepIndex += 1 }
    }

    func prevStep() {
        if currentStepIndex > 0 { currentStepIndex -= 1 }
    }
}
