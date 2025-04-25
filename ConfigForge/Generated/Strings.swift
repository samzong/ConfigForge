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
    /// Language
    public static let language = L10n.tr("Localizable", "app.language", fallback: "Language")
    /// General
    public static let name = L10n.tr("Localizable", "app.name", fallback: "ConfigForge")
    /// Save
    public static let save = L10n.tr("Localizable", "app.save", fallback: "Save")
    /// Success
    public static let success = L10n.tr("Localizable", "app.success", fallback: "Success")
    public enum Language {
      /// Chinese
      public static let chinese = L10n.tr("Localizable", "app.language.chinese", fallback: "Chinese")
      /// English
      public static let english = L10n.tr("Localizable", "app.language.english", fallback: "English")
      public enum Restart {
        /// Please restart the application for the language change to take effect.
        public static let message = L10n.tr("Localizable", "app.language.restart.message", fallback: "Please restart the application for the language change to take effect.")
        /// Language Changed
        public static let title = L10n.tr("Localizable", "app.language.restart.title", fallback: "Language Changed")
      }
    }
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
    public enum Binding {
      /// Error: Cannot find editor binding for selected Cluster.
      public static let cluster = L10n.tr("Localizable", "error.binding.cluster", fallback: "Error: Cannot find editor binding for selected Cluster.")
      /// Error: Cannot find editor binding for selected Context.
      public static let context = L10n.tr("Localizable", "error.binding.context", fallback: "Error: Cannot find editor binding for selected Context.")
      /// Error: Cannot find editor binding for selected User.
      public static let user = L10n.tr("Localizable", "error.binding.user", fallback: "Error: Cannot find editor binding for selected User.")
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
    /// Search kubernetes configurations
    public static let search = L10n.tr("Localizable", "kubernetes.search", fallback: "Search configurations")
    /// Refresh configurations
    public static let refresh = L10n.tr("Localizable", "kubernetes.refresh", fallback: "Refresh configurations")
    /// No configuration selected
    public static let noSelection = L10n.tr("Localizable", "kubernetes.noSelection", fallback: "No configuration selected")
    /// Select a configuration from the list or create a new one
    public static let selectOrCreate = L10n.tr("Localizable", "kubernetes.selectOrCreate", fallback: "Select a configuration from the list or create a new one")
    /// Create new configuration
    public static let createNew = L10n.tr("Localizable", "kubernetes.createNew", fallback: "Create new configuration")
    public enum Cluster {
      /// Certificate Authority Data (Base64)
      public static let ca = L10n.tr("Localizable", "kubernetes.cluster.ca", fallback: "Certificate Authority Data (Base64)")
      /// Edit Cluster: %@
      public static func edit(_ p1: Any) -> String {
        return L10n.tr("Localizable", "kubernetes.cluster.edit", String(describing: p1), fallback: "Edit Cluster: %@")
      }
      /// Cluster Name
      public static let name = L10n.tr("Localizable", "kubernetes.cluster.name", fallback: "Cluster Name")
      /// Security Options
      public static let security = L10n.tr("Localizable", "kubernetes.cluster.security", fallback: "Security Options")
      /// Server URL
      public static let server = L10n.tr("Localizable", "kubernetes.cluster.server", fallback: "Server URL")
      public enum Ca {
        /// No certificate data set
        public static let empty = L10n.tr("Localizable", "kubernetes.cluster.ca.empty", fallback: "No certificate data set")
        /// Certificate Authority Data (Base64):
        public static let label = L10n.tr("Localizable", "kubernetes.cluster.ca.label", fallback: "Certificate Authority Data (Base64):")
      }
      public enum Details {
        /// Kubernetes Detail Panels
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "kubernetes.cluster.details.title", String(describing: p1), fallback: "Cluster Details: %@")
        }
      }
      public enum Name {
        /// Cluster Name:
        public static let label = L10n.tr("Localizable", "kubernetes.cluster.name.label", fallback: "Cluster Name:")
      }
      public enum Server {
        /// Server URL:
        public static let label = L10n.tr("Localizable", "kubernetes.cluster.server.label", fallback: "Server URL:")
        /// https://<server-address>:<port>
        public static let placeholder = L10n.tr("Localizable", "kubernetes.cluster.server.placeholder", fallback: "https://<server-address>:<port>")
      }
      public enum Skip {
        /// Skip TLS Certificate Verification
        public static let tls = L10n.tr("Localizable", "kubernetes.cluster.skip.tls", fallback: "Skip TLS Certificate Verification")
        public enum Tls {
          /// Skip TLS Certificate Verification
          public static let verification = L10n.tr("Localizable", "kubernetes.cluster.skip.tls.verification", fallback: "Skip TLS Certificate Verification")
        }
      }
    }
    public enum Config {
      /// Configuration saved
      public static let saved = L10n.tr("Localizable", "kubernetes.config.saved", fallback: "Configuration saved")
      /// Active configuration
      public static let active = L10n.tr("Localizable", "kubernetes.config.active", fallback: "Active configuration")
      /// Backup configuration
      public static let backup = L10n.tr("Localizable", "kubernetes.config.backup", fallback: "Backup configuration")
      /// Set as active configuration
      public static let setActive = L10n.tr("Localizable", "kubernetes.config.setActive", fallback: "Set as active configuration")
      /// Duplicate
      public static let duplicate = L10n.tr("Localizable", "kubernetes.config.duplicate", fallback: "Duplicate")
      /// Rename
      public static let rename = L10n.tr("Localizable", "kubernetes.config.rename", fallback: "Rename")
    }
    public enum Context {
      /// Cluster
      public static let cluster = L10n.tr("Localizable", "kubernetes.context.cluster", fallback: "Cluster")
      /// Kubernetes UI
      public static func edit(_ p1: Any) -> String {
        return L10n.tr("Localizable", "kubernetes.context.edit", String(describing: p1), fallback: "Edit Context: %@")
      }
      /// Context Name
      public static let name = L10n.tr("Localizable", "kubernetes.context.name", fallback: "Context Name")
      /// Namespace
      public static let namespace = L10n.tr("Localizable", "kubernetes.context.namespace", fallback: "Namespace")
      /// User
      public static let user = L10n.tr("Localizable", "kubernetes.context.user", fallback: "User")
      public enum Cluster {
        public enum User {
          /// Cluster: %@ | User: %@
          public static func format(_ p1: Any, _ p2: Any) -> String {
            return L10n.tr("Localizable", "kubernetes.context.cluster.user.format", String(describing: p1), String(describing: p2), fallback: "Cluster: %@ | User: %@")
          }
        }
      }
      public enum Namespace {
        /// Namespace: %@
        public static func format(_ p1: Any) -> String {
          return L10n.tr("Localizable", "kubernetes.context.namespace.format", String(describing: p1), fallback: "Namespace: %@")
        }
        /// Namespace (optional)
        public static let `optional` = L10n.tr("Localizable", "kubernetes.context.namespace.optional", fallback: "Namespace (optional)")
      }
      public enum View {
        public enum Cluster {
          /// View/Edit Cluster Details
          public static let details = L10n.tr("Localizable", "kubernetes.context.view.cluster.details", fallback: "View/Edit Cluster Details")
        }
        public enum User {
          /// View/Edit User Details
          public static let details = L10n.tr("Localizable", "kubernetes.context.view.user.details", fallback: "View/Edit User Details")
        }
      }
    }
    public enum Panel {
      public enum Cluster {
        /// Cluster Details
        public static let details = L10n.tr("Localizable", "kubernetes.panel.cluster.details", fallback: "Cluster Details")
      }
      public enum Not {
        public enum Found {
          /// Cluster details not found
          public static let cluster = L10n.tr("Localizable", "kubernetes.panel.not.found.cluster", fallback: "Cluster details not found")
          /// User details not found
          public static let user = L10n.tr("Localizable", "kubernetes.panel.not.found.user", fallback: "User details not found")
        }
      }
      public enum User {
        /// User Details
        public static let details = L10n.tr("Localizable", "kubernetes.panel.user.details", fallback: "User Details")
      }
    }
    public enum User {
      /// Edit User: %@
      public static func edit(_ p1: Any) -> String {
        return L10n.tr("Localizable", "kubernetes.user.edit", String(describing: p1), fallback: "Edit User: %@")
      }
      /// User Name
      public static let name = L10n.tr("Localizable", "kubernetes.user.name", fallback: "User Name")
      public enum Auth {
        /// Auth: Client Cert
        public static let cert = L10n.tr("Localizable", "kubernetes.user.auth.cert", fallback: "Auth: Client Cert")
        /// Auth: Other/Unknown
        public static let other = L10n.tr("Localizable", "kubernetes.user.auth.other", fallback: "Auth: Other/Unknown")
        /// Auth: Token
        public static let token = L10n.tr("Localizable", "kubernetes.user.auth.token", fallback: "Auth: Token")
      }
      public enum Cert {
        /// Client Certificate Authentication
        public static let auth = L10n.tr("Localizable", "kubernetes.user.cert.auth", fallback: "Client Certificate Authentication")
      }
      public enum Client {
        /// Client Certificate (Base64)
        public static let cert = L10n.tr("Localizable", "kubernetes.user.client.cert", fallback: "Client Certificate (Base64)")
        /// Client Key (Base64)
        public static let key = L10n.tr("Localizable", "kubernetes.user.client.key", fallback: "Client Key (Base64)")
        public enum Cert {
          /// No client certificate set
          public static let empty = L10n.tr("Localizable", "kubernetes.user.client.cert.empty", fallback: "No client certificate set")
          /// Client Certificate Data (Base64):
          public static let label = L10n.tr("Localizable", "kubernetes.user.client.cert.label", fallback: "Client Certificate Data (Base64):")
        }
        public enum Key {
          /// No client key set
          public static let empty = L10n.tr("Localizable", "kubernetes.user.client.key.empty", fallback: "No client key set")
          /// Client Key Data (Base64):
          public static let label = L10n.tr("Localizable", "kubernetes.user.client.key.label", fallback: "Client Key Data (Base64):")
        }
      }
      public enum Details {
        /// User Details: %@
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "kubernetes.user.details.title", String(describing: p1), fallback: "User Details: %@")
        }
      }
      public enum Name {
        /// User Name:
        public static let label = L10n.tr("Localizable", "kubernetes.user.name.label", fallback: "User Name:")
      }
      public enum Token {
        /// Bearer Token Authentication
        public static let auth = L10n.tr("Localizable", "kubernetes.user.token.auth", fallback: "Bearer Token Authentication")
        /// No token set
        public static let empty = L10n.tr("Localizable", "kubernetes.user.token.empty", fallback: "No token set")
        /// Token:
        public static let label = L10n.tr("Localizable", "kubernetes.user.token.label", fallback: "Token:")
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
    /// Search
    public static let search = L10n.tr("Localizable", "sidebar.search", fallback: "Search")
    public enum Add {
      /// Add host
      public static let host = L10n.tr("Localizable", "sidebar.add.host", fallback: "Add host")
      /// Add configuration
      public static let config = L10n.tr("Localizable", "sidebar.add.config", fallback: "Add configuration")
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
