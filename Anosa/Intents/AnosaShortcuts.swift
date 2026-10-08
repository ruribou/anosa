import AppIntents

struct AnosaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveToAnosaIntent(),
            phrases: ["\(.applicationName)に保存"],
            shortTitle: "Anosaに保存",
            systemImageName: "mappin.and.ellipse"
        )
    }
}
