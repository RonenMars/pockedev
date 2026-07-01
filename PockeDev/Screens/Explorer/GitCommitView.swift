import SwiftUI

// MARK: - GitCommitView

struct GitCommitView: View {
    @StateObject private var viewModel: GitCommitViewModel
    @Environment(\.dismiss) private var dismiss

    private let repoURL: URL
    @State private var diffFilePath = ""
    @State private var showDiff = false

    init(repoURL: URL) {
        self.repoURL = repoURL
        _viewModel = StateObject(wrappedValue: GitCommitViewModel(repoURL: repoURL))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.background.ignoresSafeArea()
                bodyContent
            }
            .navigationTitle("Source Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Tokens.Color.accent)
                }
            }
        }
        .task { viewModel.loadStatus() }
        .sheet(isPresented: $showDiff) {
            DiffView(repoURL: repoURL, filePath: diffFilePath)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.clearSuccess() } }
        )) {
            Button("OK") { viewModel.clearSuccess() }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    // MARK: - Body content

    @ViewBuilder
    private var bodyContent: some View {
        if viewModel.isLoading && viewModel.changedFiles.isEmpty {
            VStack {
                Spacer()
                ProgressView().tint(Tokens.Color.accent)
                Spacer()
            }
        } else if viewModel.changedFiles.isEmpty {
            cleanState
        } else {
            form
        }
    }

    // MARK: - Clean working tree

    private var cleanState: some View {
        VStack(spacing: Tokens.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundColor(Tokens.Color.success)
            Text("Nothing to commit")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Tokens.Color.textPrimary)
            Text("Working tree is clean.")
                .font(.system(size: 14))
                .foregroundColor(Tokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Form

    private var form: some View {
        Form {
            // Changed files
            Section {
                ForEach(viewModel.changedFiles) { file in
                    Button { viewModel.toggleFile(file.path) } label: {
                        fileRow(file)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            diffFilePath = file.path
                            showDiff = true
                        } label: {
                            Label("Diff", systemImage: "doc.text.magnifyingglass")
                        }
                        .tint(Tokens.Color.accent)
                    }
                }
            } header: {
                Text("Changed Files (\(viewModel.selectedPaths.count)/\(viewModel.changedFiles.count) staged)")
            }

            // Author
            Section("Author") {
                TextField("Name", text: $viewModel.authorName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Email", text: $viewModel.authorEmail)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }

            // Commit message
            Section("Message") {
                TextEditor(text: $viewModel.commitMessage)
                    .frame(minHeight: 72)
                    .font(.system(size: 14))
            }

            // Token
            Section("Token (required for push)") {
                SecureField("GitHub Personal Access Token", text: $viewModel.token)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Actions
            Section {
                actionButton(title: "Commit", color: Tokens.Color.accent) {
                    Task { await viewModel.commit() }
                }
                actionButton(title: "Commit & Push", color: Tokens.Color.success) {
                    Task { await viewModel.commitAndPush() }
                }
                actionButton(title: "Pull", color: Tokens.Color.textSecondary) {
                    Task { await viewModel.pull() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Subviews

    private func fileRow(_ file: GitStatusFile) -> some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: viewModel.selectedPaths.contains(file.path)
                  ? "checkmark.square.fill" : "square")
                .font(.system(size: 16))
                .foregroundColor(viewModel.selectedPaths.contains(file.path)
                                 ? Tokens.Color.accent : Tokens.Color.textSecondary)

            Text(file.path)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Tokens.Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(file.statusType.rawValue)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(statusColor(file.statusType))
        }
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            }
        }
        .disabled(viewModel.isLoading)
        .listRowBackground(color)
    }

    private func statusColor(_ type: GitStatusFile.StatusType) -> Color {
        switch type {
        case .modified:  return Tokens.Color.warning
        case .added:     return Tokens.Color.success
        case .deleted:   return Tokens.Color.error
        case .untracked: return Tokens.Color.textSecondary
        case .renamed:   return Tokens.Color.accent
        }
    }
}
