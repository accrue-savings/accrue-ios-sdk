#if canImport(UIKit)
    import UIKit
    import QuickLook
    import MobileCoreServices

    public class StatementDownloader: NSObject, QLPreviewControllerDataSource {
        private var fileURL: URL?

        func downloadStatement(url: URL) {
            let task = URLSession.shared.downloadTask(with: url) { (tempURL, response, error) in
                guard let tempURL = tempURL, error == nil else {
                    print("Download error:", error ?? "Unknown error")
                    return
                }

                let fileManager = FileManager.default

                // Determine suggested file name
                var suggestedName: String = url.lastPathComponent
                var fileExtension: String?

                if let httpResponse = response as? HTTPURLResponse {
                    if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                        suggestedName = self.extractFileName(from: contentDisposition) ?? suggestedName
                    }
                    if let mimeType = httpResponse.mimeType {
                        fileExtension = self.fileExtension(for: mimeType)
                    }
                }

                // Append extension if missing
                if let ext = fileExtension,
                   suggestedName.range(of: "\\.[a-zA-Z0-9]+$", options: .regularExpression) == nil {
                    suggestedName += ".\(ext)"
                }

                let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(suggestedName)

                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.moveItem(at: tempURL, to: destinationURL)

                    DispatchQueue.main.async {
                        self.fileURL = destinationURL
                        self.presentPreviewOrShare(for: destinationURL)
                    }
                } catch {
                    print("File error:", error)
                }
            }
            task.resume()
        }

        // MARK: - Preview or Share
        private func presentPreviewOrShare(for fileURL: URL) {
            let previewController = QLPreviewController()
            previewController.dataSource = self

            if QLPreviewController.canPreview(fileURL as QLPreviewItem) {
                UIApplication.shared.windows.first?.rootViewController?.present(previewController, animated: true)
            } else {
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
            }
        }

        // MARK: - Helpers
        private func extractFileName(from contentDisposition: String) -> String? {
            let components = contentDisposition.components(separatedBy: ";")
            for comp in components {
                let trimmed = comp.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("filename=") {
                    var filename = trimmed.replacingOccurrences(of: "filename=", with: "")
                    filename = filename.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    return filename
                }
            }
            return nil
        }

        private func fileExtension(for mimeType: String) -> String? {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue(),
               let ext = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension)?.takeRetainedValue() {
                return ext as String
            }
            return nil
        }

        // MARK: - QLPreviewControllerDataSource
        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return fileURL != nil ? 1 : 0
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL! as QLPreviewItem
        }
    }
#endif
