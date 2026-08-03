import AppKit

private final class FlippedInspectorDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class InfoInspectorView: NSView {
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let documentView = FlippedInspectorDocumentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -18),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(document: bbcatDocument) {
        clear()

        let heading = NSTextField(labelWithString: "Info")
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(heading)

        addSection("GENERAL", rows: [
            ("File", document.sourceURL.lastPathComponent),
            ("Format", document.info.format),
            ("File size", fileSize(for: document.sourceURL)),
        ])

        let info = document.info
        var artworkRows: [(String, String?)] = [
            ("Characters", "\(info.columns) × \(info.rows)"),
            ("Pixels", dimensions(width: info.pixelWidth, height: info.pixelHeight)),
            ("Glyph", "\(info.glyphWidth) × \(info.glyphHeight) px"),
            ("Content", info.raster ? "Raster graphics" : "Character art"),
            ("UTF-8", info.supportsUTF8 ? "Supported" : "Not supported"),
        ]
        if info.embeddedFont { artworkRows.append(("Font data", "Embedded")) }
        addSection("ARTWORK", rows: artworkRows)

        if document.isAnimated {
            addSection("ANIMATION", rows: [
                ("Frames", "\(document.frameCount)"),
                ("Export", "Animated GIF"),
            ])
        }

        if info.hasSauce {
            var sauceRows: [(String, String?)] = [
                ("Title", info.title),
                ("Author", info.author),
                ("Group", info.group),
                ("Date", formattedSauceDate(info.date)),
                ("Font", info.fontName),
            ]
            if info.sauceUsesICEColors { sauceRows.append(("iCE colors", "Enabled")) }
            if let spacing = info.sauceLetterSpacing {
                sauceRows.append(("Spacing", "\(spacing) pixels"))
            }
            addSection("SAUCE", rows: sauceRows)
        }
    }

    private func clear() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func addSection(_ title: String, rows: [(String, String?)]) {
        let rows = rows.compactMap { label, value -> (String, String)? in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
        guard !rows.isEmpty else { return }

        let titleView = NSTextField(labelWithString: title)
        titleView.font = .systemFont(ofSize: 10, weight: .semibold)
        titleView.textColor = .secondaryLabelColor

        let rowsView = NSStackView()
        rowsView.orientation = .vertical
        rowsView.alignment = .leading
        rowsView.spacing = 8
        for (label, value) in rows {
            rowsView.addArrangedSubview(makeRow(label: label, value: value))
        }

        let section = NSStackView(views: [titleView, rowsView])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        stack.addArrangedSubview(section)
        section.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        rowsView.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
    }

    private func makeRow(label: String, value: String) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor
        labelView.setContentCompressionResistancePriority(.required, for: .horizontal)
        labelView.widthAnchor.constraint(equalToConstant: 74).isActive = true

        let valueView = NSTextField(labelWithString: value)
        valueView.font = .systemFont(ofSize: 12)
        valueView.lineBreakMode = .byWordWrapping
        valueView.maximumNumberOfLines = 0
        valueView.isSelectable = true
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [labelView, valueView])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    private func dimensions(width: Int?, height: Int?) -> String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height) px"
    }

    private func fileSize(for url: URL) -> String? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func formattedSauceDate(_ date: String?) -> String? {
        guard let date, date.count == 8, date.allSatisfy(\.isNumber) else { return date }
        return "\(date.prefix(4))-\(date.dropFirst(4).prefix(2))-\(date.suffix(2))"
    }
}
