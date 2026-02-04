import SwiftUI

/// Main SwiftUI view for the menubar popover
struct PopoverView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .font(.title2)
                Text("TranslateBar")
                    .font(.headline)
                Spacer()
                Text("Cmd+Shift+T")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // API Key Section
            apiKeySection

            Divider()

            // Language Section
            languageSection

            Divider()

            // Auto-paste Section
            autoPasteSection

            Divider()

            // Translate Button
            translateButton

            // Status Message
            statusSection

            Spacer()

            // Footer
            footerSection
        }
        .padding()
        .frame(width: 320, height: 380)
        .onAppear {
            viewModel.refreshAccessibilityStatus()
            // Start polling if auto-paste is enabled but no permission yet
            if viewModel.autoPasteEnabled && !viewModel.hasAccessibilityPermission {
                viewModel.startPermissionPolling()
            }
        }
        .onDisappear {
            viewModel.stopPermissionPolling()
        }
        .onChange(of: viewModel.autoPasteEnabled) { newValue in
            if newValue && !viewModel.hasAccessibilityPermission {
                viewModel.startPermissionPolling()
            } else if !newValue {
                viewModel.stopPermissionPolling()
            }
        }
    }

    // MARK: - Sections

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenAI API Key")
                .font(.subheadline)
                .fontWeight(.medium)

            if viewModel.hasAPIKey {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API key configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Remove") {
                        viewModel.deleteAPIKey()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.caption)
                }
            } else {
                SecureField("sk-...", text: $viewModel.apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                Button("Save API Key") {
                    viewModel.saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.apiKeyInput.isEmpty)
            }
        }
    }

    private var languageSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Translate to")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $viewModel.targetLanguage) {
                    ForEach(TargetLanguage.allCases, id: \.self) { language in
                        Text("\(language.flag) \(language.displayName)").tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            HStack {
                Text("Tone")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $viewModel.translationTone) {
                    ForEach(TranslationTone.allCases, id: \.self) { tone in
                        Text("\(tone.icon) \(tone.displayName)").tag(tone)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
            }
        }
    }

    private var autoPasteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto-paste after translation", isOn: $viewModel.autoPasteEnabled)
                .toggleStyle(.switch)

            if viewModel.autoPasteEnabled {
                accessibilityStatus
            }
        }
    }

    @ViewBuilder
    private var accessibilityStatus: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(viewModel.hasAccessibilityPermission ? .green : .orange)
                .font(.caption)
            Text(viewModel.hasAccessibilityPermission ? "Accessibility granted" : "Accessibility required")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if !viewModel.hasAccessibilityPermission {
                Button("Grant") {
                    viewModel.openAccessibilitySettings()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var translateButton: some View {
        Button(action: {
            viewModel.translateClipboard()
        }) {
            HStack {
                if viewModel.isTranslating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "doc.on.clipboard")
                }
                Text(viewModel.isTranslating ? "Translating..." : "Translate Clipboard Now")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isTranslating || !viewModel.hasAPIKey)
    }

    private var statusSection: some View {
        HStack {
            if !viewModel.statusMessage.isEmpty {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.caption)
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .frame(height: 30)
    }

    private var footerSection: some View {
        HStack {
            Text("v1.0")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private var statusIcon: String {
        if viewModel.statusMessage.contains("success") ||
           viewModel.statusMessage.contains("Translated") ||
           viewModel.statusMessage.contains("saved") {
            return "checkmark.circle.fill"
        } else if viewModel.statusMessage.contains("error") ||
                  viewModel.statusMessage.contains("Failed") ||
                  viewModel.statusMessage.contains("Invalid") ||
                  viewModel.statusMessage.contains("empty") {
            return "exclamationmark.circle.fill"
        } else {
            return "info.circle.fill"
        }
    }

    private var statusColor: Color {
        if viewModel.statusMessage.contains("success") ||
           viewModel.statusMessage.contains("Translated") ||
           viewModel.statusMessage.contains("saved") {
            return .green
        } else if viewModel.statusMessage.contains("error") ||
                  viewModel.statusMessage.contains("Failed") ||
                  viewModel.statusMessage.contains("Invalid") ||
                  viewModel.statusMessage.contains("empty") {
            return .red
        } else {
            return .blue
        }
    }
}

#Preview {
    PopoverView(viewModel: AppViewModel())
}
