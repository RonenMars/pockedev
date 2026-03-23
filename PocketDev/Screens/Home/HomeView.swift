import SwiftUI

// MARK: - HomeView (UI_SPEC: Home Screen)
// States: empty, populated
// Actions: New Project, Open File, Open Folder
// DESIGN.md §3.2: each entry point feels equal priority, immediately actionable

struct HomeView: View {
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var sessionStore: DocumentSessionStore

    @State private var showNewProject = false
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    @State private var showCloneRepo = false
    @State private var navigateToEditor = false
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Tokens.Color.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if projectService.projects.isEmpty {
                        emptyContent
                    } else {
                        populatedContent
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Project.self) { project in
                ExplorerView(project: project)
            }
            .navigationDestination(isPresented: $navigateToEditor) {
                EditorContainerView()
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectView { project in
                navPath.append(project)
            }
            .environmentObject(projectService)
            .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView(mode: .file) { url in
                sessionStore.openFile(at: url)
                navigateToEditor = true
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            DocumentPickerView(mode: .folder) { url in
                let project = Project(name: url.lastPathComponent, rootURL: url)
                navPath.append(project)
            }
        }
        .sheet(isPresented: $showCloneRepo) {
            CloneRepoView(projectService: projectService) { project in
                navPath.append(project)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PocketDev")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Tokens.Color.textPrimary)
                Text("Local-first code editor")
                    .font(.system(size: 12))
                    .foregroundColor(Tokens.Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.top, Tokens.Spacing.xxl)
        .padding(.bottom, Tokens.Spacing.lg)
    }

    // MARK: - Action tiles (always visible)

    private var actionRow: some View {
        HStack(spacing: Tokens.Spacing.md) {
            ActionTile(icon: "folder.badge.plus", label: "New Project") {
                showNewProject = true
            }
            ActionTile(icon: "doc.text", label: "Open File") {
                showFilePicker = true
            }
            ActionTile(icon: "folder", label: "Open Folder") {
                showFolderPicker = true
            }
            ActionTile(icon: "arrow.down.circle", label: "Clone Repo") {
                showCloneRepo = true
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg)
    }

    // MARK: - Empty state

    private var emptyContent: some View {
        VStack(spacing: Tokens.Spacing.xxl) {
            actionRow
            Spacer()
            PDEmptyState(
                icon: "curlybraces",
                title: "No projects yet",
                message: "Create a new project to get started.",
                actionTitle: "New Project"
            ) {
                showNewProject = true
            }
            Spacer()
        }
        .padding(.top, Tokens.Spacing.xl)
    }

    // MARK: - Populated state

    private var populatedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                actionRow

                sectionLabel("Recent")

                LazyVStack(spacing: Tokens.Spacing.sm) {
                    ForEach(projectService.projects) { project in
                        NavigationLink(value: project) {
                            ProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Tokens.Spacing.lg)
                    }
                }
            }
            .padding(.top, Tokens.Spacing.xl)
            .padding(.bottom, Tokens.Spacing.xxl)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Tokens.Color.textSecondary)
            .tracking(0.8)
            .textCase(.uppercase)
            .padding(.horizontal, Tokens.Spacing.lg)
    }
}

// MARK: - ActionTile

private struct ActionTile: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Tokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Tokens.Color.accent)
                    .frame(height: 28)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Tokens.Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Tokens.Color.surface)
            .cornerRadius(Tokens.Radius.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ProjectCard (COMPONENT_MAP: ProjectCard)

private struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            Image(systemName: "folder.fill")
                .font(.system(size: 18))
                .foregroundColor(Tokens.Color.accent)
                .frame(width: 36, height: 36)
                .background(Tokens.Color.accent.opacity(0.12))
                .cornerRadius(Tokens.Radius.small)

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Tokens.Color.textPrimary)
                Text(project.rootPath)
                    .font(.system(size: 11))
                    .foregroundColor(Tokens.Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Tokens.Color.textSecondary.opacity(0.5))
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .cornerRadius(Tokens.Radius.medium)
    }
}
