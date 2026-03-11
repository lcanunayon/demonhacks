#include "Pathfinder.hpp"
#include <queue>
#include <unordered_map>
#include <cmath>
#include <algorithm>
#include <functional>

namespace PedNav {

float AStarPathfinder::heuristic(const GraphNode& a, const GraphNode& b) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    return std::sqrt(dx * dx + dy * dy);
}

std::vector<std::string> AStarPathfinder::findPath(const Graph& graph,
                                                     const std::string& startId,
                                                     const std::string& endId) {
    if (startId == endId) return {startId};

    const GraphNode* startNode = graph.nodeById(startId);
    const GraphNode* endNode   = graph.nodeById(endId);
    if (!startNode || !endNode) return {};

    // Min-heap: (fScore, nodeId)
    using Entry = std::pair<float, std::string>;
    std::priority_queue<Entry, std::vector<Entry>, std::greater<Entry>> openSet;

    std::unordered_map<std::string, float> gScore;
    std::unordered_map<std::string, float> fScore;
    std::unordered_map<std::string, std::string> cameFrom;

    gScore[startId] = 0.0f;
    fScore[startId] = heuristic(*startNode, *endNode);
    openSet.push({fScore[startId], startId});

    while (!openSet.empty()) {
        auto [currentF, currentId] = openSet.top();
        openSet.pop();

        if (currentId == endId) {
            // Reconstruct path
            std::vector<std::string> path;
            std::string cur = endId;
            while (cur != startId) {
                path.push_back(cur);
                cur = cameFrom[cur];
            }
            path.push_back(startId);
            std::reverse(path.begin(), path.end());
            return path;
        }

        // Skip stale entries
        auto fsIt = fScore.find(currentId);
        if (fsIt != fScore.end() && currentF > fsIt->second + 1e-5f) {
            continue;
        }

        float currentG = gScore.count(currentId) ? gScore[currentId] : 1e30f;

        for (const auto& [neighborId, edgeDist] : graph.neighbors(currentId)) {
            float tentativeG = currentG + edgeDist;

            float neighborG = gScore.count(neighborId) ? gScore[neighborId] : 1e30f;
            if (tentativeG < neighborG) {
                cameFrom[neighborId] = currentId;
                gScore[neighborId] = tentativeG;

                const GraphNode* neighborNode = graph.nodeById(neighborId);
                float h = neighborNode ? heuristic(*neighborNode, *endNode) : 0.0f;
                float newF = tentativeG + h;
                fScore[neighborId] = newF;
                openSet.push({newF, neighborId});
            }
        }
    }

    return {}; // No path found
}

} // namespace PedNav
