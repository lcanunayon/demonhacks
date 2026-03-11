#pragma once
#include "Graph.hpp"
#include <vector>
#include <string>

namespace PedNav {

enum class TurnDirection {
    Start, End, Straight, Left, Right, UTurn, SlightLeft, SlightRight
};

struct NavStep {
    std::string nodeId;
    std::string instruction;   // Human-readable
    std::string directionIcon; // Arrow emoji: ↑ ← → ↓ etc.
    TurnDirection turn = TurnDirection::Straight;
    float distanceFt = 0;      // distance from previous step in feet (0.42m/px)
    int stepIndex = 0;
};

class StepGenerator {
public:
    // Generate simplified turn-by-turn steps from a path
    // Only includes: start, end, named nodes at significant turns (>30 degrees)
    std::vector<NavStep> generate(const Graph& graph, const std::vector<std::string>& path);

private:
    std::string bearingToCardinal(float angleDeg);
    TurnDirection computeTurn(float prevBearing, float nextBearing);
    std::string turnIcon(TurnDirection t);
    float pixelToFeet(float pixels);
};

} // namespace PedNav
