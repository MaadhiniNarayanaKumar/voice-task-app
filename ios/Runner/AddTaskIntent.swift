import AppIntents
import Foundation

@available(iOS 16.0, *)
struct AddTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Task in Mia"
  static var description = IntentDescription("Adds a task in Mia from Siri or Shortcuts.")

  @Parameter(title: "Task")
  var task: String

  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    IntentChannel.shared.handle(text: task)
    return .result()
  }
}

@available(iOS 16.0, *)
struct MiaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddTaskIntent(),
      phrases: [
        "Add a task in \(.applicationName)",
        "Add a task with \(.applicationName)",
        "Create a task in \(.applicationName)",
      ],
      shortTitle: "Add task",
      systemImageName: "checkmark.circle"
    )
  }
}
