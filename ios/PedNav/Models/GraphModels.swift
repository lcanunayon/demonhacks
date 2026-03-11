import Foundation
import SwiftUI

struct MapNode: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let x: CGFloat
    let y: CGFloat
    let lat: Double
    let lng: Double
    let color: Color

    var displayType: String {
        switch type {
        case "exit":       return "Exit"
        case "transit":    return "Transit"
        case "restaurant": return "Food"
        case "retail":     return "Shop"
        case "restroom":   return "Restroom"
        case "parking":    return "Parking"
        case "landmark":   return "Landmark"
        default:           return "Junction"
        }
    }

    init(from pn: PNNode) {
        id   = pn.nodeId
        name = pn.name
        type = pn.type
        x    = pn.x
        y    = pn.y
        lat  = pn.lat
        lng  = pn.lng
        let argb = pn.color
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8)  & 0xFF) / 255.0
        let b = Double( argb        & 0xFF) / 255.0
        color = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // Hashable / Equatable based on id
    static func == (lhs: MapNode, rhs: MapNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct NavStep: Identifiable {
    let id: Int
    let nodeId: String
    let instruction: String
    let directionIcon: String
    let distanceFt: Float

    init(from pn: PNStep) {
        id            = pn.stepIndex
        nodeId        = pn.nodeId
        instruction   = pn.instruction
        directionIcon = pn.directionIcon
        distanceFt    = pn.distanceFt
    }
}
