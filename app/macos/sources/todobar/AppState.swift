import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    @Published var newTaskTitle = ""
    @Published var errorMessage: String?
    @Published var completedCollapsed = true
    @Published var privacyBlurEnabled = false
    @Published var isCloudConfigured: Bool

    private var repository: any TaskRepository
    private let effects: EffectsController
    private let reminders: ReminderController

    init(repository: any TaskRepository, effects: EffectsController, reminders: ReminderController, isCloudConfigured: Bool) {
        self.repository = repository
        self.effects = effects
        self.reminders = reminders
        self.isCloudConfigured = isCloudConfigured
    }

    var activeTasks: [TodoTask] {
        tasks.filter { !$0.completed }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var completedTasks: [TodoTask] {
        tasks.filter(\.completed).sorted { $0.updatedAt > $1.updatedAt }
    }

    func priorityRank(for taskID: TodoTask.ID) -> Int? {
        guard let index = activeTasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        return index + 1
    }

    func task(id: TodoTask.ID) -> TodoTask? {
        tasks.first { $0.id == id }
    }

    func petalIndex(for taskID: TodoTask.ID) -> Int {
        tasks.firstIndex { $0.id == taskID } ?? 0
    }

    func load() {
        Task {
            do {
                tasks = try await repository.loadTasks()
                reminders.schedule(for: tasks)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func switchToSyncedRepository(_ syncedRepository: any TaskRepository) {
        let localSnapshot = tasks
        repository = syncedRepository
        isCloudConfigured = true
        Task {
            do {
                let cloudTasks = try await syncedRepository.loadTasks()
                if cloudTasks.isEmpty, !localSnapshot.isEmpty {
                    tasks = try await migrate(localSnapshot, to: syncedRepository)
                } else {
                    tasks = cloudTasks
                }
                reminders.schedule(for: tasks)
            } catch {
                isCloudConfigured = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func switchToLocalRepository() {
        repository = LocalTaskRepository()
        isCloudConfigured = false
        load()
    }

    func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        newTaskTitle = ""
        let task = TodoTask(id: "local-\(UUID().uuidString)", title: title)
        tasks.append(task)
        reminders.schedule(for: tasks)
        Task {
            do {
                let saved = try await repository.createTask(task)
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index] = saved
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggle(_ task: TodoTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].completed.toggle()
        tasks[index].updatedAt = Date()
        if tasks[index].completed {
            effects.showTaskCompleted(title: tasks[index].title)
        }
        let updated = tasks[index]
        reminders.schedule(for: tasks)
        Task {
            do {
                try await repository.setCompleted(updated, completed: updated.completed)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func update(_ task: TodoTask, title: String, description: String?, tags: [String], reminderAt: Date?) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        tasks[index].title = title
        tasks[index].description = description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        tasks[index].tags = TodoTask.normalizedTags(tags)
        tasks[index].reminderAt = reminderAt
        tasks[index].reminderFiredAt = nil
        tasks[index].updatedAt = Date()
        let updated = tasks[index]
        reminders.schedule(for: tasks)
        Task {
            do {
                try await repository.updateTask(updated)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func delete(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        reminders.schedule(for: tasks)
        Task {
            do {
                try await repository.deleteTask(task)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func moveActiveTask(_ taskID: TodoTask.ID, to targetID: TodoTask.ID) {
        var orderedTasks = activeTasks
        guard
            let sourceIndex = orderedTasks.firstIndex(where: { $0.id == taskID }),
            let targetIndex = orderedTasks.firstIndex(where: { $0.id == targetID }),
            sourceIndex != targetIndex
        else { return }

        let movedTask = orderedTasks.remove(at: sourceIndex)
        orderedTasks.insert(movedTask, at: min(targetIndex, orderedTasks.endIndex))

        guard
            let movedIndex = orderedTasks.firstIndex(where: { $0.id == taskID }),
            let taskIndex = tasks.firstIndex(where: { $0.id == taskID })
        else { return }

        tasks[taskIndex].sortOrder = sortOrder(for: movedIndex, in: orderedTasks)
        let updated = tasks[taskIndex]
        Task {
            do {
                try await repository.updateTask(updated)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func markReminderFired(_ task: TodoTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].reminderFiredAt = Date()
        let updated = tasks[index]
        reminders.schedule(for: tasks)
        Task {
            do {
                try await repository.markReminderFired(updated)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func migrate(_ localTasks: [TodoTask], to syncedRepository: any TaskRepository) async throws -> [TodoTask] {
        var migrated: [TodoTask] = []
        for task in localTasks.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            var saved = try await syncedRepository.createTask(task)
            if task.completed {
                try await syncedRepository.setCompleted(saved, completed: true)
                saved.completed = true
                saved.updatedAt = task.updatedAt
            }
            if task.reminderFiredAt != nil {
                try await syncedRepository.markReminderFired(saved)
                saved.reminderFiredAt = Date()
            }
            migrated.append(saved)
        }
        return migrated
    }

    private func sortOrder(for index: Int, in orderedTasks: [TodoTask]) -> Double {
        let previous = index > orderedTasks.startIndex ? orderedTasks[index - 1].sortOrder : nil
        let next = index < orderedTasks.index(before: orderedTasks.endIndex) ? orderedTasks[index + 1].sortOrder : nil

        switch (previous, next) {
        case let (.some(previous), .some(next)):
            return previous + ((next - previous) / 2)
        case let (.some(previous), .none):
            return previous + 1
        case let (.none, .some(next)):
            return next - 1
        case (.none, .none):
            return orderedTasks[index].sortOrder
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
