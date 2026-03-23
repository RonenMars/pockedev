import Foundation
import libgit2

// MARK: - GitCloning Protocol

protocol GitCloning {
    func cloneRepository(
        from urlString: String,
        token: String?,
        to destinationURL: URL
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
        to destinationURL: URL
    ) async throws {
        var urlStr = urlString.trimmingCharacters(in: .whitespaces)
        if !urlStr.hasSuffix(".git") { urlStr += ".git" }
        guard URL(string: urlStr) != nil else { throw GitCloneError.invalidURL }

        let dest = destinationURL, tok = token
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Task.detached(priority: .userInitiated) {
                do {
                    try libgit2Clone(urlStr: urlStr, destination: dest, token: tok)
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

private func libgit2Clone(urlStr: String, destination: URL, token: String?) throws {
    var options = git_clone_options()
    git_clone_init_options(&options, UInt32(GIT_CLONE_OPTIONS_VERSION))
    options.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

    var repo: OpaquePointer?
    let status: Int32

    if let token, !token.isEmpty {
        let ctx = TokenContext(token)
        let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
        options.fetch_opts.callbacks.credentials = tokenCredentialCallback
        options.fetch_opts.callbacks.payload = ctxPtr
        status = git_clone(&repo, urlStr, destination.path, &options)
        Unmanaged<TokenContext>.fromOpaque(ctxPtr).release()
    } else {
        status = git_clone(&repo, urlStr, destination.path, &options)
    }

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

// MARK: - Token Context

private final class TokenContext {
    let token: String
    init(_ token: String) { self.token = token }
}

// MARK: - Credential Callback
// @convention(c) — cannot capture Swift variables.
// Token is recovered from the payload pointer set in libgit2Clone above.

private let tokenCredentialCallback: git_credential_acquire_cb = { out, _, _, allowedTypes, payload in
    guard allowedTypes & UInt32(GIT_CREDENTIAL_USERPASS_PLAINTEXT.rawValue) != 0,
          let payload else { return -1 }
    let token = Unmanaged<TokenContext>.fromOpaque(payload).takeUnretainedValue().token
    return git_credential_userpass_plaintext_new(out, "x-access-token", token)
}
