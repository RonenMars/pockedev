import SwiftUI
import Gitty

struct BranchPickerView: View {
    let repoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var branches: [Branch] = []
    @State private var current: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List(branches) { branch in
                Button {
                    checkout(branch)
                } label: {
                    HStack {
                        Text(branch.name)
                            .foregroundColor(Tokens.Color.textPrimary)
                        Spacer()
                        if branch.name == current {
                            Image(systemName: "checkmark")
                                .foregroundColor(Tokens.Color.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Branches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { loadBranches() }
    }

    private func loadBranches() {
        guard let repo = try? Repository.open(at: repoURL) else { return }
        current = repo.currentBranch
        branches = (try? repo.branches.list()) ?? []
    }

    private func checkout(_ branch: Branch) {
        guard let repo = try? Repository.open(at: repoURL) else { return }
        try? repo.branches.checkout(branch)
        dismiss()
    }
}
