#pragma once
#include "Graph.hpp"
#include <vector>
#include <string>

namespace PedNav {

class AStarPathfinder {
public:
    // Returns ordered list of node IDs from start to end, empty if no path
    std::vector<std::string> findPath(const Graph& graph, const std::string& startId, const std::string& endId);

private:
    float heuristic(const GraphNode& a, const GraphNode& b);
};

} // namespace PedNav
