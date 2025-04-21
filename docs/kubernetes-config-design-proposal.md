# Kubernetes Configuration Management Proposal

## 1. Introduction

### 1.1 Problem Statement

The current Kubernetes configuration management design segments configurations into clusters, users, and contexts within a single `.kube/config` file. This approach presents several challenges:

- The `.kube/config` file becomes unwieldy with numerous entries
- Maintenance of individual components (clusters, users, contexts) is cumbersome
- Most kubeconfig files are distributed as complete YAML documents, making the current segmented approach counter-intuitive
- No clear way to manage multiple environments or projects

### 1.2 Proposed Solution

We propose a shift to a file-based management approach where:
- Complete kubeconfig files are stored separately in a dedicated directory (`~/.kube/configs/`).
- ConfigForge manages switching between these configurations by overwriting the main `~/.kube/config` file.
- Basic file validation is performed during discovery.
- A simple backup mechanism (`~/.kube/config.bak`) preserves the previous configuration.

This approach aims to simplify management for users dealing with multiple complete kubeconfig files, reducing the need to manually edit the main `~/.kube/config`.

## 2. Design Goals and Principles

### 2.1 Key Goals

- **Simplify Configuration Management**: Eliminate the need to manually edit the `.kube/config` file
- **Improve Organization**: Provide intuitive ways to categorize and find configurations
- **Enhance User Experience**: Make configuration switching seamless and visual
- **Preserve Compatibility**: Maintain backward compatibility with existing tools
- **Enable Advanced Features**: Support metadata, templates, and dependencies

### 2.2 Design Principles

- **File-Based Approach**: Store each configuration as an intact file
- **Atomic Operations**: Ensure configuration switching is reliable and recoverable
- **File System Discovery**: Rely on direct directory scanning for configuration discovery.
- **Overwrite with Backup**: Configuration switching involves overwriting the main config file after creating a backup.
- **Security-First**: Implement appropriate safeguards for sensitive information.
- **Progressive Enhancement**: Build core functionality first, then add advanced features like automatic splitting or advanced metadata.

## 3. Architecture Overview

### 3.1 System Components

```
┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │
│  Configuration  │◄────►│ Configuration   │
│  Repository     │      │ Switcher        │
│ (`~/.kube/configs/`)│      │ (incl. Backup)  │
│                 │      │                 │
└────────┬────────┘      └────────┬────────┘
         │                        │
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │
│  File System    │      │  Active Config  │
│  Service        │      │ (`~/.kube/config`)│
│ (Read/Write/List)│      │                 │
│                 │      │                 │
└─────────────────┘      └─────────────────┘
```

### 3.2 Component Descriptions

1.  **Configuration Repository**: Represents the `~/.kube/configs/` directory where individual kubeconfig files are stored. Discovery involves listing files in this directory.
2.  **Configuration Switcher**: Handles the process of activating a selected configuration. This involves:
    *   Reading the current `~/.kube/config`.
    *   Writing its content to `~/.kube/config.bak`.
    *   Reading the selected file from `~/.kube/configs/`.
    *   Writing its content to `~/.kube/config`.
3.  **File System Service**: Handles low-level file operations: reading directory contents, reading file contents, writing file contents, and basic validation (e.g., attempting to parse).
4.  **Active Config**: The `~/.kube/config` file, which is actively managed (overwritten) by ConfigForge during switching.

## 4. File Organization Structure

```
~/.kube/
├── config                 # Active configuration file, managed by ConfigForge
├── config.bak             # Backup of the previous active config file
└── configs/               # Directory containing individual kubeconfig files
    ├── prod-cluster-a.yaml
    ├── dev-cluster-b.yaml
    └── staging-cluster-c.yaml
    # Users can organize files within this directory as they see fit (e.g., using subdirectories),
    # but ConfigForge V1 primarily lists files directly within `configs/`.
```

## 5. Core Model Design (Simplified)

Given the removal of central metadata, the core models are simplified. The primary "model" becomes the file path itself, potentially augmented with validation status.

```swift
// Represents a discovered configuration file
struct DiscoveredKubeConfig {
    let path: URL // Full path to the file in ~/.kube/configs/
    var isValid: Bool? // Optional: Result of validation check
    var lastModified: Date? // Optional: File modification date for sorting
    // Basic name derived from filename
    var displayName: String {
        path.lastPathComponent
    }
}
```

### 5.1 Core Services (Revised)

```swift
// Manages discovery, validation, and switching
protocol KubeConfigManager {
    // Discovers config files in ~/.kube/configs/
    // Optionally performs validation during discovery
    func listAvailableConfigs(validate: Bool) -> Result<[DiscoveredKubeConfig], Error>

    // Switches the active config to the one at the given path
    // Handles backup to config.bak and writing to config
    func switchActiveConfig(to configPath: URL) -> Result<Void, Error>

    // Reads the content of a specific config file
    func readConfigContent(at path: URL) -> Result<String, Error>

    // Validates the content of a specific config file
    func validateConfig(at path: URL) -> Result<Bool, Error>

    // Optional: Import a file into the ~/.kube/configs directory
    func importConfig(from sourcePath: URL) -> Result<URL, Error>

    // Optional: Export a config file from ~/.kube/configs
    func exportConfig(at configPath: URL, to destinationPath: URL) -> Result<Void, Error>
}

// Lower-level file operations
protocol FileSystemService {
    func readFile(path: URL) -> Result<String, Error>
    func writeFile(path: URL, content: String) -> Result<Void, Error>
    // Simplified backup: just write content to a fixed backup path
    func backupActiveConfig(content: String, backupPath: URL) -> Result<Void, Error>
    func listFiles(directory: URL) -> Result<[URL], Error>
    func fileExists(at path: URL) -> Bool
    func getFileAttributes(at path: URL) -> Result<[FileAttributeKey: Any], Error>
}
```

## 6. Feature Improvements

### 6.1 Configuration Management (Revised)

- **Import/Export**: Basic functionality to copy files into/out of the `~/.kube/configs` directory.
- **Validation**: Check if files in `~/.kube/configs` are parsable as valid KubeConfig YAML upon discovery or on demand. Mark invalid files in the UI.
- **Backup**: Simple backup of `~/.kube/config` to `~/.kube/config.bak` before overwriting during a switch. Restoration involves manually copying `.bak` back to `config` or using a potential future "undo" feature.
- **Duplication**: Basic file duplication within `~/.kube/configs`.
- **Templates**: Deferred.

### 6.2 Metadata Management (Simplified)

- **Basic Identification**: Configurations are identified primarily by their filename.
- **Organization**: Users manage organization through filenames or subdirectories within `~/.kube/configs/` (though initial UI might just show a flat list).
- **Search**: Basic search by filename.
- **Advanced Metadata (Tags, Env, Favs, History)**: Deferred for future consideration.

### 6.3 Configuration Switching (Revised)

- **Overwrite Mechanism**: Switching involves overwriting `~/.kube/config` with the content of the selected file from `~/.kube/configs/`.
- **Backup**: The previous `~/.kube/config` content is backed up to `~/.kube/config.bak` before the overwrite.
- **Validation**: Ideally, validate the selected config *before* attempting the switch.
- **Rollback**: Basic rollback is possible by manually restoring `~/.kube/config.bak`. A dedicated "undo" feature could be added later.
- **Notifications**: Provide clear visual feedback during the switching process (start, success, failure).
- **Quick Switching**: UI/Command Palette allows fast selection and activation of configurations listed from `~/.kube/configs/`.

## 7. User Interface Design

### 7.1 Main Interface Layout

```swift
struct MainView: View {
    var body: some View {
        NavigationSplitView {
            // Left Sidebar: Configuration Browser
            ConfigurationBrowser()
        } content: {
            // Middle Content: Configuration List
            ConfigurationList()
        } detail: {
            // Right Detail: Configuration Editor
            ConfigurationEditor()
        }
        .toolbar {
            ToolbarItems()
        }
    }
}
```

### 7.2 Configuration Browser (Left Sidebar - V3.2)

The sidebar lists discovered Kubernetes configurations, including the active one and files from the `configs/` directory.

**Key Features:**
- Displays the active `~/.kube/config` (clearly marked).
- Lists all files from `~/.kube/configs/`.
- Indicates validation status (e.g., marking invalid/unparsable files).
- Provides a "+" button to create a new empty configuration file in `~/.kube/configs/`.
- Includes context menu actions for file management and activation.
- Shows an empty state message if no configurations are found.

```swift
struct ConfigurationBrowser: View {
    // ViewModel providing the combined list (active + configs/)
    @StateObject var viewModel: ConfigBrowserViewModel

    var body: some View {
        VStack {
            // Search Bar (Filters viewModel.combinedConfigs)
            ConfigSearchBar(searchText: $viewModel.searchText)

            // List Area
            if viewModel.combinedConfigs.isEmpty {
                 // Empty State View
                 Text("No Kubernetes configurations found.\nUse '+' to add a new one.")
                     .foregroundColor(.secondary)
                     .multilineTextAlignment(.center)
                     .padding()
                 Spacer()
            } else {
                List(viewModel.filteredConfigs) { configItem in // configItem includes path, active status, valid status
                    ConfigRow(configItem: configItem) // Row shows name, active/invalid indicators
                        .contextMenu { /* Context menu defined in ConfigurationList */ }
                        .onTapGesture { viewModel.selectConfig(configItem) }
                }
                .listStyle(SidebarListStyle())
            }

            // Add Button
            Button(action: viewModel.createNewConfigFile) { // Prompts for name, creates empty file
                Label("New Configuration", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .toolbar {
            // Refresh, Open Directory buttons...
        }
    }
}
```

### 7.3 Configuration List (Middle Content - V3.2)

This view displays the combined list (active config + files from `configs/`) and handles interactions.

```swift
struct ConfigurationList: View {
    // ViewModel providing the combined list and handling actions
    @StateObject var viewModel: ConfigListViewModel
    @Binding var searchText: String // Bind to search text from Sidebar/Toolbar

    // Filter logic resides in ViewModel or here
    var filteredConfigs: [CombinedKubeConfigItem] { // CombinedItem includes path, isActive, isValid
        // ... filtering logic based on searchText (filename) ...
        return viewModel.combinedConfigs.filter { /* ... */ }
    }

    var body: some View {
        List(filteredConfigs) { configItem in
            ConfigurationListItem(configItem: configItem) // Row shows name, active/invalid indicators
                .contextMenu {
                    // Action available only for items from `configs/` directory
                    if !configItem.isActive {
                        Button("Set as Active") { viewModel.setActiveConfig(configItem.path) }
                    }
                    // Actions available only for items from `configs/` directory
                    if !configItem.isActive {
                         Button("Duplicate") { viewModel.duplicateConfig(configItem.path) }
                         Button("Export") { viewModel.exportConfig(configItem.path) }
                         Divider()
                         Button("Delete", role: .destructive) { viewModel.deleteConfig(configItem.path) } // Needs confirmation
                    } else {
                         // Actions for the active ~/.kube/config item (e.g., Export)
                         Button("Export Active Config") { viewModel.exportConfig(configItem.path) }
                    }
                    Button("Reveal in Finder") { viewModel.revealInFinder(configItem.path) }
                }
                .onTapGesture {
                     viewModel.selectConfig(configItem) // Selects for editor view
                }
        }
        .toolbar {
             // Sorting options (name, date modified, active status)
             // ...
        }
    }
}
```

### 7.4 Configuration Editor (Right Detail - V3.2)

Displays the content of the selected configuration file (active `config` or a file from `configs/`). Defaults to read-only mode.

**Key Features:**
- **Read-Only Default:** Shows YAML content in a non-editable viewer by default.
- **Syntax Highlighting:** Both viewer and editor must support YAML syntax highlighting.
- **Explicit Edit Mode:** An "Edit" button switches to an editable text area.
- **Save/Cancel:** In edit mode, "Save" writes changes back to the file, "Cancel" discards them.
- **Handles Damaged Files:** Allows viewing and attempting to edit even files marked as invalid/damaged.

```swift
struct KubeConfigFileEditorView: View { // Renamed for clarity
    // ViewModel holding content, path, edit state, etc.
    @StateObject var viewModel: KubeConfigEditorViewModel
    // Local state for edit mode, potentially synced with ViewModel
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header showing filename, active/invalid status
            ConfigHeaderView(configInfo: viewModel.configInfo) // Pass path, isActive, isValid

            // YAML Viewer or Editor
            if isEditing {
                YAMLEditor(text: $viewModel.editableContent) // Bind to editable buffer
                    .syntaxHighlighting(.yaml)
                    .border(Color.accentColor) // Indicate editing
            } else {
                YAMLViewer(text: viewModel.currentContent) // Display current file content
                    .syntaxHighlighting(.yaml)
            }

            // Action Toolbar
            HStack {
                // Optional: Validate button (checks YAML syntax)
                Button("Validate Syntax") { viewModel.validateSyntax() }

                Spacer()

                if isEditing {
                    Button("Cancel") {
                        viewModel.discardChanges() // Reset editableContent
                        isEditing = false
                    }
                    Button("Save") {
                        // Attempt save, handle success/failure
                        if viewModel.saveChanges() {
                            isEditing = false
                        } else {
                            // Show error to user
                        }
                    }
                    .keyboardShortcut("s", modifiers: .command) // Standard save shortcut
                } else {
                    Button("Edit") {
                        viewModel.prepareForEditing() // Load content into editable buffer
                        isEditing = true
                    }
                }
            }
            .padding()
            .background(.bar) // Toolbar background
        }
        .toolbar { // Main window toolbar items
            ToolbarItemGroup {
                 // Activate button, disabled if already active or if it's the ~/.kube/config item
                Button("Set as Active") { viewModel.setActive() }
                    .disabled(viewModel.configInfo.isActive || viewModel.configInfo.path == AppConstants.kubeConfigPath)

                Button("Export") { viewModel.exportConfig() }

                Menu {
                    // Duplicate/Delete only available for files in configs/
                    if viewModel.configInfo.path != AppConstants.kubeConfigPath {
                        Button("Duplicate") { viewModel.duplicateConfig() }
                        Button("Delete", role: .destructive) { viewModel.deleteConfig() } // Needs confirmation
                    }
                    Button("Reveal in Finder") { viewModel.revealInFinder() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
```

### 7.5 Quick Switcher (Command Palette)

```swift
struct QuickSwitcher: View {
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            // Search Input
            SearchField("Search configurations...", text: $searchText)
            
            // Results List
            List {
                // Recent Configurations
                Section("Recent") {
                    ForEach(recentConfigs) { config in
                        QuickSwitcherItem(config: config)
                    }
                }
                
                // Search Results
                Section("Results") {
                    ForEach(searchResults) { config in
                        QuickSwitcherItem(config: config)
                    }
                }
                
                // Quick Actions
                Section("Actions") {
                    Button("Create New Configuration") { /* ... */ }
                    Button("Import Configuration") { /* ... */ }
                    Button("Open Active Configuration") { /* ... */ }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(Material.regular)
    }
}
```

### 7.6 Import Wizard (Deferred)

Dedicated import functionality (file picker, paste text) is deferred in V3.2. Initial population relies on users manually placing files in `~/.kube/configs/` or using the "New Configuration" (+) button.

### 7.7 Dependency View (Removed/Deferred)

Dependency management is removed in this simplified version.

### 7.8 Command Line Interface (CLI) Design (V3.2)

The existing CLI commands need to be adapted to the new file-based management model.

**`configforge kube list` (or `cf k ls`)**

*   **Functionality:** Lists available Kubernetes configurations.
*   **Implementation:**
    *   Scans the `~/.kube/configs/` directory for configuration files (e.g., `.yaml`, `.kubeconfig`).
    *   Reads the content of the active `~/.kube/config` file.
    *   Compares the content of `~/.kube/config` with each file in `~/.kube/configs/` to identify which one is currently active. (Note: This requires reading all files and might be slow for many large files. A future optimization might involve storing the active filename somewhere upon switching).
    *   Outputs a list of filenames found in `~/.kube/configs/`.
    *   Clearly marks the currently active configuration in the list (e.g., `* active-config.yaml (active)`).
    *   Optionally (e.g., with a `-v` or `--validate` flag), attempts to parse each listed file and indicates if it's valid or potentially damaged.
*   **Example Output:**
    ```
    Available Kubernetes Configurations:
      dev-cluster.yaml
    * prod-cluster.yaml (active)
      staging-cluster.yaml [invalid]
    ```

**`configforge kube set <filename>` (or `cf k set <filename>`)**

*   **Functionality:** Sets the specified configuration file as the active one.
*   **Parameter:** `<filename>` - The name of the file within the `~/.kube/configs/` directory (e.g., `dev-cluster.yaml`).
*   **Implementation:**
    *   Verifies that the specified `<filename>` exists within `~/.kube/configs/`.
    *   Reads the current content of `~/.kube/config`.
    *   Writes this content to `~/.kube/config.bak` (overwriting the previous backup).
    *   Reads the content of `~/.kube/configs/<filename>`.
    *   Writes this content to `~/.kube/config` (overwriting the active config).
    *   Prints a confirmation message (e.g., "Switched active Kubernetes configuration to <filename>").
*   **Note:** This command *replaces* the old logic of calling `kubectl config use-context`.

**`configforge kube current` (or `cf k current`)**

*   **Functionality:** Shows information about the currently active configuration.
*   **Implementation Options:**
    *   **Option A (Preferred but potentially slow):** Read `~/.kube/config` and compare its content against files in `~/.kube/configs/` to determine and print the matching filename.
    *   **Option B (Simpler fallback):** Read `~/.kube/config` and print the value of its internal `current-context` field. This requires clear documentation that it shows the *internal* context, not the active *file*.
    *   **Option C (Hybrid):** Attempt Option A. If a matching file is found, print its name. Also print the internal `current-context` from `~/.kube/config`.
*   **Decision:** Initially implement Option C for the most information, clearly labeling both the inferred active file (if found) and the internal context.
*   **Example Output (Option C):**
    ```
    Active Configuration File: prod-cluster.yaml (inferred)
    Internal Current Context: admin@prod-cluster
    ```
    or if file match fails:
    ```
    Active Configuration File: Unknown (content does not match any file in ~/.kube/configs/)
    Internal Current Context: admin@prod-cluster
    ```

## 8. Implementation Plan (Revised)

### 8.1 Phase 1: Core V3 Functionality

- Implement file structure (`~/.kube/configs/`, `~/.kube/config`, `~/.kube/config.bak`).
- Implement discovery: Scan `~/.kube/configs/`, display list.
- Implement validation: Parse files during discovery/on demand, mark invalid ones.
- Implement switching: Backup `config` to `config.bak`, overwrite `config` with selected file content.
- Build fundamental UI: List view, basic editor/viewer, context menus for switching/actions.

### 8.2 Phase 2: Basic Enhancements

- Implement basic import/export/duplicate/delete file operations.
- Add basic filename search and sorting (name, date).
- Refine UI/UX based on initial feedback.
- Improve error handling and notifications.

### 8.3 Phase 3: Advanced Capabilities (Future)

- Re-evaluate adding metadata features (tags, environments, etc.).
- Implement automatic splitting of existing multi-context `~/.kube/config` files.
- Add templating features.
- Implement more robust backup/restore or versioning.
- Consider dependency management if needed.

## 9. Future Considerations

### 9.1 Potential Enhancements (Revised)

- **Automatic Splitting**: Implement the deferred feature to split existing multi-context files on first run.
- **Metadata Layer**: Add optional metadata storage (e.g., sidecar files, embedded comments) for richer organization and search.
- **Cloud Sync/Team Sharing**: Explore options for sharing/syncing the `~/.kube/configs` directory.
- **Version Control Integration**: Integrate with Git for tracking changes to configurations.
- **Direct Cluster Integration**: Fetch/update configurations directly from clusters.
- **Enhanced Backup/Restore**: Implement multiple backups or version history instead of a single `.bak` file.

### 9.2 Security Considerations

- **Credential Protection**: Secure storage of sensitive authentication data
- **Access Control**: Limit access to production configurations
- **Encryption**: Encrypt configuration files at rest
- **Audit Logging**: Track configuration changes and usage

### 9.3 Performance Optimization

- **Caching**: Implement caching for frequently accessed configurations
- **Lazy Loading**: Load configuration details only when needed
- **Background Processing**: Handle validation and other operations asynchronously

## 10. Conclusion (Revised)

This revised design proposal focuses on a streamlined, file-based system for managing multiple Kubernetes configurations. By storing individual configurations in `~/.kube/configs/` and managing the active `~/.kube/config` via an overwrite-with-backup mechanism, it directly addresses the user need for simpler handling of complete kubeconfig files.

While deferring advanced metadata and automatic splitting features, this V3 approach provides core functionality for discovery, validation, and switching, offering immediate improvements over manual management of a single, complex `~/.kube/config` file. The implementation plan prioritizes delivering this core value quickly, with clear paths for future enhancements.
