#include "Graph.hpp"
#include <algorithm>

namespace PedNav {

NodeType nodeTypeFromString(const std::string& s) {
    if (s == "junction")   return NodeType::Junction;
    if (s == "exit")       return NodeType::Exit;
    if (s == "transit")    return NodeType::Transit;
    if (s == "restaurant") return NodeType::Restaurant;
    if (s == "retail")     return NodeType::Retail;
    if (s == "restroom")   return NodeType::Restroom;
    if (s == "parking")    return NodeType::Parking;
    if (s == "landmark")        return NodeType::Landmark;
    if (s == "street_junction") return NodeType::StreetJunction;
    return NodeType::Unknown;
}

std::string nodeTypeToString(NodeType t) {
    switch (t) {
        case NodeType::Junction:   return "junction";
        case NodeType::Exit:       return "exit";
        case NodeType::Transit:    return "transit";
        case NodeType::Restaurant: return "restaurant";
        case NodeType::Retail:     return "retail";
        case NodeType::Restroom:   return "restroom";
        case NodeType::Parking:    return "parking";
        case NodeType::Landmark:        return "landmark";
        case NodeType::StreetJunction:  return "street_junction";
        default:                        return "unknown";
    }
}

std::string nodeTypeDisplayName(NodeType t) {
    switch (t) {
        case NodeType::Junction:   return "Junction";
        case NodeType::Exit:       return "Exit";
        case NodeType::Transit:    return "Transit";
        case NodeType::Restaurant: return "Food";
        case NodeType::Retail:     return "Shop";
        case NodeType::Restroom:   return "Restroom";
        case NodeType::Parking:    return "Parking";
        case NodeType::Landmark:        return "Landmark";
        case NodeType::StreetJunction:  return "Street Junction";
        default:                        return "Unknown";
    }
}

uint32_t nodeTypeColor(NodeType t) {
    // Format: 0xAARRGGBB
    switch (t) {
        case NodeType::Junction:   return 0xFF505560;
        case NodeType::Exit:       return 0xFFFF8C00;
        case NodeType::Transit:    return 0xFF2196F3;
        case NodeType::Restaurant: return 0xFFF44336;
        case NodeType::Retail:     return 0xFF9C27B0;
        case NodeType::Restroom:   return 0xFF00BCD4;
        case NodeType::Parking:    return 0xFF78909C;
        case NodeType::Landmark:        return 0xFFFFC107;
        case NodeType::StreetJunction:  return 0xFF4CAF50;
        default:                        return 0xFF888888;
    }
}

void Graph::buildIndex() {
    nodeIndex.clear();
    adj.clear();

    for (size_t i = 0; i < nodes.size(); ++i) {
        nodeIndex[nodes[i].id] = i;
    }

    for (const auto& edge : edges) {
        adj[edge.from].push_back({edge.to, edge.distance});
        adj[edge.to].push_back({edge.from, edge.distance});
    }
}

const GraphNode* Graph::nodeById(const std::string& id) const {
    auto it = nodeIndex.find(id);
    if (it == nodeIndex.end()) return nullptr;
    return &nodes[it->second];
}

const std::vector<std::pair<std::string, float>>& Graph::neighbors(const std::string& id) const {
    static const std::vector<std::pair<std::string, float>> empty;
    auto it = adj.find(id);
    if (it == adj.end()) return empty;
    return it->second;
}

} // namespace PedNav
