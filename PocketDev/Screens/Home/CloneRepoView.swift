import SwiftUI

// MARK: - CloneRepoView (UI_SPEC: Home Screen → Clone Repository)
// Modal sheet. Pure UI — all logic lives in CloneRepoViewModel.

struct CloneRepoView: View {
    @StateObject private var viewModel: CloneRepoViewModel
    @Environment(\.dismiss) private var dismiss

    private let onCloned: (Project) -> Void

    @State private var repoURL = ""
    @State private var token = ""
    @State private var rememberToken = false
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
                        .padding(.horizontal, Tokens.Spacing.md)
                        .contentShape(Rectangle())
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
        .onAppear {
            urlFocused = true
            if let saved = KeychainService.loadToken() {
                token = saved
                rememberToken = true
            }
        }
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
                action: { Task { await viewModel.clone(urlString: repoURL, token: token, rememberToken: rememberToken) } },
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

            Button {
                rememberToken.toggle()
            } label: {
                HStack(spacing: Tokens.Spacing.sm) {
                    Image(systemName: rememberToken ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(rememberToken ? Tokens.Color.accent : Tokens.Color.textSecondary)
                    Text("Remember token")
                        .font(.system(size: 13))
                        .foregroundColor(Tokens.Color.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Progress

    private var cloningView: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            Spacer()

            VStack(spacing: Tokens.Spacing.lg) {
                // Phase label + percentage
                HStack {
                    Text(viewModel.progressMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Tokens.Color.textSecondary)
                    Spacer()
                    Text("\(Int(viewModel.cloneProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundColor(Tokens.Color.accent)
                }

                // Progress bar track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Tokens.Color.panel)
                            .frame(height: 6)

                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Tokens.Color.accent)
                            .frame(width: geo.size.width * viewModel.cloneProgress, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.cloneProgress)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, Tokens.Spacing.xxl)

            Spacer()
        }
    }
}
