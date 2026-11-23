import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct SimplePDFMergerApp: App {
    var body: some Scene {
        WindowGroup("Simple PDF Merger") {
            MergerView()
                .frame(minWidth: 530, minHeight: 360)
        }
        .defaultSize(width: 630, height: 460)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PDFs to merge")
                    .font(.title2.bold())
                Spacer()
                Button(action: choosePDFs) {
                    Label("Add PDFs", systemImage: "plus")
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            .disabled(model.isMerging)

            List(selection: $model.selection) {
                ForEach(model.inputs) { input in
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(input.url.lastPathComponent)
                            Text(input.url.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 3)
                    } icon: {
                        Image(systemName: "doc")
                    }
                    .tag(input.id)
                }
            }
            .overlay {
                if model.inputs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 32))
                        Text("Drop PDFs here or click Add PDFs")
                    }
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                }
            }
            .border(model.isDropTarget ? Color.accentColor : Color.secondary.opacity(0.2))
            .dropDestination(for: URL.self) { urls, _ in
                guard !model.isMerging else { return false }
                return addPDFs(urls)
            } isTargeted: {
                model.isDropTarget = $0 && !model.isMerging
            }

            HStack(spacing: 10) {
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
                Button("Merge PDFs…", action: savePDF)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.inputs.count < 2)
            }
            .disabled(model.isMerging)

            if !model.status.isEmpty {
                Text(model.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(22)
        .alert("Couldn’t Merge PDFs", isPresented: $model.showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage)
        }
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
