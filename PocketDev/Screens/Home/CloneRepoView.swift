import SwiftUI

// MARK: - CloneRepoView (UI_SPEC: Home Screen → Clone Repository)
// Modal sheet. Pure UI — all logic lives in CloneRepoViewModel.

struct CloneRepoView: View {
    @StateObject private var viewModel: CloneRepoViewModel
    @Environment(\.dismiss) private var dismiss

    private let onCloned: (Project) -> Void

    @State private var repoURL = ""
    @State private var token = ""
    @FocusState private var urlFocused: Bool

    init(projectService: ProjectService, onCloned: @escaping (Project) -> Void) {
        self.onCloned = onCloned
        _viewModel = StateObject(wrappedValue: CloneRepoViewModel(projectService: projectService))
    }

    private var canClone: Bool {
        !repoURL.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isCloning
    }

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                PDTopBar(title: "Clone Repository") {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(Tokens.Color.textSecondary)
                        .frame(height: 44)
                        .buttonStyle(.plain)
                        .disabled(viewModel.isCloning)
                }

                Divider().background(Tokens.Color.panel)

                if viewModel.isCloning {
                    cloningView
                } else {
                    formView
                }

                Spacer()
            }
        }
        .onAppear { urlFocused = true }
        .onChange(of: viewModel.completedProject) { project in
            guard let project else { return }
            dismiss()
            onCloned(project)
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: Tokens.Spacing.xxl) {
            PDInput(
                label: "Repository URL",
                placeholder: "https://github.com/user/repo",
                text: $repoURL,
                isFocused: urlFocused
            )
            .focused($urlFocused)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            tokenField

            if let error = viewModel.errorMessage {
                HStack(spacing: Tokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 13))
                }
                .foregroundColor(Tokens.Color.error)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            PDButton(
                title: "Clone",
                variant: .primary,
                action: { Task { await viewModel.clone(urlString: repoURL, token: token) } },
                icon: "arrow.down.circle"
            )
            .frame(maxWidth: .infinity)
            .disabled(!canClone)
            .opacity(canClone ? 1 : 0.5)
        }
        .padding(Tokens.Spacing.xxl)
        .animation(.easeInOut(duration: Tokens.Motion.normal), value: viewModel.errorMessage)
    }

    private var tokenField: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            HStack(spacing: Tokens.Spacing.xs) {
                Text("Access Token")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Tokens.Color.textSecondary)
                    .tracking(0.8)
                    .textCase(.uppercase)
                Text("· optional")
                    .font(.system(size: 11))
                    .foregroundColor(Tokens.Color.textSecondary.opacity(0.5))
            }
            SecureField("ghp_xxxxxxxxxxxx", text: $token)
                .font(.system(size: 16))
                .foregroundColor(Tokens.Color.textPrimary)
                .tint(Tokens.Color.accent)
                .padding(Tokens.Spacing.md)
                .background(Tokens.Color.panel)
                .cornerRadius(Tokens.Radius.small)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    // MARK: - Progress

    private var cloningView: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            Spacer()
            ProgressView()
                .tint(Tokens.Color.accent)
                .scaleEffect(1.5)
            Text(viewModel.progressMessage)
                .font(.system(size: 14))
                .foregroundColor(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Spacing.xxl)
            Spacer()
        }
    }
}
