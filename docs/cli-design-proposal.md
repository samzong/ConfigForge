# ConfigForge CLI Design Proposal

## Overview

The ConfigForge CLI (`cf`) will be a companion to the ConfigForge macOS application, providing terminal access to view and manage SSH hosts and Kubernetes contexts. It will allow users to:

1. List SSH hosts and Kubernetes contexts
2. Connect to SSH hosts with a single command
3. Switch between Kubernetes contexts quickly
4. Integrate seamlessly with the ConfigForge application's data model

## Technical Design

### 1. Framework Selection

For Swift CLI development, we'll use:

- **Swift Argument Parser** - Apple's official library for building command-line tools
- **Foundation Framework** - For file operations and data handling
- **AppKit (limited)** - For terminal launching capabilities (reusing existing code from the app)

### 2. CLI Structure

```
cf [command] [options]

Commands:
  ssh                Commands for SSH operations
    list             List all SSH hosts
    connect <host>   Connect to specified SSH host

  kube               Commands for Kubernetes operations
    list             List all Kubernetes contexts
    context <name>   Switch to specified Kubernetes context
    current          Show current Kubernetes context

  version            Display the version
  help               Display help information
```

### 3. Core Components

#### 3.1 CLI Entry Point

Create a new Swift executable target in the project that will serve as the entry point for the CLI.

```swift
// main.swift
import ArgumentParser
import Foundation

@main
struct ConfigForgeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cf",
        abstract: "ConfigForge CLI - Manage SSH and Kubernetes configurations",
        version: "1.0.0",
        subcommands: [
            SSHCommand.self,
            KubeCommand.self
        ],
        defaultSubcommand: SSHCommand.self
    )
}

// Start the CLI
ConfigForgeCLI.main()
```

#### 3.2 SSH Command Group

```swift
// SSHCommand.swift
struct SSHCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ssh",
        abstract: "Manage SSH configurations",
        subcommands: [
            SSHListCommand.self,
            SSHConnectCommand.self
        ],
        defaultSubcommand: SSHListCommand.self
    )
}

// List SSH hosts
struct SSHListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all SSH hosts"
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed information for each host")
    var detail = false
    
    func run() throws {
        // Use SSHConfigFileManager and SSHConfigParser to get hosts
        let fileManager = SSHConfigFileManager()
        let parser = SSHConfigParser()
        
        do {
            let content = try await fileManager.readConfigFile()
            let entries = try parser.parseConfig(content: content)
            
            // Format and display the entries
            // ...
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// Connect to SSH host
struct SSHConnectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "connect",
        abstract: "Connect to a specified SSH host"
    )
    
    @Argument(help: "The SSH host to connect to")
    var host: String
    
    func run() throws {
        // Use SSHConfigFileManager and SSHConfigParser to find the host
        // Use TerminalLauncherService to establish connection
        // ...
    }
}
```

#### 3.3 Kubernetes Command Group

```swift
// KubeCommand.swift
struct KubeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kube",
        abstract: "Manage Kubernetes configurations",
        subcommands: [
            KubeListCommand.self,
            KubeContextCommand.self,
            KubeCurrentCommand.self
        ],
        defaultSubcommand: KubeListCommand.self
    )
}

// List Kubernetes contexts
struct KubeListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all Kubernetes contexts"
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed information for each context")
    var detail = false
    
    func run() throws {
        // Use KubeConfigFileManager and KubeConfigParser to get contexts
        // ...
    }
}

// Switch to a Kubernetes context
struct KubeContextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "context",
        abstract: "Switch to a specified Kubernetes context"
    )
    
    @Argument(help: "The Kubernetes context to switch to")
    var contextName: String
    
    func run() throws {
        // Use KubeConfigFileManager to switch contexts
        // ...
    }
}

// Show current Kubernetes context
struct KubeCurrentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "current",
        abstract: "Show the current Kubernetes context"
    )
    
    func run() throws {
        // Use KubeConfigFileManager to get current context
        // ...
    }
}
```

### 4. Shared Services

We'll need to create a CLI-specific version of the services used in the main application:

1. **CLIConfigReader** - A simplified version of the FileManager services
2. **CLITerminalService** - A CLI-appropriate version of the TerminalLauncherService

### 5. Installation

The CLI will be installed alongside the ConfigForge application when using Homebrew:

```bash
brew tap samzong/tap
brew install configforge
```

This will install both the macOS app and the `cf` CLI command.

### 6. Integration with Main App

The CLI will:
1. Read from the same configuration files (`~/.ssh/config` and `~/.kube/config`)
2. Use the same parsers and models as the main app
3. Ensure changes made through the CLI are reflected in the app and vice versa

## Implementation Plan

1. Create a new Swift Package for the CLI
2. Add ArgumentParser dependency
3. Set up the command structure
4. Implement shared models and services
5. Implement SSH and Kubernetes command functionality
6. Add installation scripts to the Homebrew formula
7. Test with various real-world scenarios
8. Update documentation

## User Experience Examples

### SSH Operations

```bash
# List all SSH hosts
$ cf ssh list
Available SSH hosts:
1. dev-server
2. production-db
3. staging-web

# Connect to an SSH host
$ cf ssh connect dev-server
# Terminal connects to dev-server
```

### Kubernetes Operations

```bash
# List all Kubernetes contexts
$ cf kube list
Available Kubernetes contexts:
1. minikube
2. production (current)
3. staging

# Switch to a different context
$ cf kube context staging
Switched to context "staging"

# Show current context
$ cf kube current
Current context: staging
```

## Future Enhancements

1. Interactive selection mode (using arrow keys)
2. Tab completion for host names and context names
3. Configuration management (add/remove/modify entries)
4. Syncing between multiple machines
5. Status reporting for SSH hosts and Kubernetes clusters 