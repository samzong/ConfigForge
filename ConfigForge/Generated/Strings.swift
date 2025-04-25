// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum L10n {
  public enum App {
    /// Cancel
    public static let cancel = L10n.tr("Localizable", "app.cancel", fallback: "Cancel")
    /// Confirm
    public static let confirm = L10n.tr("Localizable", "app.confirm", fallback: "Confirm")
    /// Delete
    public static let delete = L10n.tr("Localizable", "app.delete", fallback: "Delete")
    /// Edit
    public static let edit = L10n.tr("Localizable", "app.edit", fallback: "Edit")
    /// Error
    public static let error = L10n.tr("Localizable", "app.error", fallback: "Error")
    /// General
    public static let name = L10n.tr("Localizable", "app.name", fallback: "ConfigForge")
    /// Save
    public static let save = L10n.tr("Localizable", "app.save", fallback: "Save")
    /// Success
    public static let success = L10n.tr("Localizable", "app.success", fallback: "Success")
    public enum Save {
      /// Save current configuration to SSH file
      public static let help = L10n.tr("Localizable", "app.save.help", fallback: "Save current configuration to SSH file")
    }
  }
  public enum Button {
    /// Done
    public static let done = L10n.tr("Localizable", "button.done", fallback: "Done")
  }
  public enum Editor {
    public enum Empty {
      /// Select an item from the list on the left, or click "Add Host" to create a new configuration
      public static let description = L10n.tr("Localizable", "editor.empty.description", fallback: "Select an item from the list on the left, or click \"Add Host\" to create a new configuration")
      /// Editor
      public static let title = L10n.tr("Localizable", "editor.empty.title", fallback: "Select or Create SSH Config")
    }
  }
  public enum Error {
    /// Cannot access import file
    public static let cannotAccessImportFile = L10n.tr("Localizable", "error.cannotAccessImportFile", fallback: "Cannot access import file")
    /// Failed to import file: %@
    public static func fileImportFailed(_ p1: Any) -> String {
      return L10n.tr("Localizable", "error.fileImportFailed", String(describing: p1), fallback: "Failed to import file: %@")
    }
    public enum Editor {
      /// Cannot display editor for selected item.
      public static let unknown = L10n.tr("Localizable", "error.editor.unknown", fallback: "Cannot display editor for selected item.")
    }
  }
  public enum Host {
    /// Invalid host name, please correct before saving
    public static let invalid = L10n.tr("Localizable", "host.invalid", fallback: "Invalid host name, please correct before saving")
    /// Host List
    public static let new = L10n.tr("Localizable", "host.new", fallback: "new-host")
    public enum Enter {
      /// Enter host name
      public static let name = L10n.tr("Localizable", "host.enter.name", fallback: "Enter host name")
    }
  }
  public enum Kubernetes {
    /// Create New Configuration
    public static let createNew = L10n.tr("Localizable", "kubernetes.createNew", fallback: "Create New Configuration")
    /// Kubernetes UI
    public static let noSelection = L10n.tr("Localizable", "kubernetes.noSelection", fallback: "No Configuration Selected")
    /// Search configurations
    public static let search = L10n.tr("Localizable", "kubernetes.search", fallback: "Search configurations")
    /// Select a configuration from the list or create a new one
    public static let selectOrCreate = L10n.tr("Localizable", "kubernetes.selectOrCreate", fallback: "Select a configuration from the list or create a new one")
    public enum Config {
      /// Active
      public static let active = L10n.tr("Localizable", "kubernetes.config.active", fallback: "Active")
      /// Backup
      public static let backup = L10n.tr("Localizable", "kubernetes.config.backup", fallback: "Backup")
      /// Delete
      public static let delete = L10n.tr("Localizable", "kubernetes.config.delete", fallback: "Delete")
      /// Configuration saved
      public static let saved = L10n.tr("Localizable", "kubernetes.config.saved", fallback: "Configuration saved")
      /// Set as Active
      public static let setActive = L10n.tr("Localizable", "kubernetes.config.setActive", fallback: "Set as Active")
      public enum Delete {
        /// Are you sure you want to delete this configuration?
        public static let confirm = L10n.tr("Localizable", "kubernetes.config.delete.confirm", fallback: "Are you sure you want to delete this configuration?")
      }
    }
  }
  public enum Message {
    public enum Backup {
      /// Configuration backed up to %@
      public static func success(_ p1: Any) -> String {
        return L10n.tr("Localizable", "message.backup.success", String(describing: p1), fallback: "Configuration backed up to %@")
      }
    }
    public enum Error {
      public enum Backup {
        /// Backup failed
        public static let failed = L10n.tr("Localizable", "message.error.backup.failed", fallback: "Backup failed")
        public enum Not {
          /// No backup file selected
          public static let selected = L10n.tr("Localizable", "message.error.backup.not.selected", fallback: "No backup file selected")
        }
      }
      public enum Duplicate {
        /// A host with this name already exists
        public static let host = L10n.tr("Localizable", "message.error.duplicate.host", fallback: "A host with this name already exists")
      }
      public enum Empty {
        /// Host name cannot be empty
        public static let host = L10n.tr("Localizable", "message.error.empty.host", fallback: "Host name cannot be empty")
      }
      public enum Entry {
        public enum Not {
          /// Entry not found
          public static let found = L10n.tr("Localizable", "message.error.entry.not.found", fallback: "Entry not found")
        }
      }
      public enum Export {
        /// Failed to export backup: %@
        public static func failed(_ p1: Any) -> String {
          return L10n.tr("Localizable", "message.error.export.failed", String(describing: p1), fallback: "Failed to export backup: %@")
        }
      }
      public enum File {
        /// Error Messages
        public static let access = L10n.tr("Localizable", "message.error.file.access", fallback: "File access error")
      }
      public enum Import {
        /// Failed to import backup: %@
        public static func failed(_ p1: Any) -> String {
          return L10n.tr("Localizable", "message.error.import.failed", String(describing: p1), fallback: "Failed to import backup: %@")
        }
      }
      public enum Invalid {
        /// Invalid configuration format. Some entries may not be parsed correctly.
        public static let format = L10n.tr("Localizable", "message.error.invalid.format", fallback: "Invalid configuration format. Some entries may not be parsed correctly.")
        /// Invalid port number
        public static let port = L10n.tr("Localizable", "message.error.invalid.port", fallback: "Invalid port number")
      }
      public enum Permission {
        /// Permission denied
        public static let denied = L10n.tr("Localizable", "message.error.permission.denied", fallback: "Permission denied")
      }
      public enum Restore {
        /// Restore failed
        public static let failed = L10n.tr("Localizable", "message.error.restore.failed", fallback: "Restore failed")
      }
    }
    public enum Host {
      /// Messages
      public static func added(_ p1: Any) -> String {
        return L10n.tr("Localizable", "message.host.added", String(describing: p1), fallback: "Added %@")
      }
      /// Deleted %@
      public static func deleted(_ p1: Any) -> String {
        return L10n.tr("Localizable", "message.host.deleted", String(describing: p1), fallback: "Deleted %@")
      }
      /// Updated %@
      public static func updated(_ p1: Any) -> String {
        return L10n.tr("Localizable", "message.host.updated", String(describing: p1), fallback: "Updated %@")
      }
    }
    public enum Restore {
      /// Configuration restored from backup
      public static let success = L10n.tr("Localizable", "message.restore.success", fallback: "Configuration restored from backup")
    }
    public enum Success {
      public enum Config {
        /// Configuration backed up successfully
        public static let backup = L10n.tr("Localizable", "message.success.config.backup", fallback: "Configuration backed up successfully")
        /// Success Messages
        public static let loaded = L10n.tr("Localizable", "message.success.config.loaded", fallback: "Configuration loaded successfully")
        /// Configuration restored successfully
        public static let restore = L10n.tr("Localizable", "message.success.config.restore", fallback: "Configuration restored successfully")
        /// Configuration saved successfully
        public static let saved = L10n.tr("Localizable", "message.success.config.saved", fallback: "Configuration saved successfully")
      }
      public enum Entry {
        /// New host configuration added
        public static let added = L10n.tr("Localizable", "message.success.entry.added", fallback: "New host configuration added")
        /// Configuration deleted
        public static let deleted = L10n.tr("Localizable", "message.success.entry.deleted", fallback: "Configuration deleted")
        /// Configuration updated
        public static let updated = L10n.tr("Localizable", "message.success.entry.updated", fallback: "Configuration updated")
      }
    }
  }
  public enum Property {
    /// Config Properties
    public static let hostname = L10n.tr("Localizable", "property.hostname", fallback: "HostName")
    /// IdentityFile
    public static let identityfile = L10n.tr("Localizable", "property.identityfile", fallback: "IdentityFile")
    /// Port
    public static let port = L10n.tr("Localizable", "property.port", fallback: "Port")
    /// User
    public static let user = L10n.tr("Localizable", "property.user", fallback: "User")
    public enum Hostname {
      /// e.g. example.com
      public static let placeholder = L10n.tr("Localizable", "property.hostname.placeholder", fallback: "e.g. example.com")
    }
    public enum Identityfile {
      /// e.g. ~/.ssh/id_rsa
      public static let placeholder = L10n.tr("Localizable", "property.identityfile.placeholder", fallback: "e.g. ~/.ssh/id_rsa")
    }
    public enum Port {
      /// Default: 22
      public static let placeholder = L10n.tr("Localizable", "property.port.placeholder", fallback: "Default: 22")
    }
    public enum User {
      /// e.g. admin
      public static let placeholder = L10n.tr("Localizable", "property.user.placeholder", fallback: "e.g. admin")
    }
  }
  public enum Sidebar {
    /// Sidebar
    public static let search = L10n.tr("Localizable", "sidebar.search", fallback: "Search hosts")
    public enum Add {
      /// Add Config
      public static let config = L10n.tr("Localizable", "sidebar.add.config", fallback: "Add Config")
      /// Add Host
      public static let host = L10n.tr("Localizable", "sidebar.add.host", fallback: "Add Host")
    }
  }
  public enum Terminal {
    public enum Launch {
      public enum Failed {
        /// Could not launch SSH connection in %@. Please check your terminal settings and permissions.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "terminal.launch.failed.message", String(describing: p1), fallback: "Could not launch SSH connection in %@. Please check your terminal settings and permissions.")
        }
        /// Failed to Launch Terminal
        public static let title = L10n.tr("Localizable", "terminal.launch.failed.title", fallback: "Failed to Launch Terminal")
      }
    }
    public enum Open {
      /// Terminal Launcher
      public static let `in` = L10n.tr("Localizable", "terminal.open.in", fallback: "Open In")
      public enum In {
        /// Open In iTerm
        public static let iterm = L10n.tr("Localizable", "terminal.open.in.iterm", fallback: "Open In iTerm")
        /// Open In Terminal
        public static let terminal = L10n.tr("Localizable", "terminal.open.in.terminal", fallback: "Open In Terminal")
      }
    }
    public enum Permission {
      /// ConfigForge needs permission to control %@ to launch SSH connections. You may see a system prompt to allow this.
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "terminal.permission.message", String(describing: p1), fallback: "ConfigForge needs permission to control %@ to launch SSH connections. You may see a system prompt to allow this.")
      }
      /// Terminal Automation Permission
      public static let title = L10n.tr("Localizable", "terminal.permission.title", fallback: "Terminal Automation Permission")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
