import Foundation

let fileManager = FileManager.default
let root = fileManager.temporaryDirectory
    .appendingPathComponent("bbcat-command-test-\(UUID().uuidString)", isDirectory: true)
defer { try? fileManager.removeItem(at: root) }

let bundle = root.appendingPathComponent("bbcat.app", isDirectory: true)
let bundledTool = bundle.appendingPathComponent("Contents/Helpers/bbcat", isDirectory: false)
let home = root.appendingPathComponent("home", isDirectory: true)
try fileManager.createDirectory(at: bundledTool.deletingLastPathComponent(), withIntermediateDirectories: true)
try Data("test executable".utf8).write(to: bundledTool)
try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundledTool.path)

let installer = CommandLineToolInstaller(
    bundleURL: bundle,
    homeDirectoryURL: home,
    fileManager: fileManager
)

precondition(installer.state() == .missing)
try installer.install(replacingLink: false)
precondition(installer.state() == .installed)
let installedDestination = try fileManager.destinationOfSymbolicLink(
    atPath: installer.installedToolURL.path
)
precondition(installedDestination == bundledTool.path)

try installer.install(replacingLink: false)
precondition(installer.state() == .installed)
try installer.uninstall()
precondition(installer.state() == .missing)

try fileManager.createDirectory(at: installer.installDirectoryURL, withIntermediateDirectories: true)
try fileManager.createSymbolicLink(
    atPath: installer.installedToolURL.path,
    withDestinationPath: "../somewhere-else/bbcat"
)
precondition(installer.state() == .otherLink("../somewhere-else/bbcat"))
do {
    try installer.install(replacingLink: false)
    preconditionFailure("An unmanaged link was replaced without permission")
} catch CommandLineToolError.destinationNotManaged {
    // Expected.
}
try installer.install(replacingLink: true)
precondition(installer.state() == .installed)
try installer.uninstall()

try Data("existing command".utf8).write(to: installer.installedToolURL)
precondition(installer.state() == .occupied)
do {
    try installer.install(replacingLink: true)
    preconditionFailure("A regular file was overwritten")
} catch CommandLineToolError.destinationOccupied {
    // Expected.
}
let existingContents = try String(contentsOf: installer.installedToolURL, encoding: .utf8)
precondition(existingContents == "existing command")

print("CLI installer tests passed")
