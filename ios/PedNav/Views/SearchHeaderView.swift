import SwiftUI

struct SearchHeaderView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: logo + title + tab switcher
            HStack(spacing: 10) {
                // Logo / icon
                logoView

                Text("PedNav")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.pedText)

                Spacer()

                // Map / AR tab switcher
                TabSwitcher(
                    selectedView: $viewModel.currentView
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider().background(Color.pedBorder)

            // From row
            LocationRow(
                label: "From",
                dotColor: .pedFrom,
                selectedNode: viewModel.fromNode,
                isActive: viewModel.activeInput == .from,
                groups: viewModel.pickerGroups,
                placeholder: "Select start...",
                onSelect: { node in
                    viewModel.fromNode = node
                    viewModel.activeInput = .to
                    if viewModel.fromNode != nil && viewModel.toNode != nil {
                        viewModel.calculateRoute()
                    }
                },
                onClear: {
                    viewModel.fromNode = nil
                    viewModel.clearRoute()
                }
            )
            .contentShape(Rectangle())
            .onTapGesture { viewModel.activeInput = .from }

            Divider()
                .background(Color.pedBorder)
                .padding(.horizontal, 14)

            // To row
            LocationRow(
                label: "To",
                dotColor: .pedTo,
                selectedNode: viewModel.toNode,
                isActive: viewModel.activeInput == .to,
                groups: viewModel.pickerGroups,
                placeholder: "Select destination...",
                onSelect: { node in
                    viewModel.toNode = node
                    viewModel.activeInput = .from
                    if viewModel.fromNode != nil && viewModel.toNode != nil {
                        viewModel.calculateRoute()
                    }
                },
                onClear: {
                    viewModel.toNode = nil
                    viewModel.clearRoute()
                }
            )
            .contentShape(Rectangle())
            .onTapGesture { viewModel.activeInput = .to }

            Divider().background(Color.pedBorder)
        }
        .background(Color.pedSurf)
    }

    @ViewBuilder
    private var logoView: some View {
        if let _ = UIImage(named: "logo") {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            // Fallback icon
            Image(systemName: "map.fill")
                .font(.system(size: 20))
                .foregroundColor(.pedAccent)
                .frame(width: 28, height: 28)
        }
    }
}

// MARK: - Tab switcher

private struct TabSwitcher: View {
    @Binding var selectedView: AppView

    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "Map",  icon: "map",    view: .map)
            tabButton(title: "AR",   icon: "camera", view: .ar)
        }
        .background(Color.pedSurf2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.pedBorder, lineWidth: 0.5))
    }

    private func tabButton(title: String, icon: String, view: AppView) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedView = view } }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(selectedView == view ? .white : .pedMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selectedView == view
                    ? Color.pedAccent
                    : Color.clear
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selectedView == view)
    }
}

// MARK: - Location row

private struct LocationRow: View {
    let label: String
    let dotColor: Color
    let selectedNode: MapNode?
    let isActive: Bool
    let groups: [(groupName: String, type: String, nodes: [MapNode])]
    let placeholder: String
    let onSelect: (MapNode) -> Void
    let onClear: () -> Void

    @State private var isPickerShowing = false

    var body: some View {
        HStack(spacing: 10) {
            // Active indicator bar
            Rectangle()
                .fill(isActive ? Color.pedAccent : Color.clear)
                .frame(width: 3)
                .frame(height: 40)
                .cornerRadius(2)

            // Colored dot
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)

            // Label
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.pedMuted)
                .frame(width: 36, alignment: .leading)

            // Picker / selected node
            if let node = selectedNode {
                Text(node.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.pedText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(.pedMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Picker button
            Button(action: { isPickerShowing.toggle() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.pedMuted)
                    .rotationEffect(isPickerShowing ? .degrees(180) : .zero)
                    .animation(.easeInOut(duration: 0.2), value: isPickerShowing)
            }
            .buttonStyle(.plain)

            // Clear button
            if selectedNode != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.pedMuted)
                        .frame(width: 22, height: 22)
                        .background(Color.pedSurf2)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? Color.pedAccent.opacity(0.06) : Color.clear)
        .sheet(isPresented: $isPickerShowing) {
            NodePickerSheet(
                groups: groups,
                onSelect: { node in
                    onSelect(node)
                    isPickerShowing = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Node picker sheet

private struct NodePickerSheet: View {
    let groups: [(groupName: String, type: String, nodes: [MapNode])]
    let onSelect: (MapNode) -> Void
    @State private var searchText = ""

    var filteredGroups: [(groupName: String, type: String, nodes: [MapNode])] {
        if searchText.isEmpty { return groups }
        return groups.compactMap { g in
            let filtered = g.nodes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            if filtered.isEmpty { return nil }
            return (g.groupName, g.type, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.type) { group in
                    Section(header: Text(group.groupName)
                        .foregroundColor(.pedMuted)
                        .font(.caption.weight(.semibold))
                    ) {
                        ForEach(group.nodes) { node in
                            Button(action: { onSelect(node) }) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(node.color)
                                        .frame(width: 8, height: 8)
                                    Text(node.name)
                                        .foregroundColor(.pedText)
                                        .font(.system(size: 15))
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.pedSurf2)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pedBg)
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search locations...")
        }
        .preferredColorScheme(.dark)
    }
}
