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
    @Published var route: [String] = []
    @Published var steps: [NavStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var isRoutePanelOpen: Bool = false
    @Published var filterType: String = "all"
    @Published var isLoaded: Bool = false
    @Published var edges: [(from: String, to: String)] = []
    @Published var showLabels: Bool = true

    let core = PedNavCore()
    var mapImage: UIImage? = nil   // full map, loaded once

    var nodeMap: [String: MapNode] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    var filteredNodes: [MapNode] {
        if filterType == "all" { return nodes }
        return nodes.filter { $0.type == filterType }
    }

    var nodesByType: [String: [MapNode]] {
        Dictionary(grouping: nodes) { $0.type }
    }

    // Exits are visible on the map but excluded from the picker (they have no useful names)
    var pickerGroups: [(groupName: String, type: String, nodes: [MapNode])] {
        let order: [(String, String)] = [
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
        guard let pedwayURL = Bundle.main.url(forResource: "pedway_graph", withExtension: "json"),
              let pedwayData = try? Data(contentsOf: pedwayURL),
              var root = (try? JSONSerialization.jsonObject(with: pedwayData)) as? [String: Any] else {
            print("PedNav: Failed to load pedway_graph.json from bundle")
            return
        }

        // Merge street_graph.json — prefix all IDs with "s_" to avoid conflicts
        if let streetURL = Bundle.main.url(forResource: "street_graph", withExtension: "json"),
           let streetData = try? Data(contentsOf: streetURL),
           let streetRoot = (try? JSONSerialization.jsonObject(with: streetData)) as? [String: Any] {
            var baseNodes = root["nodes"] as? [[String: Any]] ?? []
            var baseEdges = root["edges"] as? [[String: Any]] ?? []
            if let sNodes = streetRoot["nodes"] as? [[String: Any]] {
                baseNodes += sNodes.map { n -> [String: Any] in
                    var m = n; if let id = m["id"] as? String { m["id"] = "s_\(id)" }; return m
                }
            }
            if let sEdges = streetRoot["edges"] as? [[String: Any]] {
                baseEdges += sEdges.map { e -> [String: Any] in
                    var m = e
                    if let f = m["from"] as? String { m["from"] = "s_\(f)" }
                    if let t = m["to"]   as? String { m["to"]   = "s_\(t)" }
                    return m
                }
            }
            root["nodes"] = baseNodes
            root["edges"] = baseEdges
        }

        // Add bridge edges (pedway ↔ street — IDs already in final form)
        if let bridgeURL = Bundle.main.url(forResource: "bridge_edges", withExtension: "json"),
           let bridgeData = try? Data(contentsOf: bridgeURL),
           let bridgeRoot = (try? JSONSerialization.jsonObject(with: bridgeData)) as? [String: Any],
           let bridgeList = bridgeRoot["bridge_edges"] as? [[String: Any]] {
            var baseEdges = root["edges"] as? [[String: Any]] ?? []
            baseEdges += bridgeList
            root["edges"] = baseEdges
        }

        guard let merged = try? JSONSerialization.data(withJSONObject: root),
              let jsonString = String(data: merged, encoding: .utf8) else {
            print("PedNav: Failed to serialize merged graph")
            return
        }

        let success = core.loadGraph(fromJSON: jsonString)
        if success {
            nodes = core.allNodes().map { MapNode(from: $0) }
            edges = core.allEdges().map { (from: $0["from"] ?? "", to: $0["to"] ?? "") }
            if let mapURL = Bundle.main.url(forResource: "map", withExtension: "jpg") {
                mapImage = UIImage(contentsOfFile: mapURL.path)
            }
            isLoaded = true
            let streetCount = nodes.filter { $0.id.hasPrefix("s_") }.count
            print("PedNav: Loaded \(nodes.count) nodes (\(streetCount) street), \(edges.count) edges")
        } else {
            print("PedNav: loadGraph failed")
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
