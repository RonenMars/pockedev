import SwiftUI

// MARK: - NewProjectView (UI_SPEC: Home Screen → New Project)
// Modal sheet. One primary action: Create.
// DESIGN.md §5.4: One primary action per screen.

struct NewProjectView: View {
    @EnvironmentObject private var projectService: ProjectService
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Project) -> Void

    @State private var projectName: String = ""
    @State private var isNameFocused: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String? = nil

    @FocusState private var fieldFocused: Bool

    private var canCreate: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                PDTopBar(title: "New Project") {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(Tokens.Color.textSecondary)
                        .frame(height: 44)
                        .buttonStyle(.plain)
                }

                Divider().background(Tokens.Color.panel)

                // Form
                VStack(spacing: Tokens.Spacing.xxl) {
                    PDInput(
                        label: "Project Name",
                        placeholder: "e.g. my-app",
                        text: $projectName,
                        isFocused: fieldFocused
                    )
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit { attemptCreate() }

                    if let error = errorMessage {
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
                        title: "Create Project",
                        variant: .primary,
                        action: attemptCreate,
                        icon: "plus",
                        isLoading: isCreating
                    )
                    .frame(maxWidth: .infinity)
                    .disabled(!canCreate)
                    .opacity(canCreate ? 1 : 0.5)
                }
                .padding(Tokens.Spacing.xxl)
                .animation(.easeInOut(duration: Tokens.Motion.normal), value: errorMessage)

                Spacer()
            }
        }
        .onAppear { fieldFocused = true }
    }

    // MARK: - Create

    private func attemptCreate() {
        let name = projectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let project = try projectService.createProject(named: name)
                DispatchQueue.main.async {
                    isCreating = false
                    dismiss()
                    onCreated(project)
                }
            } catch {
                DispatchQueue.main.async {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
