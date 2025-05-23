//
//  ModernEntryEditorView.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI
import AppKit

struct ModernEntryEditorView: View {
    @ObservedObject var viewModel: MainViewModel
    var entry: SSHConfigEntry
    @State private var editedHost: String
    @State private var editedProperties: [String: String]
    @State private var hostValid: Bool = true
    @State private var isShowingFilePicker = false
    @State private var currentEditingKey = ""
    
    init(viewModel: MainViewModel, entry: SSHConfigEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedHost = State(initialValue: entry.host)

        let newHostString = L10n.Host.new
        if entry.properties.isEmpty && entry.host == newHostString {
            let defaultProperties: [String: String] = [
                "HostName": "",
                "User": "",
                "Port": "22"
            ]
            _editedProperties = State(initialValue: defaultProperties)
        } else {
            var updatedProperties = entry.properties
            if !updatedProperties.keys.contains("HostName") {
                updatedProperties["HostName"] = ""
            }
            _editedProperties = State(initialValue: updatedProperties)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    configPropertyView(
                        label: L10n.Property.hostname,
                        systemImage: "network",
                        value: Binding(
                            get: { editedProperties["HostName"] ?? "" },
                            set: { editedProperties["HostName"] = $0 }
                        ),
                        placeholder: L10n.Property.Hostname.placeholder
                    )
                    configPropertyView(
                        label: L10n.Property.user,
                        systemImage: "person.fill",
                        value: Binding(
                            get: { editedProperties["User"] ?? "" },
                            set: { editedProperties["User"] = $0 }
                        ),
                        placeholder: L10n.Property.User.placeholder
                    )
                    configPropertyView(
                        label: L10n.Property.port,
                        systemImage: "number.circle",
                        value: Binding(
                            get: { editedProperties["Port"] ?? "22" },
                            set: { editedProperties["Port"] = $0 }
                        ),
                        placeholder: L10n.Property.Port.placeholder
                    )
                    identityFileView
                    ForEach(otherPropertyKeys, id: \.self) { key in
                        configPropertyView(
                            label: key,
                            systemImage: "doc.text",
                            value: Binding(
                                get: { editedProperties[key] ?? "" },
                                set: { editedProperties[key] = $0 }
                            )
                        )
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.2), value: viewModel.isEditing)
            }
        }
        .background(Color(.windowBackgroundColor))
        .id(entry.id)
    }
    private func configPropertyView(label: String, systemImage: String, value: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: systemImage)
                .font(.headline)
                .foregroundColor(.primary)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.textBackgroundColor))
                    .frame(height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                if viewModel.isEditing {
                    TextField(placeholder, text: value)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                } else {
                    Text(value.wrappedValue.isEmpty ? placeholder : value.wrappedValue)
                        .foregroundColor(value.wrappedValue.isEmpty ? .gray.opacity(0.5) : .primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
            }
            .frame(height: 30)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    private var identityFileView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.Property.identityfile, systemImage: "key.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(NSColor.textBackgroundColor))
                        .frame(height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    if viewModel.isEditing {
                        TextField(L10n.Property.Identityfile.placeholder, text: Binding(
                            get: { editedProperties["IdentityFile"] ?? "" },
                            set: { editedProperties["IdentityFile"] = $0 }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    } else {
                        let value = editedProperties["IdentityFile"] ?? ""
                        Text(value.isEmpty ? L10n.Property.Identityfile.placeholder : value)
                            .foregroundColor(value.isEmpty ? .gray.opacity(0.5) : .primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                }
                .frame(height: 30)
                Button(action: {
                    if viewModel.isEditing {
                        selectIdentityFile()
                    }
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(!viewModel.isEditing)
                .opacity(viewModel.isEditing ? 1.0 : 0.5)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func selectIdentityFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select SSH key file"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true  
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.text, .data]  
        
        openPanel.begin { (result) in
            if result == .OK, let url = openPanel.url {
                DispatchQueue.main.async {
                    self.editedProperties["IdentityFile"] = url.path
                    print("Selected file path: \(url.path)")
                }
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    let newHostString = L10n.Host.new
                    if viewModel.isEditing {
                        TextField(L10n.Host.Enter.name, text: $editedHost)
                            .font(.title2.bold())
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(maxWidth: 300, minHeight: 40)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(entry.host == newHostString ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(entry.host == newHostString ? Color.accentColor : Color.clear, lineWidth: 1)
                                    )
                            )
                            .onChange(of: editedHost) { newValue in
                                Task {
                                    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.*?"))
                                    let isValid = newValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil && !newValue.isEmpty
                                    
                                    await MainActor.run {
                                        hostValid = isValid
                                    }
                                }
                            }
                    } else {
                        Text(entry.host)
                            .font(.title2.bold())
                            .frame(maxWidth: 300, minHeight: 40, alignment: .leading)
                            .padding(4)
                    }
                }
                .frame(height: 40)
                
                HStack {
                    if !entry.hostname.isEmpty {
                        Text(entry.hostname)
                            .foregroundColor(.secondary)
                    }
                    
                    if !entry.user.isEmpty {
                        Text("@\(entry.user)")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
            }

            if !viewModel.isEditing {
                HStack {
                    TerminalLauncherButton(sshEntry: entry)
                        .frame(height: 32)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)
            }
            
            Spacer()

            Button(action: {
                if viewModel.isEditing {
                    if !hostValid || editedHost.isEmpty {
                        viewModel.getMessageHandler().show(AppConstants.ErrorMessages.emptyHostError, type: .error)
                        return
                    }
                    let newHostString = L10n.Host.new
                    if entry.host == newHostString { 
                        if let sshEntry = entry as? SSHConfigEntry, 
                           let index = viewModel.sshEntries.firstIndex(where: { $0.id == sshEntry.id }) {
                            viewModel.sshEntries.remove(at: index) 
                        }
                         viewModel.addSshEntry(host: editedHost, properties: editedProperties) 
                    } else {
                        viewModel.updateSshEntry(id: entry.id, host: editedHost, properties: editedProperties) 
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isEditing.toggle()
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isEditing.toggle()
                    }
                }
            }) {
                Text(viewModel.isEditing ? L10n.App.save : L10n.App.edit)
                    .frame(minWidth: 80)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .disabled(viewModel.isEditing && (!hostValid || editedHost.isEmpty))
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: viewModel.isEditing)
    }
    
    private var otherPropertyKeys: [String] {
        let basicKeys = ["HostName", "User", "Port", "IdentityFile", "PreferredAuthentications"]
        return editedProperties.keys
            .filter { !basicKeys.contains($0) }
            .sorted()
    }
} 