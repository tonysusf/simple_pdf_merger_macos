import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct SimplePDFMergerApp: App {
    var body: some Scene {
        WindowGroup("Simple PDF Merger") {
            MergerView()
                .frame(minWidth: 550, minHeight: 400)
        }
        .defaultSize(width: 660, height: 480)
    }
}

private struct MergerView: View {
    private struct Input: Identifiable {
        let id = UUID()
        let url: URL
    }

    private final class Model: ObservableObject {
        @Published var inputs: [Input] = []
        @Published var selection: Input.ID?
        @Published var isMerging = false
        @Published var isDropTarget = false
        @Published var status = ""
        @Published var errorMessage = ""
        @Published var showsError = false
    }

    @StateObject private var model = Model()

    private var selectedIndex: Int? {
        model.inputs.firstIndex { $0.id == model.selection }
    }

    private static let logo = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap { NSImage(contentsOf: $0) }
    private let indigo = Color(red: 0.32, green: 0.31, blue: 0.88)
    private let cyan = Color(red: 0.16, green: 0.72, blue: 0.93)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            workspace
            actions

            if !model.status.isEmpty {
                Label(model.status, systemImage: model.isMerging ? "clock" : "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(24)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [indigo.opacity(0.13), cyan.opacity(0.07), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
        .tint(indigo)
        .alert("Couldn’t Merge PDFs", isPresented: $model.showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let logo = Self.logo {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Simple PDF Merger")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                Text("Combine multiple PDFs into one file.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: choosePDFs) {
                Label("Add PDFs", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)
            .disabled(model.isMerging)
        }
    }

    private var workspace: some View {
        let outline = RoundedRectangle(cornerRadius: 18)
        let isEmpty = model.inputs.isEmpty

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Merge order")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(model.inputs.count == 1 ? "1 PDF" : "\(model.inputs.count) PDFs")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 3)

            Group {
                if isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                outline.fill(Color(nsColor: .controlBackgroundColor))
                outline.fill(indigo.opacity(model.isDropTarget ? 0.14 : 0.035))
            }
            .clipShape(outline)
            .overlay {
                outline.strokeBorder(
                    model.isDropTarget ? indigo : Color.secondary.opacity(isEmpty ? 0.45 : 0.20),
                    style: StrokeStyle(lineWidth: model.isDropTarget ? 2 : 1, dash: isEmpty ? [6, 5] : [])
                )
                .allowsHitTesting(false)
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !model.isMerging else { return false }
                return addPDFs(urls)
            } isTargeted: {
                model.isDropTarget = $0 && !model.isMerging
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: model.isDropTarget ? "arrow.down.doc.fill" : "doc.on.doc")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [cyan.opacity(0.28), indigo.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .accessibilityHidden(true)
                .padding(.bottom, 4)
            Text(model.isDropTarget ? "Release to add PDFs" : "Drop PDFs here")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("Or choose files with Add PDFs")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var fileList: some View {
        List(selection: $model.selection) {
            ForEach(Array(model.inputs.enumerated()), id: \.element.id) { index, input in
                HStack(spacing: 10) {
                    Text((index + 1).formatted())
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 24)
                    Image(systemName: "doc.fill")
                        .font(.body)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(input.url.lastPathComponent)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(input.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 6)
                .tag(input.id)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(5)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Move Up", systemImage: "arrow.up") { move(by: -1) }
                .disabled((selectedIndex ?? 0) == 0)
            Button("Move Down", systemImage: "arrow.down") { move(by: 1) }
                .disabled(selectedIndex.map { $0 == model.inputs.count - 1 } ?? true)
            Button("Remove", systemImage: "trash", action: removeSelected)
                .disabled(selectedIndex == nil)
            Spacer()
            if model.isMerging {
                ProgressView().controlSize(.small)
            }
            Button("Merge PDFs…", systemImage: "arrow.triangle.merge", action: savePDF)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.inputs.count < 2)
        }
        .controlSize(.large)
        .disabled(model.isMerging)
    }

    private func choosePDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            _ = addPDFs(panel.urls)
        }
    }

    private func addPDFs(_ urls: [URL]) -> Bool {
        let pdfs = urls.filter { $0.isFileURL && $0.pathExtension.lowercased() == "pdf" }
        guard !pdfs.isEmpty else { return false }
        model.inputs.append(contentsOf: pdfs.map { Input(url: $0) })
        model.status = ""
        return true
    }

    private func move(by offset: Int) {
        guard let index = selectedIndex, model.inputs.indices.contains(index + offset) else { return }
        model.inputs.swapAt(index, index + offset)
        model.status = ""
    }

    private func removeSelected() {
        guard let index = selectedIndex else { return }
        model.inputs.remove(at: index)
        model.selection = model.inputs.isEmpty ? nil : model.inputs[min(index, model.inputs.count - 1)].id
        model.status = ""
    }

    private func savePDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Merged.pdf"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let urls = model.inputs.map(\.url)
        let resolvedDestination = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard !urls.contains(where: {
            $0.standardizedFileURL.resolvingSymlinksInPath() == resolvedDestination
        }) else {
            model.errorMessage = "Choose a different filename to keep the original PDF."
            model.showsError = true
            return
        }

        model.isMerging = true
        model.status = "Merging PDFs…"
        Task {
            defer { model.isMerging = false }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PDFMerger.merge(urls, to: destination)
                }.value
                model.status = "Saved \(destination.lastPathComponent)"
            } catch {
                model.status = ""
                model.errorMessage = error.localizedDescription
                model.showsError = true
            }
        }
    }
}
