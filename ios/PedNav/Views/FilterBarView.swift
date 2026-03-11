import SwiftUI

private struct FilterItem: Identifiable {
    let id: String       // "all", "exit", "transit", etc.
    let label: String
    let icon: String
}

private let filterItems: [FilterItem] = [
    FilterItem(id: "all",        label: "All",       icon: "square.grid.2x2"),
    FilterItem(id: "exit",       label: "Exits",     icon: "door.right.hand.open"),
    FilterItem(id: "transit",    label: "Transit",   icon: "tram"),
    FilterItem(id: "landmark",   label: "Buildings", icon: "building.2"),
    FilterItem(id: "restaurant", label: "Food",      icon: "fork.knife"),
    FilterItem(id: "retail",     label: "Shops",     icon: "bag"),
    FilterItem(id: "restroom",   label: "Restrooms", icon: "figure.stand"),
    FilterItem(id: "parking",    label: "Parking",   icon: "parkingsign"),
]

struct FilterBarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterItems) { item in
                    FilterPill(
                        item: item,
                        isSelected: viewModel.filterType == item.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.filterType = item.id
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.pedSurf)
        .overlay(
            Rectangle()
                .fill(Color.pedBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

private struct FilterPill: View {
    let item: FilterItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(item.label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .pedMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.pedAccent : Color.pedSurf2)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.pedBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
