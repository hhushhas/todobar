import SwiftUI

struct TaskInlineEditor: View {
    let task: TodoTask
    let onCommit: (String, String?, [String], Date?) -> Void
    let onClose: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var tags: [String]
    @State private var tagDraft = ""
    @State private var reminderAt: Date
    @State private var hasReminder: Bool
    @State private var didCommit = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case description
        case tag
    }

    init(task: TodoTask, onCommit: @escaping (String, String?, [String], Date?) -> Void, onClose: @escaping () -> Void) {
        self.task = task
        self.onCommit = onCommit
        self.onClose = onClose
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description ?? "")
        _tags = State(initialValue: task.tags)
        _reminderAt = State(initialValue: task.reminderAt ?? Self.defaultReminderDate())
        _hasReminder = State(initialValue: task.reminderAt != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Task title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .medium))
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .description }

            descriptionEditor
            tagEditor
            reminderEditor
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Brand.teal.opacity(0.38), lineWidth: 1)
                )
        )
        .onExitCommand {
            commit()
            onClose()
        }
        .onDisappear(perform: commit)
        .task {
            await Task.yield()
            focusedField = .description
        }
    }

    private var descriptionEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("DESCRIPTION")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
                Spacer()
                if !description.isEmpty {
                    CopyDescriptionButton(text: description, showLabel: true)
                }
            }

            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Add context or paste an agent prompt…")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 5)
                        .allowsHitTesting(false)
                }

                DescriptionTextEditor(
                    text: $description,
                    isFocused: Binding(
                        get: { focusedField == .description },
                        set: { isFocused in
                            if isFocused {
                                focusedField = .description
                            } else if focusedField == .description {
                                focusedField = nil
                            }
                        }
                    )
                )
            }
            .frame(minHeight: 64, maxHeight: 104)
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        TagPill(tag: tag) {
                            tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                TextField("Add a tag", text: $tagDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .focused($focusedField, equals: .tag)
                    .onSubmit(addTag)

                if !tags.contains(where: { $0.caseInsensitiveCompare("Prompt") == .orderedSame }) {
                    Button("+ Prompt") { addTag("Prompt") }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Brand.teal)
                        .help("Tag this task as a prompt")
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
        }
    }

    private var reminderEditor: some View {
        HStack(spacing: 7) {
            Image(systemName: hasReminder ? "bell.fill" : "bell")
                .font(.system(size: 10.5))
                .foregroundStyle(hasReminder ? Brand.blue : Color.secondary)

            if hasReminder {
                DatePicker("Reminder date", selection: $reminderAt, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .accessibilityLabel("Reminder date")
                DatePicker("Reminder time", selection: $reminderAt, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .accessibilityLabel("Reminder time")

                Button {
                    hasReminder = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove reminder")
                .accessibilityLabel("Remove reminder")
            } else {
                Button("Add reminder") {
                    reminderAt = Self.defaultReminderDate()
                    hasReminder = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)
            Text(hasReminder ? "Esc closes" : "Autosaves · Esc to close")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func addTag() {
        addTag(tagDraft)
        tagDraft = ""
        focusedField = .tag
    }

    private func addTag(_ tag: String) {
        tags = TodoTask.normalizedTags(tags + [tag])
    }

    private func commit() {
        guard !didCommit else { return }
        didCommit = true
        onCommit(title, description, tags, hasReminder ? reminderAt : nil)
    }

    private static func defaultReminderDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        if calendar.component(.hour, from: now) < 20 {
            return calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
