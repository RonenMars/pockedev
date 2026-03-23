import SwiftUI
import UniformTypeIdentifiers

// MARK: - DocumentPickerView
// UIKit wrapper for UIDocumentPickerViewController.
// ARCHITECTURE.md: UIKit allowed where technically justified.
// Used by HomeView for "Open File" and "Open Folder".

struct DocumentPickerView: UIViewControllerRepresentable {

    enum PickerMode {
        case file    // picks a single file of any type
        case folder  // picks a directory
    }

    let mode: PickerMode
    var onPick: (URL) -> Void

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = mode == .folder ? [.folder] : [.item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        // Cancellation: no-op — sheet dismisses automatically
    }
}
