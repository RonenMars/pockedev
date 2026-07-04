import SwiftUI

// MARK: - EditorContainerView (UI_SPEC: Editor)
// States: loading, error, editing
// Features: TabsBar, CodeEditorView, Save, Search overlay
// DESIGN.md §2.2: Editor ≥ 80% of screen.

struct EditorContainerView: View {
    @EnvironmentObject private var sessionStore: DocumentSessionStore
    @Environment(\.dismiss) private var dismiss

    // Save state
    @State private var showSaveSuccess = false
    @State private var isSaving = false

    // Search state (not persisted — per scope constraints)
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var searchMatches: [NSRange] = []
    @State private var currentMatchIndex = 0
    @State private var replaceText = ""
    @State private var isRegex = false
    @State private var isCaseSensitive = false
    @State private var showReplace = false
    @State private var isInvalidRegex = false

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if sessionStore.sessions.isEmpty {
                    noFileOpen
                } else {
                    TabsBar(
                        sessions: sessionStore.sessions,
                        activeID: sessionStore.activeSessionID,
                        onActivate: { sessionStore.activate(id: $0) },
                        onClose:   { closeTab($0) }
                    )

                    editorBody
                }
            }

            // Save success toast
            if showSaveSuccess {
                VStack {
                    Spacer()
                    saveToast
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        // Recompute matches when the active tab changes
        .onChange(of: sessionStore.activeSessionID) { _ in
            recomputeMatches()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        PDTopBar(
            title: sessionStore.activeSession?.fileName ?? "Editor",
            subtitle: sessionStore.activeSession.map { $0.isDirty ? "Unsaved changes" : "Saved" },
            leadingIcon: "chevron.left",
            leadingAction: { dismiss() }
        ) {
            HStack(spacing: Tokens.Spacing.sm) {
                // Syntax language picker
                if let session = sessionStore.activeSession {
                    Menu {
                        Picker("Syntax", selection: languageBinding(for: session)) {
                            Text("Auto — \(SyntaxHighlighter.language(for: session.fileURL.pathExtension).displayName)")
                                .tag(nil as SyntaxHighlighter.Language?)
                            ForEach(SyntaxHighlighter.Language.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang as SyntaxHighlighter.Language?)
                            }
                        }
                    } label: {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(session.languageOverride == nil ? Tokens.Color.textSecondary : Tokens.Color.accent)
                            .frame(width: 36, height: 44)
                    }
                }

                // Search toggle
                Button {
                    toggleSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(showSearch ? Tokens.Color.accent : Tokens.Color.textSecondary)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(sessionStore.activeSession == nil)

                // Save
                if let session = sessionStore.activeSession {
                    PDButton(
                        title: "Save",
                        variant: session.isDirty ? .primary : .secondary,
                        action: { save(sessionID: session.id) },
                        icon: "arrow.down.doc",
                        isLoading: isSaving
                    )
                    .opacity(session.isDirty || isSaving ? 1 : 0.4)
                    .disabled(!session.isDirty || session.isLoading || isSaving)
                    .animation(.easeInOut(duration: Tokens.Motion.micro), value: session.isDirty)
                }
            }
            .padding(.trailing, Tokens.Spacing.sm)
        }
    }

    // MARK: - Editor body

    @ViewBuilder
    private var editorBody: some View {
        if let session = sessionStore.activeSession {
            if session.isLoading {
                loadingView
            } else if let error = session.error {
                errorView(message: error, sessionID: session.id)
            } else {
                ZStack(alignment: .top) {
                    CodeEditorView(
                        text: Binding(
                            get: { session.content },
                            set: { sessionStore.updateContent($0, sessionID: session.id) }
                        ),
                        language: session.language,
                        searchMatches: searchMatches,
                        activeMatchIndex: currentMatchIndex,
                        onTextChange: { sessionStore.updateContent($0, sessionID: session.id) }
                    )

                    // Search overlay — slides in from top (DESIGN.md §6.3)
                    if showSearch {
                        SearchOverlay(
                            query: $searchQuery,
                            replaceText: $replaceText,
                            isRegex: $isRegex,
                            isCaseSensitive: $isCaseSensitive,
                            showReplace: $showReplace,
                            matchCount: searchMatches.count,
                            currentIndex: currentMatchIndex,
                            isInvalidRegex: isInvalidRegex,
                            onNext:       { navigateMatch(direction: .next) },
                            onPrevious:   { navigateMatch(direction: .previous) },
                            onReplace:    { performReplace() },
                            onReplaceAll: { performReplaceAll() },
                            onDismiss:    { dismissSearch() }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: Tokens.Motion.normal), value: showSearch)
                // Recompute as query changes
                .onChange(of: searchQuery) { _ in
                    recomputeMatches()
                }
                // Recompute when file content changes while search is open
                .onChange(of: sessionStore.activeSession?.content) { _ in
                    guard showSearch else { return }
                    recomputeMatches()
                }
                .onChange(of: isRegex) { _ in recomputeMatches() }
                .onChange(of: isCaseSensitive) { _ in recomputeMatches() }
            }
        }
    }

    // MARK: - Syntax language

    private func languageBinding(for session: DocumentSession) -> Binding<SyntaxHighlighter.Language?> {
        Binding(
            get: { session.languageOverride },
            set: { sessionStore.setLanguage($0, sessionID: session.id) }
        )
    }

    // MARK: - Sub-states

    private var noFileOpen: some View {
        PDEmptyState(
            icon: "doc.text",
            title: "No file open",
            message: "Go back to the explorer and tap a file."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Tokens.Color.accent)
            Text("Loading…")
                .font(.system(size: 12))
                .foregroundColor(Tokens.Color.textSecondary)
                .padding(.top, Tokens.Spacing.sm)
            Spacer()
        }
    }

    private func errorView(message: String, sessionID: UUID) -> some View {
        PDEmptyState(
            icon: "exclamationmark.triangle",
            title: "Cannot open file",
            message: message,
            actionTitle: "Close Tab"
        ) {
            sessionStore.close(id: sessionID)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Save

    private var saveToast: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Tokens.Color.success)
            Text("Saved")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Tokens.Color.textPrimary)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.md)
        .background(Tokens.Color.panel)
        .cornerRadius(Tokens.Radius.medium)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private func save(sessionID: UUID) {
        isSaving = true
        Task { @MainActor in
            let result = await sessionStore.save(sessionID: sessionID)
            isSaving = false
            if case .success = result {
                withAnimation(.easeInOut(duration: Tokens.Motion.normal)) { showSaveSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: Tokens.Motion.normal)) { showSaveSuccess = false }
                }
            }
        }
    }

    // MARK: - Tab close

    private func closeTab(_ id: UUID) {
        if sessionStore.sessions.count == 1 {
            // Last tab: clear search state, close session, then pop back to Explorer
            dismissSearch()
            sessionStore.close(id: id)
            dismiss()
            return
        }
        sessionStore.close(id: id)
    }

    // MARK: - Search

    private func toggleSearch() {
        if showSearch {
            dismissSearch()
        } else {
            showSearch = true
        }
    }

    private func dismissSearch() {
        showSearch = false
        searchQuery = ""
        replaceText = ""
        searchMatches = []
        currentMatchIndex = 0
        showReplace = false
        isInvalidRegex = false
    }

    private func recomputeMatches() {
        guard !searchQuery.isEmpty,
              let content = sessionStore.activeSession?.content else {
            searchMatches = []
            currentMatchIndex = 0
            isInvalidRegex = false
            return
        }

        let result = FindReplaceEngine.matches(
            in: content, query: searchQuery,
            isRegex: isRegex, caseSensitive: isCaseSensitive
        )
        isInvalidRegex = result.isInvalidRegex
        searchMatches = result.ranges

        if searchMatches.isEmpty {
            currentMatchIndex = 0
        } else {
            currentMatchIndex = min(currentMatchIndex, searchMatches.count - 1)
        }
    }

    private enum Direction { case next, previous }

    private func navigateMatch(direction: Direction) {
        guard !searchMatches.isEmpty else { return }
        switch direction {
        case .next:
            currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        case .previous:
            currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        }
    }

    private func performReplace() {
        guard let session = sessionStore.activeSession,
              !searchMatches.isEmpty,
              currentMatchIndex < searchMatches.count else { return }
        let range = searchMatches[currentMatchIndex]
        let updated = FindReplaceEngine.replaceOne(
            in: session.content, matchRange: range, query: searchQuery,
            replacement: replaceText, isRegex: isRegex, caseSensitive: isCaseSensitive
        )
        sessionStore.updateContent(updated, sessionID: session.id)
        recomputeMatches()
    }

    private func performReplaceAll() {
        guard let session = sessionStore.activeSession, !searchMatches.isEmpty else { return }
        let updated = FindReplaceEngine.replaceAll(
            in: session.content, query: searchQuery, replacement: replaceText,
            isRegex: isRegex, caseSensitive: isCaseSensitive
        )
        sessionStore.updateContent(updated, sessionID: session.id)
        recomputeMatches()
    }
}
