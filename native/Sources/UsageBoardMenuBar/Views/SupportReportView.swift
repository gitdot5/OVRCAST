import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SupportReportView: View {
    let text: String
    var scheme: ColorScheme? = nil
    let copy: () -> Void
    @State private var saved = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review before sharing").font(.title2.weight(.semibold))
            Text("This report excludes account identities, computer names, paths, balances, credentials and raw error messages. Nothing is sent automatically.").font(.callout).foregroundStyle(.secondary)
            ScrollView { Text(text).font(.system(.caption, design: .monospaced)).foregroundStyle(.primary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                .padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("Copy report", action: copy)
                Button("Save report…", action: save)
                Spacer()
                Text(saved).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(22).frame(minWidth: 520, minHeight: 400).background(.background).preferredColorScheme(scheme)
    }
    private func save() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "OVRCAST-support.json"; panel.allowedContentTypes = [.json]
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do { try PrivateFiles.writeData(Data(text.utf8), to: url); saved = "Saved locally" }
            catch { saved = "Could not save report" }
        }
    }
}
