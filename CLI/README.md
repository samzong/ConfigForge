# ConfigForge CLI

A command-line interface for managing SSH hosts and Kubernetes contexts.

## Installation

The ConfigForge CLI (`cf`) is installed alongside the ConfigForge macOS application when using Homebrew:

```bash
brew tap samzong/tap
brew install configforge
```

## Usage

### SSH Commands

List all SSH hosts:
```bash
cf ssh list
```

Show detailed information for SSH hosts:
```bash
cf ssh list --detail
```

Connect to an SSH host:
```bash
cf ssh connect <host-name>
```

### Kubernetes Commands

List all Kubernetes contexts:
```bash
cf kube list
```

Show detailed information for Kubernetes contexts:
```bash
cf kube list --detail
```

Switch to a specific Kubernetes context:
```bash
cf kube context <context-name>
```

Show the current Kubernetes context:
```bash
cf kube current
```

### General Commands

Display version information:
```bash
cf version
```

Display help information:
```bash
cf help
```

## Development

### Building from Source

1. Clone the repository
2. Navigate to the CLI directory
3. Run `swift build`

### Running in Development

```bash
swift run cf <command>
```

### Creating a Release

```bash
swift build -c release
``` 