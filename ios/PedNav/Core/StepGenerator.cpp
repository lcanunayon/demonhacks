#include "StepGenerator.hpp"
#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace PedNav {

float StepGenerator::pixelToFeet(float pixels) {
    // 0.42 meters per pixel * 3.28084 feet per meter
    return pixels * 0.42f * 3.28084f;
}

std::string StepGenerator::bearingToCardinal(float angleDeg) {
    // Normalize angle to [0, 360)
    while (angleDeg < 0)   angleDeg += 360.0f;
    while (angleDeg >= 360) angleDeg -= 360.0f;

    if (angleDeg < 22.5f)   return "N";
    if (angleDeg < 67.5f)   return "NE";
    if (angleDeg < 112.5f)  return "E";
    if (angleDeg < 157.5f)  return "SE";
    if (angleDeg < 202.5f)  return "S";
    if (angleDeg < 247.5f)  return "SW";
    if (angleDeg < 292.5f)  return "W";
    if (angleDeg < 337.5f)  return "NW";
    return "N";
}

TurnDirection StepGenerator::computeTurn(float prevBearing, float nextBearing) {
    float delta = nextBearing - prevBearing;
    // Normalize to [-180, 180]
    while (delta > 180.0f)  delta -= 360.0f;
    while (delta < -180.0f) delta += 360.0f;

    float absDelta = std::abs(delta);

    if (absDelta < 22.5f) {
        return TurnDirection::Straight;
    } else if (absDelta < 67.5f) {
        return delta > 0 ? TurnDirection::SlightRight : TurnDirection::SlightLeft;
    } else if (absDelta < 112.5f) {
        return delta > 0 ? TurnDirection::Right : TurnDirection::Left;
    } else if (absDelta < 157.5f) {
        return delta > 0 ? TurnDirection::Right : TurnDirection::Left;
    } else {
        return TurnDirection::UTurn;
    }
}

std::string StepGenerator::turnIcon(TurnDirection t) {
    switch (t) {
        case TurnDirection::Start:       return "\u25B6"; // ▶
        case TurnDirection::End:         return "\u2691"; // ⚑
        case TurnDirection::Straight:    return "\u2191"; // ↑
        case TurnDirection::Left:        return "\u2190"; // ←
        case TurnDirection::Right:       return "\u2192"; // →
        case TurnDirection::UTurn:       return "\u2193"; // ↓
        case TurnDirection::SlightLeft:  return "\u2196"; // ↖
        case TurnDirection::SlightRight: return "\u2197"; // ↗
        default:                         return "\u2191";
    }
}

std::vector<NavStep> StepGenerator::generate(const Graph& graph,
                                               const std::vector<std::string>& path) {
    std::vector<NavStep> steps;
    if (path.empty()) return steps;

    if (path.size() == 1) {
        const GraphNode* n = graph.nodeById(path[0]);
        NavStep s;
        s.nodeId = path[0];
        s.instruction = "You are at " + (n ? n->name : path[0]);
        s.directionIcon = turnIcon(TurnDirection::Start);
        s.turn = TurnDirection::Start;
        s.distanceFt = 0;
        s.stepIndex = 0;
        steps.push_back(s);
        return steps;
    }

    // Pre-compute per-segment bearings
    // bearing[i] = bearing from path[i] to path[i+1]
    std::vector<float> bearings;
    bearings.reserve(path.size() - 1);
    for (size_t i = 0; i + 1 < path.size(); ++i) {
        const GraphNode* a = graph.nodeById(path[i]);
        const GraphNode* b = graph.nodeById(path[i + 1]);
        if (!a || !b) {
            bearings.push_back(0.0f);
            continue;
        }
        float dx = b->x - a->x;
        float dy = b->y - a->y; // screen coords: y increases downward
        // atan2 in degrees, adjusting so 0 = North (up = negative y)
        float angle = std::atan2(dx, -dy) * 180.0f / (float)M_PI;
        if (angle < 0) angle += 360.0f;
        bearings.push_back(angle);
    }

    // Cumulative distances from path[0]
    std::vector<float> cumDist(path.size(), 0.0f);
    for (size_t i = 1; i < path.size(); ++i) {
        const GraphNode* a = graph.nodeById(path[i - 1]);
        const GraphNode* b = graph.nodeById(path[i]);
        float dist = 0.0f;
        if (a && b) {
            float dx = b->x - a->x;
            float dy = b->y - a->y;
            dist = std::sqrt(dx * dx + dy * dy);
        }
        cumDist[i] = cumDist[i - 1] + dist;
    }

    float lastStepCumDist = 0.0f;
    int stepIdx = 0;

    // START step
    {
        const GraphNode* startNode = graph.nodeById(path[0]);
        NavStep s;
        s.nodeId = path[0];
        s.instruction = "Start at " + (startNode ? startNode->name : path[0]);
        s.directionIcon = turnIcon(TurnDirection::Start);
        s.turn = TurnDirection::Start;
        s.distanceFt = 0;
        s.stepIndex = stepIdx++;
        steps.push_back(s);
        lastStepCumDist = 0.0f;
    }

    // Intermediate steps
    for (size_t i = 1; i + 1 < path.size(); ++i) {
        const GraphNode* node = graph.nodeById(path[i]);
        bool isNamed = node && node->type != NodeType::Junction && node->type != NodeType::Unknown;
        bool isSignificantTurn = false;

        float prevB = bearings[i - 1];
        float nextB = bearings[i];
        float delta = nextB - prevB;
        while (delta > 180.0f)  delta -= 360.0f;
        while (delta < -180.0f) delta += 360.0f;
        float absDelta = std::abs(delta);

        if (absDelta > 30.0f) {
            isSignificantTurn = true;
        }

        if (!isNamed && !isSignificantTurn) {
            continue;
        }

        TurnDirection turn = computeTurn(prevB, nextB);
        float distFromLast = pixelToFeet(cumDist[i] - lastStepCumDist);

        NavStep s;
        s.nodeId = path[i];
        s.turn = turn;
        s.directionIcon = turnIcon(turn);
        s.distanceFt = distFromLast;
        s.stepIndex = stepIdx++;

        std::string turnWord;
        switch (turn) {
            case TurnDirection::Straight:    turnWord = "Continue straight"; break;
            case TurnDirection::Left:        turnWord = "Turn left"; break;
            case TurnDirection::Right:       turnWord = "Turn right"; break;
            case TurnDirection::SlightLeft:  turnWord = "Bear left"; break;
            case TurnDirection::SlightRight: turnWord = "Bear right"; break;
            case TurnDirection::UTurn:       turnWord = "Make a U-turn"; break;
            default:                         turnWord = "Continue"; break;
        }

        std::string cardinal = bearingToCardinal(nextB);
        if (isNamed && node) {
            s.instruction = turnWord + " toward " + node->name;
        } else {
            s.instruction = turnWord + " heading " + cardinal;
        }

        steps.push_back(s);
        lastStepCumDist = cumDist[i];
    }

    // END step
    {
        const GraphNode* endNode = graph.nodeById(path.back());
        float distFromLast = pixelToFeet(cumDist.back() - lastStepCumDist);
        NavStep s;
        s.nodeId = path.back();
        s.instruction = "Arrive at " + (endNode ? endNode->name : path.back());
        s.directionIcon = turnIcon(TurnDirection::End);
        s.turn = TurnDirection::End;
        s.distanceFt = distFromLast;
        s.stepIndex = stepIdx++;
        steps.push_back(s);
    }

    return steps;
}

} // namespace PedNav
