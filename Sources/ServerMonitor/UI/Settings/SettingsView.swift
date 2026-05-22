import SwiftUI

@MainActor
struct SettingsView: View {
    @Bindable var state: AppState
    @State private var selectedID: UUID?
    @State private var draft: Profile = .init(name: "", sshHost: "")
    @State private var isEditingNew = false

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 200, idealWidth: 220)
            editor
                .frame(minWidth: 320)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(state.profiles) { profile in
                    HStack {
                        Image(systemName: profile.iconSymbol)
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.system(size: 13, weight: .medium))
                            Text(profile.sshHost).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.id as UUID?)
                }
            }
            .onChange(of: selectedID) { _, new in
                if let new, let p = state.profiles.first(where: { $0.id == new }) {
                    draft = p
                    isEditingNew = false
                }
            }

            Divider()
            HStack {
                Button {
                    startAdding()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                Button {
                    if let id = selectedID {
                        state.removeProfile(id: id)
                        selectedID = state.profiles.first?.id
                        if let id = selectedID, let p = state.profiles.first(where: { $0.id == id }) {
                            draft = p
                        } else {
                            draft = Profile(name: "", sshHost: "")
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedID == nil)
                Spacer()
            }
            .padding(6)
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if state.profiles.isEmpty && !isEditingNew {
            VStack(spacing: 12) {
                Image(systemName: "server.rack").font(.system(size: 32)).foregroundStyle(.secondary)
                Text("Add a server to get started").font(.headline)
                Button("Add server", action: startAdding).buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedID != nil || isEditingNew {
            ProfileEditorView(
                draft: $draft,
                knownHosts: SSHConfigReader.listHosts(),
                onSave: save,
                onCancel: cancel,
                isNew: isEditingNew
            )
            .padding(16)
        } else {
            Text("Select a server")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func startAdding() {
        draft = Profile(name: "", sshHost: "")
        selectedID = nil
        isEditingNew = true
    }

    private func save() {
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        let host = draft.sshHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        var toSave = draft
        toSave.name = trimmed.isEmpty ? host : trimmed
        toSave.sshHost = host
        if isEditingNew {
            state.addProfile(toSave)
            selectedID = toSave.id
            isEditingNew = false
        } else {
            state.updateProfile(toSave)
        }
    }

    private func cancel() {
        if isEditingNew {
            isEditingNew = false
            selectedID = state.profiles.first?.id
        }
        if let id = selectedID, let p = state.profiles.first(where: { $0.id == id }) {
            draft = p
        }
    }
}
