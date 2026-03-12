#pragma once
#include <string>
#include <vector>
#include <unordered_map>

namespace PedNav {

enum class NodeType : uint8_t {
    Junction = 0, Exit, Transit, Restaurant, Retail, Restroom, Parking, Landmark, StreetJunction, Unknown
};

NodeType nodeTypeFromString(const std::string& s);
std::string nodeTypeToString(NodeType t);
std::string nodeTypeDisplayName(NodeType t);
uint32_t nodeTypeColor(NodeType t); // ARGB hex

struct GraphNode {
    std::string id;
    std::string name;
    NodeType type = NodeType::Unknown;
    float x = 0, y = 0;
    double lat = 0, lng = 0;
};

struct GraphEdge {
    std::string from;
    std::string to;
    float distance = 0;
};

struct GraphMeta {
    int imageWidth = 4900;
    int imageHeight = 7300;
    int nodeCount = 0;
    int edgeCount = 0;
};

class Graph {
public:
    GraphMeta meta;
    std::vector<GraphNode> nodes;
    std::vector<GraphEdge> edges;
    std::unordered_map<std::string, size_t> nodeIndex;
    std::unordered_map<std::string, std::vector<std::pair<std::string, float>>> adj;

    void buildIndex();
    const GraphNode* nodeById(const std::string& id) const;
    const std::vector<std::pair<std::string, float>>& neighbors(const std::string& id) const;
};

} // namespace PedNav
