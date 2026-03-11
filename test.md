func loadGraph() {
        guard let url = Bundle.main.url(forResource: "pedway_graph", withExtension: "json"),
              let jsonString = try? String(contentsOf: url, encoding: .utf8) else {
            print("PedNav: Failed to load pedway_graph.json from bundle")
            return
        }
        let success = core.loadGraphFromJSON(jsonString)
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
        let path = core.findPathFrom(from.id, to: to.id)
        route = path
        let rawSteps = core.stepsForPath(path)
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
