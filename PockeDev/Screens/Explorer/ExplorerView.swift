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

    // Create item state
    @State private var showNewItemAlert = false
    @State private var newItemIsFolder = false
    @State private var newItemName = ""
    @State private var newItemParent: URL? = nil

    // Delete state
    @State private var itemToDelete: FileItem? = nil
    @State private var showDeleteConfirm = false

    // Folder picker (move / copy)
    @State private var showFolderPicker = false
    @State private var isMoveOperation = true

    // Error state
    @State private var errorMessage = ""
    @State private var showError = false

    // Git panel
    @State private var showGitPanel = false
    @State private var showBranchPicker = false

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
                    subtitle: viewModel.isSelecting && !viewModel.selectedURLs.isEmpty
                        ? "\(viewModel.selectedURLs.count) selected"
                        : "Explorer",
                    leadingIcon: "chevron.left",
                    leadingAction: { dismiss() }
                ) {
                    HStack(spacing: 0) {
                        if viewModel.isSelecting {
                            Button("Cancel") {
                                viewModel.toggleSelectMode()
                            }
                            .font(.system(size: 14))
                            .foregroundColor(Tokens.Color.accent)
                            .frame(height: 44)
                            .padding(.trailing, Tokens.Spacing.sm)
                        } else {
                            // Branch button
                            if viewModel.isGitRepo, let branch = viewModel.currentBranch {
                                Button {
                                    showBranchPicker = true
                                } label: {
                                    Text(branch)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(Tokens.Color.textSecondary)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Tokens.Color.surface, in: Capsule())
                                }
                                .padding(.trailing, Tokens.Spacing.xs)
                            }

                            // Git button
                            if viewModel.isGitRepo {
                                Button {
                                    showGitPanel = true
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "arrow.triangle.branch")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(Tokens.Color.accent)
                                            .frame(width: 36, height: 44)

                                        if viewModel.gitChangedCount > 0 {
                                            Text("\(viewModel.gitChangedCount)")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 3)
                                                .background(Tokens.Color.error, in: Capsule())
                                                .offset(x: 4, y: 8)
                                        }
                                    }
                                }
                                .padding(.trailing, Tokens.Spacing.xs)
                            }

                            Button("Select") {
                                viewModel.toggleSelectMode()
                            }
                            .font(.system(size: 14))
                            .foregroundColor(Tokens.Color.accent)
                            .frame(height: 44)
                            .padding(.trailing, Tokens.Spacing.sm)

                            Menu {
                                Button {
                                    newItemIsFolder = false
                                    newItemParent = project.rootURL
                                    newItemName = ""
                                    showNewItemAlert = true
                                } label: {
                                    Label("New File", systemImage: "doc.badge.plus")
                                }
                                Button {
                                    newItemIsFolder = true
                                    newItemParent = project.rootURL
                                    newItemName = ""
                                    showNewItemAlert = true
                                } label: {
                                    Label("New Folder", systemImage: "folder.badge.plus")
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Tokens.Color.accent)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }

                Divider().background(Tokens.Color.panel)

                content

                if viewModel.isSelecting && !viewModel.selectedURLs.isEmpty {
                    bulkActionBar
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToEditor) {
            EditorContainerView()
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $showGitPanel, onDismiss: { viewModel.loadGitStatus() }) {
            GitCommitView(repoURL: project.rootURL)
        }
        .sheet(isPresented: $showBranchPicker, onDismiss: { viewModel.loadGitStatus() }) {
            BranchPickerView(repoURL: project.rootURL)
        }
        .alert(newItemIsFolder ? "New Folder" : "New File", isPresented: $showNewItemAlert) {
            TextField(newItemIsFolder ? "FolderName" : "filename.swift", text: $newItemName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Create") { commitCreate() }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            viewModel.isSelecting
                ? "Delete \(viewModel.selectedURLs.count) item\(viewModel.selectedURLs.count == 1 ? "" : "s")?"
                : "Delete \"\(itemToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { commitDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(
                rootURL: project.rootURL,
                fileService: FileService(),
                isMoveOperation: isMoveOperation
            ) { destination in
                do {
                    if isMoveOperation {
                        try viewModel.moveSelected(to: destination)
                    } else {
                        try viewModel.copySelected(to: destination)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    // MARK: - Create / Delete actions

    private func commitCreate() {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let parent = newItemParent else { return }
        do {
            if newItemIsFolder {
                try viewModel.createFolder(named: name, in: parent)
            } else {
                try viewModel.createFile(named: name, in: parent)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func commitDelete() {
        if viewModel.isSelecting {
            do {
                try viewModel.deleteSelected()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            guard let item = itemToDelete else { return }
            do {
                try viewModel.deleteItem(at: item.url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Bulk action bar

    private var bulkActionBar: some View {
        HStack {
            Spacer()
            Button {
                isMoveOperation = true
                showFolderPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 20))
                    Text("Move")
                        .font(.system(size: 11))
                }
                .foregroundColor(Tokens.Color.accent)
                .frame(maxWidth: .infinity)
            }
            Spacer()
            Button {
                isMoveOperation = false
                showFolderPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 20))
                    Text("Copy")
                        .font(.system(size: 11))
                }
                .foregroundColor(Tokens.Color.accent)
                .frame(maxWidth: .infinity)
            }
            Spacer()
            Button {
                showDeleteConfirm = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                    Text("Delete")
                        .font(.system(size: 11))
                }
                .foregroundColor(Tokens.Color.error)
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(.vertical, Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Tokens.Color.panel),
            alignment: .top
        )
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
                        isActive: sessionStore.activeSession?.fileURL == node.item.url,
                        isSelecting: viewModel.isSelecting,
                        isSelected: viewModel.selectedURLs.contains(node.item.url)
                    ) {
                        handleTap(node: node)
                    }
                    .contextMenu {
                        if !viewModel.isSelecting {
                            if node.item.isDirectory {
                                Button {
                                    newItemIsFolder = false
                                    newItemParent = node.item.url
                                    newItemName = ""
                                    showNewItemAlert = true
                                } label: {
                                    Label("New File", systemImage: "doc.badge.plus")
                                }
                                Button {
                                    newItemIsFolder = true
                                    newItemParent = node.item.url
                                    newItemName = ""
                                    showNewItemAlert = true
                                } label: {
                                    Label("New Folder", systemImage: "folder.badge.plus")
                                }
                                Divider()
                            }
                            Button(role: .destructive) {
                                itemToDelete = node.item
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
        if viewModel.isSelecting {
            viewModel.toggleSelection(url: node.item.url)
            return
        }
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
    @Published private(set) var isSelecting = false
    @Published private(set) var selectedURLs: Set<URL> = []
    @Published private(set) var isGitRepo = false
    @Published private(set) var gitChangedCount = 0
    @Published private(set) var currentBranch: String? = nil

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
        loadGitStatus()
    }

    func loadGitStatus() {
        let root = rootURL
        Task {
            let gitService = GitRepositoryService(repoURL: root)
            let isGit = await Task.detached(priority: .background) {
                gitService.isGitRepository()
            }.value
            isGitRepo = isGit
            guard isGit else { gitChangedCount = 0; currentBranch = nil; return }
            let count = await Task.detached(priority: .background) {
                (try? gitService.changedFiles())?.count ?? 0
            }.value
            gitChangedCount = count
            let branch = await Task.detached(priority: .background) {
                gitService.currentBranch()
            }.value
            currentBranch = branch
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

    // MARK: - Selection

    func toggleSelectMode() {
        isSelecting.toggle()
        selectedURLs.removeAll()
    }

    func toggleSelection(url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    // MARK: - Bulk operations

    func deleteSelected() throws {
        for url in selectedURLs {
            try fileService.deleteItem(at: url)
        }
        isSelecting = false
        selectedURLs.removeAll()
        load()
    }

    func moveSelected(to destination: URL) throws {
        for url in selectedURLs {
            try fileService.moveItem(from: url, to: destination)
        }
        isSelecting = false
        selectedURLs.removeAll()
        load()
    }

    func copySelected(to destination: URL) throws {
        for url in selectedURLs {
            try fileService.copyItem(from: url, to: destination)
        }
        isSelecting = false
        selectedURLs.removeAll()
        load()
    }

    // MARK: - Create / Delete

    func createFile(named name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        try fileService.createFile(at: url)
        load()
    }

    func createFolder(named name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        try fileService.createDirectory(at: url)
        load()
    }

    func deleteItem(at url: URL) throws {
        try fileService.deleteItem(at: url)
        load()
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

// MARK: - FolderPickerView

struct FolderPickerView: View {
    let rootURL: URL
    let fileService: FileService
    let isMoveOperation: Bool
    let onSelect: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var directories: [DirectoryItem] = []

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(rootURL)
                    dismiss()
                } label: {
                    Label("/ (project root)", systemImage: "house")
                        .foregroundColor(Tokens.Color.textPrimary)
                }

                ForEach(directories) { dir in
                    Button {
                        onSelect(dir.url)
                        dismiss()
                    } label: {
                        HStack(spacing: 0) {
                            if dir.depth > 0 {
                                Spacer().frame(width: CGFloat(dir.depth) * 20)
                            }
                            Label(dir.name, systemImage: "folder")
                                .foregroundColor(Tokens.Color.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle(isMoveOperation ? "Move To" : "Copy To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            directories = fileService.allDirectories(in: rootURL)
        }
    }
}
