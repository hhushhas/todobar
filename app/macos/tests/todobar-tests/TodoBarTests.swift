import XCTest
@testable import TodoBar

final class TodoBarTests: XCTestCase {
    func testTagsAreTrimmedDeduplicatedAndLoseLeadingHashes() {
        XCTAssertEqual(
            TodoTask.normalizedTags([" Prompt ", "#work", "prompt", "##agent", " "]),
            ["Prompt", "work", "agent"]
        )
    }

    func testLegacyDueTextMigratesToATag() throws {
        let data = Data(
            """
            {
              "id": "legacy",
              "title": "Old task",
              "completed": false,
              "dueDate": "Client",
              "createdAt": "2026-07-17T12:00:00Z",
              "updatedAt": "2026-07-17T12:00:00Z",
              "sortOrder": 1
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let task = try decoder.decode(TodoTask.self, from: data)

        XCTAssertEqual(task.tags, ["Client"])
    }

    func testReminderIsDueOnlyForActiveUnfiredTasks() {
        XCTAssertTrue(TodoTask(title: "A", reminderAt: Date().addingTimeInterval(-1)).reminderIsDue)
        XCTAssertFalse(TodoTask(title: "B", completed: true, reminderAt: Date().addingTimeInterval(-1)).reminderIsDue)
        XCTAssertFalse(TodoTask(title: "C", reminderAt: Date().addingTimeInterval(60)).reminderIsDue)
        XCTAssertFalse(TodoTask(title: "D", reminderAt: Date().addingTimeInterval(-1), reminderFiredAt: Date()).reminderIsDue)
    }

    @MainActor
    func testActiveTaskPriorityRanksFollowPersistedSortOrder() async {
        let tasks = [
            TodoTask(id: "third", title: "Third", sortOrder: 30),
            TodoTask(id: "first", title: "First", sortOrder: 10),
            TodoTask(id: "done", title: "Done", completed: true, sortOrder: 5),
            TodoTask(id: "second", title: "Second", sortOrder: 20),
        ]
        let appState = makeAppState(repository: InMemoryTaskRepository(tasks: tasks))

        appState.load()
        await Task.yield()

        XCTAssertEqual(appState.activeTasks.map(\.id), ["first", "second", "third"])
        XCTAssertEqual(appState.priorityRank(for: "first"), 1)
        XCTAssertEqual(appState.priorityRank(for: "second"), 2)
        XCTAssertEqual(appState.priorityRank(for: "third"), 3)
        XCTAssertNil(appState.priorityRank(for: "done"))
    }

    @MainActor
    func testDraggingTaskChangesPriorityOrderAndPersistsIt() async {
        let tasks = [
            TodoTask(id: "first", title: "First", sortOrder: 10),
            TodoTask(id: "second", title: "Second", sortOrder: 20),
            TodoTask(id: "third", title: "Third", sortOrder: 30),
        ]
        let repository = InMemoryTaskRepository(tasks: tasks)
        let appState = makeAppState(repository: repository)

        appState.load()
        await Task.yield()
        appState.moveActiveTask("third", to: "first")
        await Task.yield()

        XCTAssertEqual(appState.activeTasks.map(\.id), ["third", "first", "second"])
        XCTAssertEqual(appState.priorityRank(for: "third"), 1)
        XCTAssertEqual(repository.tasks.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id), ["third", "first", "second"])
    }

    @MainActor
    func testTogglingCompletedTaskRestoresItToActiveTasks() async {
        let task = TodoTask(id: "done", title: "Done", completed: true)
        let repository = InMemoryTaskRepository(tasks: [task])
        let appState = makeAppState(repository: repository)

        appState.load()
        await Task.yield()

        appState.toggle(task)
        await Task.yield()

        XCTAssertEqual(appState.activeTasks.map(\.id), ["done"])
        XCTAssertTrue(appState.completedTasks.isEmpty)
        XCTAssertEqual(repository.completedUpdates, [false])
    }

    @MainActor
    func testUpdatingTaskPersistsDescriptionTagsAndReminder() async {
        let task = TodoTask(id: "prompt", title: "Draft prompt")
        let repository = InMemoryTaskRepository(tasks: [task])
        let appState = makeAppState(repository: repository)
        let reminderAt = Date().addingTimeInterval(3600)

        appState.load()
        await Task.yield()
        appState.update(
            task,
            title: "Draft prompt",
            description: "  Ask the agent to review the diff.  ",
            tags: ["#Prompt", "work", "prompt"],
            reminderAt: reminderAt
        )
        await Task.yield()

        XCTAssertEqual(appState.tasks.first?.description, "Ask the agent to review the diff.")
        XCTAssertEqual(appState.tasks.first?.tags, ["Prompt", "work"])
        XCTAssertEqual(appState.tasks.first?.reminderAt, reminderAt)
        XCTAssertEqual(repository.tasks.first, appState.tasks.first)
    }

    @MainActor
    private func makeAppState(repository: InMemoryTaskRepository) -> AppState {
        let effects = EffectsController()
        let reminders = ReminderController(effects: effects, requestNotificationAuthorization: false)
        return AppState(repository: repository, effects: effects, reminders: reminders, isCloudConfigured: false)
    }
}

@MainActor
private final class InMemoryTaskRepository: TaskRepository {
    private(set) var tasks: [TodoTask]
    private(set) var completedUpdates: [Bool] = []

    init(tasks: [TodoTask]) {
        self.tasks = tasks
    }

    func loadTasks() async throws -> [TodoTask] {
        tasks
    }

    func createTask(_ task: TodoTask) async throws -> TodoTask {
        tasks.append(task)
        return task
    }

    func updateTask(_ task: TodoTask) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
    }

    func setCompleted(_ task: TodoTask, completed: Bool) async throws {
        completedUpdates.append(completed)
        var updated = task
        updated.completed = completed
        try await updateTask(updated)
    }

    func deleteTask(_ task: TodoTask) async throws {
        tasks.removeAll { $0.id == task.id }
    }

    func markReminderFired(_ task: TodoTask) async throws {
        var updated = task
        updated.reminderFiredAt = Date()
        try await updateTask(updated)
    }
}
