import SwiftUI

enum PopoverLayout {
    static let width: CGFloat = 380
    static let height: CGFloat = 520
}

struct TaskPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var auth: AuthController
    @FocusState private var inputFocused: Bool
    @State private var editingTaskID: TodoTask.ID?
    @State private var taskFrames: [TodoTask.ID: CGRect] = [:]
    @State private var dragTargetTaskID: TodoTask.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            taskInput
            taskList
            footer
        }
        .frame(width: PopoverLayout.width, height: PopoverLayout.height)
        .background(VisualEffectBackground())
        .tint(Brand.teal)
        .onAppear { focusCaptureField() }
        .onReceive(NotificationCenter.default.publisher(for: .todoBarPopoverDidShow)) { _ in
            focusCaptureField()
        }
        .onChange(of: inputFocused) { _, focused in
            if focused {
                editingTaskID = nil
            }
        }
        .onChange(of: editingTaskID) { _, taskID in
            if taskID != nil {
                inputFocused = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            PinwheelMark(size: 20)
            Text("TodoBar")
                .font(.system(size: 14.5, weight: .semibold))
                .tracking(-0.2)
            syncDot
            Spacer()
            privacyToggle
            IdentityMenu()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 7)
    }

    private var privacyToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                if !appState.privacyBlurEnabled {
                    editingTaskID = nil
                }
                appState.privacyBlurEnabled.toggle()
            }
        } label: {
            Image(systemName: appState.privacyBlurEnabled ? "eye.slash.fill" : "eye")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(appState.privacyBlurEnabled ? Brand.teal : Color.secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(appState.privacyBlurEnabled ? Brand.teal.opacity(0.12) : Color.primary.opacity(0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(appState.privacyBlurEnabled ? "Show task text" : "Hide task text")
        .accessibilityLabel(appState.privacyBlurEnabled ? "Show task text" : "Hide task text")
    }

    private var syncDot: some View {
        let configured = appState.isCloudConfigured
        return Circle()
            .fill(configured ? Brand.teal : Color.secondary.opacity(0.4))
            .frame(width: 7, height: 7)
            .background(
                Circle()
                    .fill(Brand.teal.opacity(configured ? 0.18 : 0))
                    .frame(width: 13, height: 13)
            )
            .help(configured ? auth.statusText : "Local mode")
    }

    private var taskInput: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("Add a task or prompt…", text: $appState.newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($inputFocused)
                .onSubmit {
                    appState.addTask()
                    inputFocused = true
                }
            if inputFocused {
                Text("⏎")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(inputFocused ? Brand.teal.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: inputFocused ? Brand.teal.opacity(0.12) : .clear, radius: 2)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .animation(.easeInOut(duration: 0.15), value: inputFocused)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.activeTasks) { task in
                    TaskRowView(
                        taskID: task.id,
                        petalIndex: appState.petalIndex(for: task.id),
                        priorityRank: appState.priorityRank(for: task.id),
                        isDropTarget: dragTargetTaskID == task.id,
                        onFrameChange: updateTaskFrame,
                        onDragChange: updateDragTarget,
                        onDragEnd: finishDrag,
                        editingTaskID: $editingTaskID
                    )
                        .id("active-\(task.id)")
                }

                if !appState.completedCollapsed {
                    completedSectionHeader
                    ForEach(appState.completedTasks) { task in
                        TaskRowView(
                            taskID: task.id,
                            petalIndex: appState.petalIndex(for: task.id),
                            priorityRank: nil,
                            isDropTarget: false,
                            onFrameChange: updateTaskFrame,
                            onDragChange: updateDragTarget,
                            onDragEnd: finishDrag,
                            editingTaskID: $editingTaskID
                        )
                            .id("completed-\(task.id)")
                    }
                }

                if appState.activeTasks.isEmpty && (appState.completedCollapsed || appState.completedTasks.isEmpty) {
                    emptyState
                }
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 6)
        }
        .coordinateSpace(name: "taskList")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            PinwheelMark(size: 44)
                .opacity(0.5)
            Text("All clear")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Enjoy the quiet, or add what's next.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 36)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            if !appState.completedTasks.isEmpty && appState.completedCollapsed {
                completedToggle
            }
            Spacer()
            Text(remainingText)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var completedSectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { appState.completedCollapsed = true }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Brand.teal)
                    .frame(width: 11, height: 11)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(0.78)
                Text("Completed · \(appState.completedTasks.count)")
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Brand.teal)
            .padding(.horizontal, 7)
            .padding(.top, appState.activeTasks.isEmpty ? 3 : 8)
            .padding(.bottom, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Hide completed tasks")
    }

    private var completedToggle: some View {
        let showing = !appState.completedCollapsed
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { appState.completedCollapsed.toggle() }
        } label: {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(showing ? Brand.teal : Color.secondary)
                    .frame(width: 13, height: 13)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(0.78)
                Text("Completed · \(appState.completedTasks.count)")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(showing ? AnyShapeStyle(Brand.teal) : AnyShapeStyle(.secondary))
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -8)
        .help(showing ? "Hide completed tasks" : "Show completed tasks")
    }

    private var remainingText: String {
        let count = appState.activeTasks.count
        switch count {
        case 0: return "All done"
        case 1: return "1 task left"
        default: return "\(count) tasks left"
        }
    }

    private func focusCaptureField() {
        editingTaskID = nil
        inputFocused = true
    }

    private func updateTaskFrame(_ taskID: TodoTask.ID, frame: CGRect) {
        taskFrames[taskID] = frame
    }

    private func updateDragTarget(_ taskID: TodoTask.ID, location: CGPoint) {
        let targetID = nearestActiveTask(to: location.y)
        dragTargetTaskID = targetID == taskID ? nil : targetID
    }

    private func finishDrag(_ taskID: TodoTask.ID, location: CGPoint) {
        let nearestTaskID = nearestActiveTask(to: location.y)
        let targetID = nearestTaskID == taskID ? nil : nearestTaskID ?? dragTargetTaskID
        dragTargetTaskID = nil
        guard let targetID else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            appState.moveActiveTask(taskID, to: targetID)
        }
    }

    private func nearestActiveTask(to verticalPosition: CGFloat) -> TodoTask.ID? {
        let activeIDs = Set(appState.activeTasks.map(\.id))
        return taskFrames
            .filter { activeIDs.contains($0.key) }
            .min { abs($0.value.midY - verticalPosition) < abs($1.value.midY - verticalPosition) }?
            .key
    }
}
