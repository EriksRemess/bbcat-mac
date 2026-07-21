import AppKit

final class CommandLineToolController: NSObject {
    @objc func install() {
        let installer = CommandLineToolInstaller()
        switch installer.state() {
        case .installed:
            showMessage(
                title: "CLI Is Up to Date",
                message: "bbcat is installed at \(installer.installedToolURL.path)."
            )
            return
        case .occupied:
            present(CommandLineToolError.destinationOccupied(installer.installedToolURL))
            return
        case .otherLink(let destination):
            let alert = NSAlert()
            alert.messageText = "Replace Existing bbcat Link?"
            alert.informativeText = "\(installer.installedToolURL.path) currently points to \(destination)."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Replace Link")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            performInstall(installer, replacingLink: true)
        case .missing:
            performInstall(installer, replacingLink: false)
        }
    }

    @objc func uninstall() {
        let installer = CommandLineToolInstaller()
        guard case .installed = installer.state() else {
            showMessage(
                title: "CLI Is Not Installed",
                message: "No bbcat link managed by this app was found at \(installer.installedToolURL.path)."
            )
            return
        }

        let alert = NSAlert()
        alert.messageText = "Uninstall CLI?"
        alert.informativeText = "This removes the link at \(installer.installedToolURL.path)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try installer.uninstall()
            showMessage(
                title: "CLI Uninstalled",
                message: "The bbcat command was removed from \(installer.installedToolURL.path)."
            )
        } catch {
            present(error)
        }
    }

    private func performInstall(_ installer: CommandLineToolInstaller, replacingLink: Bool) {
        do {
            try installer.install(replacingLink: replacingLink)
            var message = "bbcat is available at \(installer.installedToolURL.path)."
            message += "\n\nIf a new Terminal window cannot find bbcat, add ~/.local/bin to your shell PATH."
            if !Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
                message += "\n\nKeep bbcat.app in its current location or reinstall the command after moving it."
            }
            showMessage(title: "CLI Installed", message: message)
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private func showMessage(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
