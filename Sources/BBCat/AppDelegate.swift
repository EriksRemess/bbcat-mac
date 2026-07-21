import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewer = ViewerController()
    private let commandLineToolController = CommandLineToolController()

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
        let about = appMenu.addItem(
            withTitle: "About bbcat",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        appMenu.addItem(.separator())
        let installCommand = appMenu.addItem(
            withTitle: "Install or Update CLI…",
            action: #selector(CommandLineToolController.install),
            keyEquivalent: ""
        )
        installCommand.target = commandLineToolController
        let uninstallCommand = appMenu.addItem(
            withTitle: "Uninstall CLI…",
            action: #selector(CommandLineToolController.uninstall),
            keyEquivalent: ""
        )
        uninstallCommand.target = commandLineToolController
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

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(string: "bbcat.dev")
        credits.addAttribute(
            .link,
            value: URL(string: "https://bbcat.dev")!,
            range: NSRange(location: 0, length: credits.length)
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
