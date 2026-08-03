import Foundation

enum CommandLineToolState: Equatable {
    case missing
    case installed
    case otherLink(String)
    case occupied
}

enum CommandLineToolError: LocalizedError {
    case bundledToolMissing
    case destinationOccupied(URL)
    case destinationNotManaged(URL)

    var errorDescription: String? {
        switch self {
        case .bundledToolMissing:
            "The CLI is missing from this copy of bbcat."
        case .destinationOccupied(let url):
            "A file already exists at \(url.path). Move or remove it before installing bbcat."
        case .destinationNotManaged(let url):
            "bbcat did not remove \(url.path) because that CLI is not managed by this app."
        }
    }
}

struct CommandLineToolInstaller {
    let bundleURL: URL
    let homeDirectoryURL: URL
    let fileManager: FileManager

    init(
        bundleURL: URL = Bundle.main.bundleURL,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.bundleURL = bundleURL
        self.homeDirectoryURL = homeDirectoryURL
        self.fileManager = fileManager
    }

    var bundledToolURL: URL {
        bundleURL.appendingPathComponent("Contents/Helpers/bbcat", isDirectory: false)
    }

    var installDirectoryURL: URL {
        homeDirectoryURL.appendingPathComponent(".local/bin", isDirectory: true)
    }

    var installedToolURL: URL {
        installDirectoryURL.appendingPathComponent("bbcat", isDirectory: false)
    }

    func state() -> CommandLineToolState {
        do {
            let destination = try fileManager.destinationOfSymbolicLink(atPath: installedToolURL.path)
            let destinationURL = URL(fileURLWithPath: destination, relativeTo: installDirectoryURL)
                .standardizedFileURL
            return destinationURL.path == bundledToolURL.standardizedFileURL.path
                ? .installed
                : .otherLink(destination)
        } catch {
            return fileManager.fileExists(atPath: installedToolURL.path) ? .occupied : .missing
        }
    }

    func install(replacingLink: Bool) throws {
        guard fileManager.isExecutableFile(atPath: bundledToolURL.path) else {
            throw CommandLineToolError.bundledToolMissing
        }
        try fileManager.createDirectory(
            at: installDirectoryURL,
            withIntermediateDirectories: true
        )

        switch state() {
        case .missing:
            break
        case .installed:
            return
        case .occupied:
            throw CommandLineToolError.destinationOccupied(installedToolURL)
        case .otherLink(let oldDestination):
            guard replacingLink else {
                throw CommandLineToolError.destinationNotManaged(installedToolURL)
            }
            try fileManager.removeItem(at: installedToolURL)
            do {
                try fileManager.createSymbolicLink(
                    at: installedToolURL,
                    withDestinationURL: bundledToolURL
                )
            } catch {
                try? fileManager.createSymbolicLink(
                    atPath: installedToolURL.path,
                    withDestinationPath: oldDestination
                )
                throw error
            }
            return
        }

        try fileManager.createSymbolicLink(
            at: installedToolURL,
            withDestinationURL: bundledToolURL
        )
    }

    func uninstall() throws {
        switch state() {
        case .installed:
            try fileManager.removeItem(at: installedToolURL)
        case .missing:
            return
        case .otherLink, .occupied:
            throw CommandLineToolError.destinationNotManaged(installedToolURL)
        }
    }
}
