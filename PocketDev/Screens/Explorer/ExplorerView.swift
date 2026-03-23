import SwiftUI

// MARK: - ExplorerView (UI_SPEC: Explorer)
// States: loading, empty, populated, error
// Tap file → opens session + navigates to editor.
// Tap folder → expands/collapses inline (depth-indented).

struct ExplorerView: View {
    @EnvironmentObject private var sessionStore: DocumentSessionStore
    @Environment(\.dismiss) private var dismiss

    let project: Project

    @StateObject private var viewModel: ExplorerViewModel
    @State private var navigateToEditor = false

    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: ExplorerViewModel(
            rootURL: project.rootURL,
            fileService: FileService()
        ))
    }

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                PDTopBar(
                    title: project.name,
                    subtitle: "Explorer",
                    leadingIcon: "chevron.left",
                    leadingAction: { dismiss() }
                )

                Divider().background(Tokens.Color.panel)

                content
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToEditor) {
            EditorContainerView()
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear

        case .loading:
            VStack {
                Spacer()
                ProgressView().tint(Tokens.Color.accent)
                Spacer()
            }

        case .loaded:
            fileList

        case .empty:
            PDEmptyState(
                icon: "doc.badge.plus",
                title: "No files",
                message: "This project is empty."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let msg):
            PDEmptyState(
                icon: "exclamationmark.triangle",
                title: "Cannot load files",
                message: msg,
                actionTitle: "Retry"
            ) { viewModel.load() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - File list

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.flatItems) { node in
                    FileRow(
                        item: node.item,
                        depth: node.depth,
                        isActive: sessionStore.activeSession?.fileURL == node.item.url
                    ) {
                        handleTap(node: node)
                    }

                    Divider()
                        .background(Tokens.Color.panel.opacity(0.5))
                        .padding(.leading, Tokens.Spacing.lg + CGFloat(node.depth) * 16 + 26)
                }
            }
        }
    }

    // MARK: - Tap handler

    private func handleTap(node: ExplorerNode) {
        if node.item.isDirectory {
            withAnimation(.easeInOut(duration: Tokens.Motion.micro)) {
                viewModel.toggle(node: node)
            }
        } else {
            sessionStore.openFile(at: node.item.url)
            navigateToEditor = true
        }
    }
}

// MARK: - ExplorerNode

struct ExplorerNode: Identifiable {
    var id: URL { item.url }
    let item: FileItem
    let depth: Int
}

// MARK: - ExplorerViewModel

@MainActor
final class ExplorerViewModel: ObservableObject {
    enum State {
        case idle, loading, loaded, empty
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var flatItems: [ExplorerNode] = []

    private let rootURL: URL
    private let fileService: FileService

    // Expansion state keyed by rootURL — survives view recreation when user
    // navigates back to Home and re-enters the same project.
    // @MainActor on the class guarantees all accesses are on the main thread.
    private static var expansionCache: [URL: Set<URL>] = [:]

    private var expandedDirs: Set<URL> {
        get { ExplorerViewModel.expansionCache[rootURL] ?? [] }
        set { ExplorerViewModel.expansionCache[rootURL] = newValue }
    }

    init(rootURL: URL, fileService: FileService) {
        self.rootURL = rootURL
        self.fileService = fileService
    }

    // MARK: - Load

    func load() {
        state = .loading
        Task {
            do {
                let items = try fileService.listItems(in: rootURL)
                if items.isEmpty {
                    state = .empty
                } else {
                    flatItems = buildFlat(items: items, depth: 0)
                    state = .loaded
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Toggle

    func toggle(node: ExplorerNode) {
        guard node.item.isDirectory else { return }
        if expandedDirs.contains(node.item.url) {
            collapse(dirURL: node.item.url)
        } else {
            expand(node: node)
        }
    }

    // MARK: - Expand / collapse

    private func expand(node: ExplorerNode) {
        guard let children = try? fileService.listItems(in: node.item.url) else { return }
        expandedDirs.insert(node.item.url)
        guard let insertAt = flatItems.firstIndex(where: { $0.id == node.id }) else { return }
        let childNodes = buildFlat(items: children, depth: node.depth + 1)
        flatItems.insert(contentsOf: childNodes, at: insertAt + 1)
    }

    private func collapse(dirURL: URL) {
        expandedDirs.remove(dirURL)
        // Remove all descendants
        flatItems.removeAll { $0.item.url.path.hasPrefix(dirURL.path + "/") }
        // Also collapse any nested expanded dirs that were under this one
        expandedDirs = expandedDirs.filter { !$0.path.hasPrefix(dirURL.path + "/") }
    }

    // MARK: - Flat list builder

    private func buildFlat(items: [FileItem], depth: Int) -> [ExplorerNode] {
        var result: [ExplorerNode] = []
        for item in items {
            result.append(ExplorerNode(item: item, depth: depth))
            if item.isDirectory && expandedDirs.contains(item.url) {
                let sub = (try? fileService.listItems(in: item.url)) ?? []
                result += buildFlat(items: sub, depth: depth + 1)
            }
        }
        return result
    }
}
