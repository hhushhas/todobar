import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject private var appState: AppState
    let taskID: TodoTask.ID
    let petalIndex: Int
    let priorityRank: Int?
    let isDropTarget: Bool
    let onFrameChange: (TodoTask.ID, CGRect) -> Void
    let onDragChange: (TodoTask.ID, CGPoint) -> Void
    let onDragEnd: (TodoTask.ID, CGPoint) -> Void
    @Binding var editingTaskID: TodoTask.ID?

    @State private var isHovered = false
    @State private var isActionsHovered = false
    @GestureState private var dragOffset = CGSize.zero

    private var petalColor: Color { Brand.petal(for: petalIndex) }
    private var isEditing: Bool { editingTaskID == taskID }
    private var showActions: Bool { (isHovered || isActionsHovered) && !appState.privacyBlurEnabled }
    private var contentBlurRadius: CGFloat { appState.privacyBlurEnabled ? 4.5 : 0 }

    var body: some View {
        if let task = appState.task(id: taskID) {
            row(for: task)
        }
    }

    private func row(for task: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 8) {
            PetalCheckbox(completed: task.completed, color: petalColor) {
                appState.toggle(task)
            }
            .disabled(isEditing)

            if let priorityRank {
                PriorityBadge(rank: priorityRank)
            }

            if isEditing {
                TaskInlineEditor(
                    task: task,
                    onCommit: { title, description, tags, reminderAt in
                        appState.update(
                            task,
                            title: title,
                            description: description,
                            tags: tags,
                            reminderAt: reminderAt
                        )
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) { editingTaskID = nil }
                    }
                )
            } else {
                taskContent
                    .onTapGesture {
                        if task.completed {
                            appState.toggle(task)
                        } else {
                            withAnimation(.easeInOut(duration: 0.16)) { editingTaskID = taskID }
                        }
                    }
                    .offset(y: dragOffset.height)
                    .opacity(dragOffset == .zero ? 1 : 0.82)
                    .zIndex(dragOffset == .zero ? 0 : 1)
                    .gesture(priorityDragGesture)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(isDropTarget ? 0.09 : (isHovered && !isEditing ? 0.045 : 0)))
        )
        .overlay(alignment: .top) {
            if isDropTarget {
                Capsule()
                    .fill(Brand.teal)
                    .frame(height: 2)
                    .padding(.horizontal, 5)
            }
        }
        .opacity(task.completed ? 0.75 : 1)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named("taskList"))
        } action: { frame in
            onFrameChange(taskID, frame)
        }
    }

    @ViewBuilder
    private var taskContent: some View {
        if let task = appState.task(id: taskID) {
            taskContent(for: task)
        }
    }

    private func taskContent(for task: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let description = task.description {
                    Text(description)
                        .font(.system(size: 11.5))
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if isHovered && !task.completed {
                    Text("Add description…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if hasMeta {
                    FlowLayout(spacing: 4) {
                        ForEach(task.tags, id: \.self) { tag in
                            TagPill(tag: tag)
                        }
                        if let reminderAt = task.reminderAt {
                            MetaChip(
                                text: reminderText(reminderAt),
                                systemImage: "bell.fill",
                                color: Brand.blue,
                                background: 0.12
                            )
                        }
                    }
                }
            }
            .blur(radius: contentBlurRadius)
            .accessibilityLabel(appState.privacyBlurEnabled ? "Private task" : task.title)
            .animation(.easeInOut(duration: 0.14), value: appState.privacyBlurEnabled)

            HStack(spacing: 2) {
                if let description = task.description {
                    CopyDescriptionButton(text: description)
                        .opacity(showActions ? 1 : 0.5)
                }

                HStack(spacing: 2) {
                    RowIconButton(systemName: "pencil", accessibilityLabel: "Edit task") {
                        withAnimation(.easeInOut(duration: 0.16)) { editingTaskID = taskID }
                    }
                    RowIconButton(systemName: "xmark", accessibilityLabel: "Delete task", isDestructive: true) {
                        appState.delete(task)
                    }
                }
                .opacity(showActions ? 1 : 0)
                .allowsHitTesting(showActions)
                .accessibilityHidden(!showActions)
            }
            .padding(.top, -1)
            .onHover { isActionsHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: showActions)
        }
    }

    private var hasMeta: Bool {
        guard let task = appState.task(id: taskID) else { return false }
        return !task.tags.isEmpty || task.reminderAt != nil
    }

    private func reminderText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return "Today \(time)"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(time)"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var priorityDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("taskList"))
            .updating($dragOffset) { value, offset, _ in
                guard priorityRank != nil, !isEditing else { return }
                offset = value.translation
            }
            .onChanged { value in
                guard priorityRank != nil, !isEditing else { return }
                onDragChange(taskID, value.location)
            }
            .onEnded { value in
                guard priorityRank != nil, !isEditing else { return }
                onDragEnd(taskID, value.location)
            }
    }
}

private struct PriorityBadge: View {
    let rank: Int

    var body: some View {
        Text("P\(rank)")
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Brand.teal)
            .frame(minWidth: 24, minHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Brand.teal.opacity(0.12))
            )
            .contentShape(Rectangle())
            .help("Priority \(rank). Drag the task text to reorder")
            .accessibilityLabel("Priority \(rank)")
            .accessibilityHint("Drag the task text to reorder")
    }
}

private struct PetalCheckbox: View {
    let completed: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(completed ? color : color.opacity(isHovered ? 0.15 : 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .stroke(color, lineWidth: 1.5)
                    )
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(completed ? 1.04 : 1)

                Checkmark()
                    .trim(from: 0, to: completed ? 1 : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 10)
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: completed)
        .onHover { isHovered = $0 }
        .help(completed ? "Mark active" : "Complete")
    }
}

private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: 0.18 * w, y: 0.54 * h))
        path.addLine(to: CGPoint(x: 0.40 * w, y: 0.76 * h))
        path.addLine(to: CGPoint(x: 0.82 * w, y: 0.26 * h))
        return path
    }
}

private struct RowIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var isDestructive = false
    let action: () -> Void

    @State private var isHovered = false

    private var foreground: Color {
        if isDestructive && isHovered { return Brand.coral }
        return Color.secondary.opacity(isHovered ? 0.8 : 0.5)
    }

    private var background: Color {
        if isDestructive && isHovered { return Brand.coral.opacity(0.1) }
        return Color.primary.opacity(isHovered ? 0.045 : 0)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(background)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MetaChip: View {
    let text: String
    let systemImage: String
    let color: Color
    let background: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
        .background(Capsule().fill(color.opacity(background)))
    }
}
