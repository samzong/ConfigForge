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
    @State private var editedDirectives: [(key: String, value: String)]
    @State private var hostValid: Bool = true
    @State private var isShowingFilePicker = false
    @State private var currentEditingKey = ""
    
    init(viewModel: MainViewModel, entry: SSHConfigEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedHost = State(initialValue: entry.host)

        let newHostString = L10n.Host.new
        // Initialize editedDirectives
        if entry.host == newHostString && entry.directives.isEmpty { // Assuming new entries might come with empty directives
            _editedDirectives = State(initialValue: [
                (key: "HostName", value: ""),
                (key: "User", value: ""),
                (key: "Port", value: "22")
            ])
        } else {
            // Ensure essential keys are present for existing entries if needed, or rely on SSHConfigEntry defaults
            // For now, directly use entry.directives. The binding helper will handle missing keys.
            _editedDirectives = State(initialValue: entry.directives)
        }
    }
    
    // Helper function to create a binding to a specific directive's value.
    private func bindingForDirective(key canonicalKey: String, defaultValue: String = "") -> Binding<String> {
        Binding<String>(
            get: {
                self.editedDirectives.first { $0.key.lowercased() == canonicalKey.lowercased() }?.value ?? defaultValue
            },
            set: { newValue in
                if let index = self.editedDirectives.firstIndex(where: { $0.key.lowercased() == canonicalKey.lowercased() }) {
                    // Check if the new value is empty and the key is not essential like Port
                    // For Port, if empty, it should revert to "22" or be handled by validation.
                    // For HostName/User, empty is acceptable.
                    // This logic might need refinement based on desired behavior for empty values.
                    // For now, simple update/append.
                    self.editedDirectives[index].value = newValue
                } else {
                    // Only add if the new value is not the default for non-essential keys,
                    // or if it's an essential key like Port.
                    // This prevents adding empty HostName/User directives if they weren't there.
                    // However, for simplicity now, always add. Specific behavior for empty can be refined.
                    if !newValue.isEmpty || defaultValue != "" { // Avoid adding (HostName, "") if not present
                         self.editedDirectives.append((key: canonicalKey, value: newValue))
                    } else if canonicalKey.lowercased() == "port" && newValue.isEmpty { // Port specific
                        self.editedDirectives.append((key: canonicalKey, value: "22"))
                    } else if newValue.isEmpty && defaultValue.isEmpty { // e.g. Hostname or User becomes empty
                        // if it existed, it would have been updated by the first branch.
                        // if it didn't exist, don't add an empty one.
                    } else {
                         self.editedDirectives.append((key: canonicalKey, value: newValue))
                    }

                }
            }
        )
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
                        value: bindingForDirective(key: "HostName", defaultValue: ""),
                        placeholder: L10n.Property.Hostname.placeholder
                    )
                    configPropertyView(
                        label: L10n.Property.user,
                        systemImage: "person.fill",
                        value: bindingForDirective(key: "User", defaultValue: ""),
                        placeholder: L10n.Property.User.placeholder
                    )
                    configPropertyView(
                        label: L10n.Property.port,
                        systemImage: "number.circle",
                        value: bindingForDirective(key: "Port", defaultValue: "22"),
                        placeholder: L10n.Property.Port.placeholder
                    )
                    identityFileListView 
                    
                    advancedDirectivesSection // New section for other directives
                }
                .padding()
                .animation(.easeInOut(duration: 0.2), value: viewModel.isEditing)
            }
        }
        .background(Color(.windowBackgroundColor))
        .id(entry.id)
    }

    // Binding for a specific directive at an index
    private func bindingForDirective(at index: Int) -> Binding<String> {
        Binding<String>(
            get: { self.editedDirectives[index].value },
            set: { newValue in self.editedDirectives[index].value = newValue }
        )
    }
    
    // Binding for a specific directive's key at an index (for Advanced section)
    private func bindingForKey(at index: Int) -> Binding<String> {
        Binding<String>(
            get: { self.editedDirectives[index].key },
            set: { newValue in self.editedDirectives[index].key = newValue }
        )
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
    
    private var identityFileListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.Property.identityfile, systemImage: "key.fill")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(editedDirectives.indices.filter { editedDirectives[$0].key.lowercased() == "identityfile" }, id: \.self) { index in
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
                            TextField(L10n.Property.Identityfile.placeholder, text: bindingForDirective(at: index))
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            let value = editedDirectives[index].value
                            Text(value.isEmpty ? L10n.Property.Identityfile.placeholder : value)
                                .foregroundColor(value.isEmpty ? .gray.opacity(0.5) : .primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                    }
                    .frame(height: 30)
                    
                    Button(action: {
                        if viewModel.isEditing {
                            selectIdentityFile(forIndex: index)
                        }
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!viewModel.isEditing)
                    .opacity(viewModel.isEditing ? 1.0 : 0.5)
                    
                    Button(action: {
                        if viewModel.isEditing {
                            removeDirective(at: index)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!viewModel.isEditing)
                    .opacity(viewModel.isEditing ? 1.0 : 0.5)
                }
            }
            
            if viewModel.isEditing {
                Button(action: addIdentityFile) {
                    Label("Add Identity File", systemImage: "plus.circle.fill")
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func addIdentityFile() {
        editedDirectives.append((key: "IdentityFile", value: ""))
    }

    private func removeDirective(at index: Int) {
        editedDirectives.remove(at: index)
    }
    
    // Overload for removing based on offset, useful for ForEach with non-Identifiable data
    private func removeDirective(atOffsets offsets: IndexSet) {
        editedDirectives.remove(atOffsets: offsets)
    }


    private func selectIdentityFile(forIndex index: Int) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select SSH key file"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.text, .data] // Allow common key file types
        
        openPanel.begin { (result) in
            if result == .OK, let url = openPanel.url {
                DispatchQueue.main.async {
                    // Ensure index is still valid before updating, though less likely an issue here
                    if self.editedDirectives.indices.contains(index) {
                        self.editedDirectives[index].value = url.path
                        print("Selected file path for directive at index \(index): \(url.path)")
                    }
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
                         viewModel.addSshEntry(host: editedHost, directives: editedDirectives) 
                    } else {
                        viewModel.updateSshEntry(id: entry.id, host: editedHost, directives: editedDirectives) 
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
    
    // Removed otherPropertyKeys computed property

    private var advancedDirectivesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Advanced Directives")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "https://github.com/samzong/ConfigForge/blob/main/README.md#ssh-config-host-key") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("Available Keys")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("View available SSH configuration keys")
            }
            .padding(.bottom, 4)

            // Get indices of directives not handled by common fields
            let advancedDirectiveIndices = editedDirectives.indices.filter { index in
                guard editedDirectives.indices.contains(index) else { return false } // Ensure index is valid
                let key = editedDirectives[index].key.lowercased()
                return key != "hostname" && key != "user" && key != "port" && key != "identityfile"
            }

            ForEach(advancedDirectiveIndices, id: \.self) { index in
                HStack {
                    TextField("Key", text: bindingForKey(at: index))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!viewModel.isEditing)
                    
                    TextField("Value", text: bindingForDirective(at: index))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!viewModel.isEditing)
                    
                    Button(action: {
                        if viewModel.isEditing {
                            // Ensure the index is still valid before removing
                            if editedDirectives.indices.contains(index) {
                                removeDirective(at: index)
                            }
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!viewModel.isEditing)
                    .opacity(viewModel.isEditing ? 1.0 : 0.5)
                }
            }
            
            if viewModel.isEditing {
                Button(action: addAdvancedDirective) {
                    Label("Add Directive", systemImage: "plus.circle.fill")
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func addAdvancedDirective() {
        editedDirectives.append((key: "", value: ""))
    }
}