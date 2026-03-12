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
    @Published var routeMiniMapImage: UIImage? = nil

    let core = PedNavCore()
    private var mapImage: UIImage? = nil   // full map, loaded once

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
        generateRouteMiniMap()
    }

    func clearRoute() {
        route = []
        steps = []
        fromNode = nil
        toNode = nil
        isRoutePanelOpen = false
        currentStepIndex = 0
        routeMiniMapImage = nil
    }

    // MARK: - Route mini-map rendering

    private func generateRouteMiniMap() {
        guard route.count > 1, let mapImg = mapImage else {
            routeMiniMapImage = nil
            return
        }

        // Build lookup
        var nMap: [String: MapNode] = [:]
        for n in nodes { nMap[n.id] = n }

        // Bounding box of route nodes
        var minX: CGFloat = .infinity,  minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity, maxY: CGFloat = -.infinity
        for nid in route {
            guard let n = nMap[nid] else { continue }
            minX = min(minX, n.x); minY = min(minY, n.y)
            maxX = max(maxX, n.x); maxY = max(maxY, n.y)
        }
        guard minX != .infinity else { routeMiniMapImage = nil; return }

        // Padding in map-pixel units
        let pad: CGFloat = 120
        minX = max(0, minX - pad);  minY = max(0, minY - pad)
        maxX = min(mapImg.size.width, maxX + pad)
        maxY = min(mapImg.size.height, maxY + pad)

        let cropW = maxX - minX, cropH = maxY - minY
        guard cropW > 0, cropH > 0 else { routeMiniMapImage = nil; return }

        // Scale so the crop fills a 300×300 canvas
        let canvas: CGFloat = 300
        let scale = min(canvas / cropW, canvas / cropH)
        let outW = cropW * scale, outH = cropH * scale

        UIGraphicsBeginImageContextWithOptions(CGSize(width: outW, height: outH), true, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Draw the cropped map region
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -minX, y: -minY)
        mapImg.draw(in: CGRect(origin: .zero, size: mapImg.size))
        ctx.restoreGState()

        // Draw route — two-pass
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        func routePt(_ nid: String) -> CGPoint? {
            guard let n = nMap[nid] else { return nil }
            return CGPoint(x: (n.x - minX) * scale, y: (n.y - minY) * scale)
        }
        // Border
        ctx.setStrokeColor(UIColor(red: 0x0D/255.0, green: 0x47/255.0, blue: 0xA1/255.0, alpha: 0.9).cgColor)
        ctx.setLineWidth(5.0)
        for i in 0..<(route.count - 1) {
            guard let a = routePt(route[i]), let b = routePt(route[i + 1]) else { continue }
            ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
        }
        // Blue fill
        ctx.setStrokeColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
        ctx.setLineWidth(3.0)
        for i in 0..<(route.count - 1) {
            guard let a = routePt(route[i]), let b = routePt(route[i + 1]) else { continue }
            ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
        }
        // Start dot (green)
        if let p = routePt(route.first!) {
            ctx.setFillColor(UIColor(red: 0x4C/255.0, green: 0xAF/255.0, blue: 0x50/255.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
        }
        // End dot (red)
        if let p = routePt(route.last!) {
            ctx.setFillColor(UIColor(red: 0xF4/255.0, green: 0x43/255.0, blue: 0x36/255.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
        }

        routeMiniMapImage = UIGraphicsGetImageFromCurrentImageContext()
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
