import Foundation
import libgit2

// MARK: - GitCloning Protocol

protocol GitCloning {
    func cloneRepository(
        from urlString: String,
        token: String?,
        to destinationURL: URL,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws
}

// MARK: - GitCloneService

// Thin wrapper around git_clone (libgit2).
// All protocol negotiation, PACK handling, delta resolution, and checkout
// are handled by libgit2 — this file contains no custom Git protocol logic.

actor GitCloneService: GitCloning {

    func cloneRepository(
        from urlString: String,
        token: String?,
        to destinationURL: URL,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws {
        var urlStr = urlString.trimmingCharacters(in: .whitespaces)
        if !urlStr.hasSuffix(".git") { urlStr += ".git" }
        guard URL(string: urlStr) != nil else { throw GitCloneError.invalidURL }

        let dest = destinationURL, tok = token
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Task.detached(priority: .userInitiated) {
                do {
                    try libgit2Clone(urlStr: urlStr, destination: dest, token: tok, onProgress: onProgress)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - git_clone (free function, background thread)
// Libgit2Manager.initialize() must have been called before this runs.

private func libgit2Clone(
    urlStr: String,
    destination: URL,
    token: String?,
    onProgress: (@Sendable (Double) -> Void)?
) throws {
    var options = git_clone_options()
    git_clone_init_options(&options, UInt32(GIT_CLONE_OPTIONS_VERSION))
    options.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

    let ctx    = CloneContext(token: token, onProgress: onProgress)
    let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()

    // Always attach payload so transfer_progress fires regardless of auth
    options.fetch_opts.callbacks.transfer_progress = transferProgressCallback
    options.fetch_opts.callbacks.payload           = ctxPtr

    // Checkout progress (80 %→100 %)
    options.checkout_opts.progress_cb      = checkoutProgressCallback
    options.checkout_opts.progress_payload = ctxPtr

    // Credentials — only when a token is present
    if let token, !token.isEmpty {
        options.fetch_opts.callbacks.credentials = tokenCredentialCallback
    }

    var repo: OpaquePointer?
    let status = git_clone(&repo, urlStr, destination.path, &options)
    Unmanaged<CloneContext>.fromOpaque(ctxPtr).release()

    if let repo { git_repository_free(repo) }

    guard status == 0 else {
        let msg = git_error_last().map { String(cString: $0.pointee.message) } ?? "error \(status)"
        throw mapLibgit2Error(status: status, message: msg)
    }
}

// MARK: - Error mapping

private func mapLibgit2Error(status: Int32, message: String) -> GitCloneError {
    let lower = message.lowercased()
    if lower.contains("authentication") || lower.contains("credential") || lower.contains("401") || lower.contains("403") {
        return .authenticationFailed
    }
    if lower.contains("not found") || lower.contains("404") || lower.contains("repository not found") {
        return .repositoryNotFound
    }
    if lower.contains("network") || lower.contains("connection") || lower.contains("resolve host") || lower.contains("timed out") {
        return .networkError(message)
    }
    return .cloneFailed(message: message)
}

// MARK: - Clone Context
// Carries both the auth token and the progress handler through @convention(c) callbacks.

private final class CloneContext {
    let token: String?
    let onProgress: (@Sendable (Double) -> Void)?
    init(token: String?, onProgress: (@Sendable (Double) -> Void)?) {
        self.token      = token
        self.onProgress = onProgress
    }
}

// MARK: - Credential Callback
// @convention(c) — cannot capture Swift variables.
// Token is recovered from the payload pointer set in libgit2Clone above.

private let tokenCredentialCallback: git_credential_acquire_cb = { out, _, _, allowedTypes, payload in
    guard allowedTypes & UInt32(GIT_CREDENTIAL_USERPASS_PLAINTEXT.rawValue) != 0,
          let payload else { return -1 }
    let ctx = Unmanaged<CloneContext>.fromOpaque(payload).takeUnretainedValue()
    guard let token = ctx.token, !token.isEmpty else { return -1 }
    return git_credential_userpass_plaintext_new(out, "x-access-token", token)
}

// MARK: - Transfer Progress Callback  (fetch phase → 0 %…80 %)

private let transferProgressCallback: git_indexer_progress_cb = { stats, payload in
    guard let payload, let stats else { return 0 }
    let ctx   = Unmanaged<CloneContext>.fromOpaque(payload).takeUnretainedValue()
    let total = Int(stats.pointee.total_objects)
    let recv  = Int(stats.pointee.received_objects)
    if total > 0 {
        ctx.onProgress?(Double(recv) / Double(total) * 0.8)
    }
    return 0
}

// MARK: - Checkout Progress Callback  (checkout phase → 80 %…100 %)

private let checkoutProgressCallback: git_checkout_progress_cb = { _, completed, total, payload in
    guard let payload, total > 0 else { return }
    let ctx = Unmanaged<CloneContext>.fromOpaque(payload).takeUnretainedValue()
    ctx.onProgress?(0.8 + Double(completed) / Double(total) * 0.2)
}
