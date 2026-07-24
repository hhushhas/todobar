import Combine
@preconcurrency import ConvexMobile
import Foundation

final class ConvexTaskRepository: TaskRepository {
    private let client: ConvexClientWithAuth<String>

    init(client: ConvexClientWithAuth<String>) {
        self.client = client
    }

    func loadTasks() async throws -> [TodoTask] {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            var cancellable: AnyCancellable?
            cancellable = client.subscribe(to: "tasks:listTasks", yielding: [ConvexTask].self)
                .first()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion, !didResume {
                            didResume = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { tasks in
                        guard !didResume else { return }
                        didResume = true
                        continuation.resume(returning: tasks.map { $0.todoTask })
                    }
                )
        }
    }

    func createTask(_ task: TodoTask) async throws -> TodoTask {
        var args: [String: (any ConvexEncodable)?] = [
            "title": task.title,
        ]
        if let description = task.description {
            args["description"] = description
        }
        if !task.tags.isEmpty {
            let tags: [(any ConvexEncodable)?] = task.tags.map { $0 }
            args["tags"] = tags
        }
        if let reminderAt = task.reminderAt {
            args["reminderAt"] = reminderAt.timeIntervalSince1970 * 1000
        }

        let id: String = try await client.mutation("tasks:createTask", with: args)
        var created = task
        created.id = id
        created.completed = false
        return created
    }

    func updateTask(_ task: TodoTask) async throws {
        let tags: [(any ConvexEncodable)?] = task.tags.map { $0 }
        var patch: [String: (any ConvexEncodable)?] = [
            "title": task.title,
            "description": task.description,
            "tags": tags,
        ]
        patch["reminderAt"] = task.reminderAt.map { $0.timeIntervalSince1970 * 1000 }

        let args: [String: (any ConvexEncodable)?] = [
            "id": task.id,
            "patch": patch,
        ]
        let _: String? = try await client.mutation("tasks:updateTask", with: args)
    }

    func setCompleted(_ task: TodoTask, completed: Bool) async throws {
        let args: [String: (any ConvexEncodable)?] = ["id": task.id]
        let _: String? = try await client.mutation(completed ? "tasks:completeTask" : "tasks:uncompleteTask", with: args)
    }

    func deleteTask(_ task: TodoTask) async throws {
        let args: [String: (any ConvexEncodable)?] = ["id": task.id]
        let _: String? = try await client.mutation("tasks:deleteTask", with: args)
    }

    func markReminderFired(_ task: TodoTask) async throws {
        let args: [String: (any ConvexEncodable)?] = [
            "id": task.id,
            "firedAt": Date().timeIntervalSince1970 * 1000,
        ]
        let _: String? = try await client.mutation("tasks:markReminderFired", with: args)
    }
}

private struct ConvexTask: Decodable {
    let _id: String
    let title: String
    let description: String?
    let tags: [String]?
    let completed: Bool
    let dueDate: String?
    let reminderAt: Double?
    let reminderFiredAt: Double?
    let createdAt: Double
    let updatedAt: Double
    let sortOrder: Double

    var todoTask: TodoTask {
        TodoTask(
            id: _id,
            title: title,
            description: description,
            tags: TodoTask.normalizedTags((tags ?? []) + [dueDate].compactMap { $0 }),
            completed: completed,
            reminderAt: reminderAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            reminderFiredAt: reminderFiredAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            createdAt: Date(timeIntervalSince1970: createdAt / 1000),
            updatedAt: Date(timeIntervalSince1970: updatedAt / 1000),
            sortOrder: sortOrder
        )
    }
}
