import SwiftUI

struct ProfileEditorView: View {
    @Binding var draft: Profile
    let knownHosts: [String]
    let onSave: () -> Void
    let onCancel: () -> Void
    let isNew: Bool

    @State private var testMessage: String?
    @State private var testing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Add server" : "Edit server")
                .font(.title3.bold())

            Form {
                TextField("Name", text: $draft.name, prompt: Text("Codex"))
                hostField
                Stepper(value: $draft.pollIntervalSec, in: 1...60) {
                    HStack {
                        Text("Poll interval")
                        Spacer()
                        Text("\(draft.pollIntervalSec) s")
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                }
                Picker("Menu bar shows", selection: $draft.menuBarMetric) {
                    ForEach(MenuBarMetric.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)

            HStack {
                Button {
                    Task { await runTest() }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Test connection")
                    }
                }
                .disabled(draft.sshHost.trimmingCharacters(in: .whitespaces).isEmpty || testing)

                if let msg = testMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                Button(isNew ? "Add" : "Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.sshHost.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var hostField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("SSH host", text: $draft.sshHost, prompt: Text("gpu-box-1"))
                .textFieldStyle(.roundedBorder)
            if !knownHosts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(matchingHosts, id: \.self) { host in
                            Button(host) { draft.sshHost = host }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }
                }
                .frame(height: 22)
            }
        }
    }

    private var matchingHosts: [String] {
        let q = draft.sshHost.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return Array(knownHosts.prefix(8)) }
        return knownHosts.filter { $0.lowercased().contains(q) }.prefix(8).map { $0 }
    }

    private func runTest() async {
        testing = true
        defer { testing = false }
        testMessage = "Testing…"
        let host = draft.sshHost.trimmingCharacters(in: .whitespaces)
        let outcome = await SSHRunner.run(host: host, command: "echo ok && uname -s")
        switch outcome {
        case .success(let r) where r.exitCode == 0:
            let stdout = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            testMessage = "✓ \(stdout.replacingOccurrences(of: "\n", with: " "))"
        case .success(let r):
            testMessage = "✗ exit \(r.exitCode): \(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .failure(let err):
            testMessage = "✗ \(err.localizedDescription)"
        }
    }
}
