import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewer = ViewerController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenus()
        viewer.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        let arguments = CommandLine.arguments.dropFirst()
        if let path = arguments.first { viewer.open(URL(fileURLWithPath: path)) }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if let path = filenames.first { viewer.open(URL(fileURLWithPath: path)) }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func configureMenus() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About bbcat", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit bbcat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        let open = fileMenu.addItem(withTitle: "Open…", action: Selector(("chooseFile")), keyEquivalent: "o")
        open.target = viewer
        NSApp.mainMenu = main
    }
}
