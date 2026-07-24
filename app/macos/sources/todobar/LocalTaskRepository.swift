import Foundation

@MainActor
protocol TaskRepository {
    func loadTasks() async throws -> [TodoTask]
    func createTask(_ task: TodoTask) async throws -> TodoTask
    func updateTask(_ task: TodoTask) async throws
    func setCompleted(_ task: TodoTask, completed: Bool) async throws
    func deleteTask(_ task: TodoTask) async throws
    func markReminderFired(_ task: TodoTask) async throws
}

final class LocalTaskRepository: TaskRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let directory: URL
        if let dataDirectory = ProcessInfo.processInfo.environment["TODOBAR_DATA_DIRECTORY"] {
            directory = URL(fileURLWithPath: dataDirectory, isDirectory: true)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directory = appSupport.appendingPathComponent("TodoBar", isDirectory: true)
        }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("tasks.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadTasks() async throws -> [TodoTask] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([TodoTask].self, from: data)
    }

    func createTask(_ task: TodoTask) async throws -> TodoTask {
        var tasks = try await loadTasks()
        tasks.append(task)
        try saveTasks(tasks)
        return task
    }

    func updateTask(_ task: TodoTask) async throws {
        var tasks = try await loadTasks()
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        try saveTasks(tasks)
    }

    func setCompleted(_ task: TodoTask, completed: Bool) async throws {
        var updated = task
        updated.completed = completed
        updated.updatedAt = Date()
        try await updateTask(updated)
    }

    func deleteTask(_ task: TodoTask) async throws {
        var tasks = try await loadTasks()
        tasks.removeAll { $0.id == task.id }
        try saveTasks(tasks)
    }

    func markReminderFired(_ task: TodoTask) async throws {
        var updated = task
        updated.reminderFiredAt = Date()
        updated.updatedAt = Date()
        try await updateTask(updated)
    }

    private func saveTasks(_ tasks: [TodoTask]) throws {
        let data = try encoder.encode(tasks)
        try data.write(to: fileURL, options: .atomic)
    }
}
