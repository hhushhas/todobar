import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var hotKey: HotKeyController!
    private var appState: AppState!
    private var auth: AuthController!
    private var reminders: ReminderController!
    private var effects: EffectsController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()

        let config = AppConfig.load()
        auth = AuthController(config: config)
        effects = EffectsController()
        reminders = ReminderController(effects: effects)

        appState = AppState(
            repository: LocalTaskRepository(),
            effects: effects,
            reminders: reminders,
            isCloudConfigured: false
        )
        auth.onRepositoryReady = { [weak appState] repository in
            appState?.switchToSyncedRepository(repository)
        }
        auth.onSignedOut = { [weak appState] in
            appState?.switchToLocalRepository()
        }
        reminders.bind(appState: appState)
        appState.load()

        statusBar = StatusBarController(appState: appState, auth: auth)
        statusBar.setup()

        if ProcessInfo.processInfo.environment["TODOBAR_SHOW_ON_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak statusBar] in
                statusBar?.togglePopover()
            }
        }

        if let preview = ProcessInfo.processInfo.environment["TODOBAR_PREVIEW_FEEDBACK"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak appState, weak effects] in
                switch preview {
                case "completion":
                    let title = "Ship the polished interaction"
                    appState?.newTaskTitle = title
                    appState?.addTask()
                    if let task = appState?.tasks.last, task.title == title, !task.completed {
                        appState?.toggle(task)
                    }
                case "reminder":
                    effects?.showReminder(title: "Review the agent's finished work")
                default:
                    break
                }
            }
        }

        hotKey = HotKeyController { [weak statusBar] in
            statusBar?.togglePopover()
        }
        hotKey.register()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit TodoBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")

        let redoItem = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]

        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
