import Foundation
import PDFKit

enum PDFMerger {
    enum MergeError: LocalizedError {
        case unreadable(URL)
        case locked(URL)
        case empty(URL)
        case pageUnavailable(URL, Int)
        case outputUnavailable

        var errorDescription: String? {
            switch self {
            case .unreadable(let url):
                return "Couldn’t open \(url.lastPathComponent)."
            case .locked(let url):
                return "\(url.lastPathComponent) is password-protected."
            case .empty(let url):
                return "\(url.lastPathComponent) has no pages."
            case .pageUnavailable(let url, let index):
                return "Couldn’t copy page \(index + 1) of \(url.lastPathComponent)."
            case .outputUnavailable:
                return "Couldn’t create the merged PDF."
            }
        }
    }

    static func merge(_ urls: [URL], to destination: URL) throws {
        let merged = PDFDocument()
        var sources: [PDFDocument] = []

        for url in urls {
            guard let source = PDFDocument(url: url) else {
                throw MergeError.unreadable(url)
            }
            guard !source.isLocked else { throw MergeError.locked(url) }
            guard source.pageCount > 0 else { throw MergeError.empty(url) }
            sources.append(source)

            for index in 0..<source.pageCount {
                guard let page = source.page(at: index)?.copy() as? PDFPage else {
                    throw MergeError.pageUnavailable(url, index)
                }
                merged.insert(page, at: merged.pageCount)
            }
        }

        guard let data = withExtendedLifetime(sources, {
            merged.pageCount > 0 ? merged.dataRepresentation() : nil
        }) else {
            throw MergeError.outputUnavailable
        }
        try data.write(to: destination, options: .atomic)
    }
}
