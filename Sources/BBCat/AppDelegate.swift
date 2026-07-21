import AppKit
import CoreServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let viewer = ViewerController()
    private let commandLineToolController = CommandLineToolController()
    private var cliMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
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
        appMenu.delegate = self
        appItem.submenu = appMenu
        let about = appMenu.addItem(
            withTitle: "About bbcat",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        appMenu.addItem(.separator())
        let cliCommand = NSMenuItem()
        cliCommand.target = commandLineToolController
        appMenu.addItem(cliCommand)
        cliMenuItem = cliCommand
        configureCLICommand()
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

    func menuWillOpen(_ menu: NSMenu) {
        configureCLICommand()
    }

    private func configureCLICommand() {
        guard let cliMenuItem else { return }
        if case .installed = CommandLineToolInstaller().state() {
            cliMenuItem.title = "Uninstall CLI…"
            cliMenuItem.action = #selector(CommandLineToolController.uninstall)
        } else {
            cliMenuItem.title = "Install CLI…"
            cliMenuItem.action = #selector(CommandLineToolController.install)
        }
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
