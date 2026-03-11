import SwiftUI

struct RoutePanelView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Route")
                    .font(.headline)
                    .foregroundColor(.pedText)
                Spacer()
                Button(action: { viewModel.isRoutePanelOpen = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.pedMuted)
                        .frame(width: 32, height: 32)
                        .background(Color.pedSurf2)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.pedSurf)

            // From → To summary
            if let from = viewModel.fromNode, let to = viewModel.toNode {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.pedFrom)
                        .frame(width: 10, height: 10)
                    Text(from.name)
                        .font(.subheadline)
                        .foregroundColor(.pedText)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.pedMuted)
                    Text(to.name)
                        .font(.subheadline)
                        .foregroundColor(.pedText)
                        .lineLimit(1)
                    Circle()
                        .fill(Color.pedTo)
                        .frame(width: 10, height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pedSurf2)

                Divider().background(Color.pedBorder)
            }

            // Step list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.steps) { step in
                            StepCell(step: step,
                                     isActive: step.id == viewModel.currentStepIndex)
                                .id(step.id)
                                .onTapGesture {
                                    viewModel.currentStepIndex = step.id
                                }
                        }
                    }
                }
                .onChange(of: viewModel.currentStepIndex) { idx in
                    withAnimation {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }

            Divider().background(Color.pedBorder)

            // Navigation controls
            HStack(spacing: 16) {
                Button(action: { viewModel.prevStep() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Prev")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(viewModel.currentStepIndex > 0 ? .pedText : .pedMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.pedSurf2)
                    .cornerRadius(8)
                }
                .disabled(viewModel.currentStepIndex == 0)

                Text("\(viewModel.currentStepIndex + 1)/\(viewModel.steps.count)")
                    .font(.caption)
                    .foregroundColor(.pedMuted)
                    .frame(minWidth: 50)

                Button(action: { viewModel.nextStep() }) {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(viewModel.currentStepIndex < viewModel.steps.count - 1 ? .pedText : .pedMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.pedAccent)
                    .cornerRadius(8)
                }
                .disabled(viewModel.currentStepIndex >= viewModel.steps.count - 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.pedSurf)
        }
        .background(Color.pedSurf)
        .cornerRadius(14, corners: [.topLeft, .bottomLeft])
        .shadow(color: .black.opacity(0.4), radius: 16, x: -4, y: 0)
        .frame(maxWidth: 320)
    }
}

// MARK: - Step cell

private struct StepCell: View {
    let step: NavStep
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Direction icon
            Text(step.directionIcon)
                .font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(isActive ? Color.pedAccent : Color.pedSurf2)
                .clipShape(Circle())

            // Instruction
            VStack(alignment: .leading, spacing: 2) {
                Text(step.instruction)
                    .font(.subheadline)
                    .foregroundColor(isActive ? .pedText : .pedMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if step.distanceFt > 0 {
                    Text(String(format: "%.0f ft", step.distanceFt))
                        .font(.caption2)
                        .foregroundColor(.pedMuted)
                }
            }

            Spacer()

            // Step index indicator
            if isActive {
                Circle()
                    .fill(Color.pedAccent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isActive
                    ? Color.pedAccent.opacity(0.12)
                    : Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.pedBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Rounded corners helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = 0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
