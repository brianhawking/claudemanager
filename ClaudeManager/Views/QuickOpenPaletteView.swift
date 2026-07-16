import AppKit
import SwiftUI

enum QuickOpenResultType: String {
    case repository
    case workstream
    case session

    var displayName: String {
        rawValue.capitalized
    }
}

struct QuickOpenResult: Identifiable, Hashable {
    let selection: SidebarSelection
    let title: String
    let subtitle: String
    let type: QuickOpenResultType

    var id: String {
        switch selection {
        case .repository(let id):
            return "repository-\(id.uuidString)"
        case .workstream(let id):
            return "workstream-\(id.uuidString)"
        case .session(let id):
            return "session-\(id.uuidString)"
        }
    }
}

struct QuickOpenPaletteView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var runtimeStore: SessionRuntimeStore
    let onSelectResult: (QuickOpenResult) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var highlightedIndex = 0
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Quick Open", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .onSubmit {
                        activateHighlightedResult()
                    }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            Button {
                                highlightedIndex = index
                                activateHighlightedResult()
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Image(systemName: symbolName(for: result.type))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .foregroundStyle(.primary)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index == highlightedIndex ? Color.accentColor.opacity(0.16) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .padding(16)
            .frame(width: 560)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 22)
        }
        .onAppear {
            isSearchFocused = true
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onChange(of: query) { _, _ in
            highlightedIndex = 0
        }
    }

    private var results: [QuickOpenResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let repositories = viewModel.repositories.map { repository in
            QuickOpenResult(
                selection: .repository(repository.id),
                title: repository.name,
                subtitle: "Repository",
                type: .repository
            )
        }

        let workstreams = viewModel.repositories.flatMap { repository in
            viewModel.workstreams(in: repository).map { workstream in
                QuickOpenResult(
                    selection: .workstream(workstream.id),
                    title: workstream.name,
                    subtitle: "Workstream · \(repository.name)",
                    type: .workstream
                )
            }
        }

        let sessions = viewModel.repositories.flatMap { repository in
            viewModel.workstreams(in: repository).flatMap { workstream in
                viewModel.sessions(in: workstream).map { session in
                    QuickOpenResult(
                        selection: .session(session.id),
                        title: session.name,
                        subtitle: "Session · \(workstream.name) · \(repository.name)",
                        type: .session
                    )
                }
            }
        }

        let allResults = sessions + workstreams + repositories

        guard !normalizedQuery.isEmpty else {
            return allResults
        }

        return allResults
            .compactMap { result -> (Int, QuickOpenResult)? in
                let haystack = "\(result.title) \(result.subtitle)".lowercased()
                guard haystack.contains(normalizedQuery) else { return nil }

                let score: Int
                if result.title.lowercased().hasPrefix(normalizedQuery) {
                    score = 0
                } else if result.subtitle.lowercased().hasPrefix(normalizedQuery) {
                    score = 1
                } else {
                    score = 2
                }

                return (score, result)
            }
            .sorted { (lhs: (Int, QuickOpenResult), rhs: (Int, QuickOpenResult)) in
                if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
                return lhs.1.title.localizedCaseInsensitiveCompare(rhs.1.title) == .orderedAscending
            }
            .map { $0.1 }
    }

    private func activateHighlightedResult() {
        guard results.indices.contains(highlightedIndex) else { return }
        onSelectResult(results[highlightedIndex])
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53:
                onDismiss()
                return nil
            case 125:
                highlightedIndex = min(highlightedIndex + 1, max(results.count - 1, 0))
                return nil
            case 126:
                highlightedIndex = max(highlightedIndex - 1, 0)
                return nil
            case 36, 76:
                activateHighlightedResult()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func symbolName(for type: QuickOpenResultType) -> String {
        switch type {
        case .repository:
            return "folder"
        case .workstream:
            return "target"
        case .session:
            return "terminal"
        }
    }
}
