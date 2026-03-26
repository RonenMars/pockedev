import SwiftUI
import Gitty

struct DiffView: View {
    let repoURL: URL
    let filePath: String

    @State private var diff: FileDiff?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let diff {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(diff.hunks.indices, id: \.self) { hunkIndex in
                            let hunk = diff.hunks[hunkIndex]
                            Text(hunk.header)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Tokens.Color.textSecondary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                            ForEach(hunk.lines.indices, id: \.self) { i in
                                let line = hunk.lines[i]
                                Text("\(line.origin) \(line.content)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(lineColor(line.origin))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(lineBg(line.origin))
                            }
                        }
                    }
                } else {
                    ProgressView().padding()
                }
            }
            .background(Tokens.Color.background)
            .navigationTitle(filePath)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { loadDiff() }
    }

    private func loadDiff() {
        guard let repo = try? Repository.open(at: repoURL) else { return }
        diff = (try? repo.diff(from: "HEAD"))?.first { $0.newPath == filePath || $0.oldPath == filePath }
    }

    private func lineColor(_ origin: Character) -> Color {
        switch origin {
        case "+": return Tokens.Color.success
        case "-": return Tokens.Color.error
        default:  return Tokens.Color.textPrimary
        }
    }

    private func lineBg(_ origin: Character) -> Color {
        switch origin {
        case "+": return Tokens.Color.success.opacity(0.08)
        case "-": return Tokens.Color.error.opacity(0.08)
        default:  return Color.clear
        }
    }
}
